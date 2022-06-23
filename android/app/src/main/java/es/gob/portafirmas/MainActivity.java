package es.gob.portafirmas;

import android.os.Environment;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "portafirmas.gob.es";

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
        .setMethodCallHandler(
            (call, result) -> {
              // Note: this method is invoked on the main thread.
              if (call.method.equals("getDownloadsDirectory")) {
                result.success(getDownloadsDirectory());
              } else {
                result.notImplemented();
              }
            }
        );
  }

  private String getDownloadsDirectory() {
    //return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath();
    return getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS).getAbsolutePath();
  }
}