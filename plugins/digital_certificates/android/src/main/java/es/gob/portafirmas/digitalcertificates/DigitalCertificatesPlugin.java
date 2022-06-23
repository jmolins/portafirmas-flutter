// Copyright 2022. Chema Molins
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package es.gob.portafirmas.digitalcertificates;

import java.security.KeyStore.PrivateKeyEntry;
import java.security.KeyStoreException;
import java.util.Map;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;

import android.security.KeyChain;
import android.security.KeyChainAliasCallback;

import java.security.cert.X509Certificate;
import java.security.PrivateKey;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * DigitalCertificatesPlugin
 */
public class DigitalCertificatesPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

  private Activity activity;
  private MethodChannel channel;

  private static final String CERTIFICATE_CHANNEL = "digital_certificates";

  private PrivateKeyEntry pke;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CERTIFICATE_CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  // https://github.com/flutter/flutter/wiki/Experimental:-Create-Flutter-Plugin
  @Override
  public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
    activity = activityPluginBinding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
    activity = activityPluginBinding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {

    final Map<String, Object> arguments = call.arguments();
    byte[] data = (byte[]) arguments.get("data");
    String algorithm = (String) arguments.get("algorithm");

    if (call.method.equals("selectCertificate")) {

      KeyChain.choosePrivateKeyAlias(activity,
          new KeyChainAliasCallback() {

            @Override
            public void alias(final String alias) {
              if (alias != null) {
                try {
                  pke = new PrivateKeyEntry(
                      KeyChain.getPrivateKey(activity, alias),
                      KeyChain.getCertificateChain(activity, alias)
                  );
                  // Returns the certificate
                  final byte[] certificate = pke.getCertificate().getEncoded();
                  activity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                      result.success(Base64.encode(certificate));
                    }
                  });
                } catch (final Throwable e) {
                  activity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                      result.success("");
                    }
                  });
                }
              } else {
                activity.runOnUiThread(new Runnable() {
                  @Override
                  public void run() {
                    result.error("UNAVAILABLE", "Certificate not available.", null);
                  }
                });
              }
            }
          },
          new String[]{}, null, null, -1, null
      );
    } else if (call.method.equals("certificateSubject")) {
      try {
        X509Certificate cert = (X509Certificate) pke.getCertificate();
        // This gets the whole subject, from which I need to extract the CN
        String subject = cert.getSubjectDN().toString();
        // See comment in https://stackoverflow.com/questions/2914521/how-to-extract-cn-from-x509certificate-in-java
        Pattern pattern = Pattern.compile("(?:^|,\\s?)(?:CN=(?<val>\"(?:[^\"]|\"\")+\"|[^,]+))");
        Matcher matcher = pattern.matcher(subject);
        if (matcher.find()) {
          result.success(matcher.group().replaceFirst("CN=", ""));
        } else {
          result.error("Error", "No se ha podido obtener el subject.", null);
        }
      } catch (Exception e) {
        result.error("Error", "No se ha podido obtener el subject.", null);
      }
    } else if (call.method.equals("signData")) {
      try {
        //byte[] data = call.arguments();
        final AOPkcs1Signer signer = new AOPkcs1Signer();
        if (algorithm == null) algorithm = "SHA256withRSA";
        final byte[] pkcs1 = signer.sign(data, algorithm, pke.getPrivateKey(), pke.getCertificateChain(), null);
        result.success(pkcs1);
      } catch (Exception e) {
        result.error("Error", "No se ha podido firmar los datos.", null);
      }
    } else {
      result.notImplemented();
    }
  }
}
