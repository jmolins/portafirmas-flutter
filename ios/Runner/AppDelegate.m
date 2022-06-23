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
#include "AppDelegate.h"
#import <Flutter/Flutter.h>
#include "GeneratedPluginRegistrant.h"
#import <Flutter/FlutterCodecs.h>
#import <Security/Security.h>
#include "CertificateUtils.h"
#include "OpenSSLCertificateHelper.h"
#include "PFCertificateInfo.h"
#import <Flutter/FlutterCodecs.h>
#import "NSData+Base64.h"
#import "Base64Utils.h"
#import "GlobalConstants.h"
#include "FlutterDownloaderPlugin.h"

@implementation AppDelegate

void registerPlugins(NSObject<FlutterPluginRegistry>* registry) {
  //
  // Integration note:
  //
  // In Flutter, in order to work in background isolate, plugins need to register with
  // a special instance of `FlutterEngine` that serves for background execution only.
  // Hence, all (and only) plugins that require background execution feature need to
  // call `registerWithRegistrar` in this function.
  //
  // The default `GeneratedPluginRegistrant` will call `registerWithRegistrar` of all
  // plugins integrated in your application. Hence, if you are using `FlutterDownloaderPlugin`
  // along with other plugins that need UI manipulation, you should register
  // `FlutterDownloaderPlugin` and any 'background' plugins explicitly like this:
  if( ![registry hasPlugin:@"vn.hunghd.flutter_downloader"] ){
    [FlutterDownloaderPlugin registerWithRegistrar:[registry registrarForPlugin:@"vn.hunghd.flutter_downloader"]];
  }
  //[GeneratedPluginRegistrant registerWithRegistry:registry];
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [FlutterDownloaderPlugin setPluginRegistrantCallback:registerPlugins];

    FlutterViewController* controller = (FlutterViewController*)self.window.rootViewController;

    FlutterMethodChannel* certificatesChannel = [FlutterMethodChannel  methodChannelWithName:@"digital_certificates"
              binaryMessenger:controller];

    [certificatesChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {

      if ([@"getCertificateFiles" isEqualToString:call.method]) {
        NSArray *certificates = [self findFiles:[NSArray arrayWithObjects:P12EXTENSION, PFXEXTENSION, nil]];
        if (certificates == NULL) {
          result([FlutterError errorWithCode:@"UNAVAILABLE"  message:@"certificates unavailable"
                                     details:nil]);
        } else {
          result(certificates);
        }
      } else if ([@"selectCertificate" isEqualToString:call.method]) {

        if (call.arguments == nil) {
          [[CertificateUtils sharedWrapper] setSelectedCertificateName:nil];
          result(nil);
        }

        // get arguments to find desired certificate
        NSString *issuer = call.arguments[@"issuer"];
        NSString *serial = call.arguments[@"serial"];

        NSMutableArray *certificatesInfo = nil;
        certificatesInfo = [[OpenSSLCertificateHelper getAddedCertificatesInfo] mutableCopy];

        if (!certificatesInfo) {
          result(nil);
        }

        PFCertificateInfo *certInfo;
        for (certInfo in certificatesInfo) {
          //NSLog(@"%@", issuer);
          if ([issuer isEqualToString:certInfo.issuer]
                 && [serial isEqualToString:certInfo.serial]) {

            // Keep in memory the selected certificate
            if ([[CertificateUtils sharedWrapper] searchIdentityByName:certInfo.subject] == YES) {
              [[CertificateUtils sharedWrapper] setSelectedCertificateName:certInfo.subject];
              result([[CertificateUtils sharedWrapper] certificateInBase64]);
            }
          }
        }
        result(nil);

       } else if ([@"loadCertificate" isEqualToString:call.method]) {

        // Load certificate to keychain
        NSString *certName = call.arguments[@"fileName"];
        NSString *pass = call.arguments[@"pass"];

        BOOL saveInDocument;
        #if TARGET_IPHONE_SIMULATOR
            // Load certificate from bundle
            saveInDocument = false;
        #else
            // Load certificate from Documents directory
            saveInDocument = true;
        #endif

        OSStatus status = [[CertificateUtils sharedWrapper] loadCertKeyChainWithName:certName password:pass fromDocument:saveInDocument];

        NSString *_infoLabel;
        if (status != 0) {
            switch (status) {
                case errSecItemNotFound:
                    _infoLabel = @"No se ha encontrado el certificado";
                    break;
                case errSecAuthFailed:
                    _infoLabel = @"Contraseña incorrecta";
                    break;
                case errSecDuplicateItem:
                    _infoLabel = @"El certificado ya estaba cargado";
                    break;
                default:
                    _infoLabel = [NSString stringWithFormat:@"Se ha producido un error(%d)", (int)status];
                    break;
            }
            result(_infoLabel);
        }
        else {
            result(nil);
        }
      } else if ([@"deleteCertificate" isEqualToString:call.method]) {

        // get arguments to find desired certificate
        NSString *issuer = call.arguments[@"issuer"];
        NSString *serial = call.arguments[@"serial"];

        NSMutableArray *certificatesInfo = nil;
        certificatesInfo = [[OpenSSLCertificateHelper getAddedCertificatesInfo] mutableCopy];

        if (!certificatesInfo) {
          result(nil);
        }

        PFCertificateInfo *certificateInfo;
        for (certificateInfo in certificatesInfo) {
          //NSLog(@"%@", issuer);
          if ([issuer isEqualToString:certificateInfo.issuer]
                 && [serial isEqualToString:certificateInfo.serial]) {
             OSStatus status = noErr;
             // Load certificate from Documents directory
             status = [OpenSSLCertificateHelper deleteCertificate:certificateInfo];
             [[CertificateUtils sharedWrapper] setSelectedCertificateName:nil];
             if (status == noErr) {
               result(nil);
             } else {
               result(@"error");
             }
          }
        }
        result(nil);

      } else if ([@"getAddedCertificatesInfo" isEqualToString:call.method]) {
        NSMutableArray *certificatesInfo = nil;
        certificatesInfo = [[OpenSSLCertificateHelper getAddedCertificatesInfo] mutableCopy];

        if (!certificatesInfo) {
          certificatesInfo = [[NSMutableArray alloc] init];
        }

        PFCertificateInfo *certificateInfo;
        NSMutableArray* list = [NSMutableArray array];
        for (certificateInfo in certificatesInfo) {
          NSMutableDictionary *dict = [[NSMutableDictionary alloc]initWithCapacity:2];
          dict[@"subject"] = certificateInfo.subject;
          dict[@"issuer"] = certificateInfo.issuer;
          dict[@"serial"] = certificateInfo.serial;
          [list addObject:dict];
        }
        result(list);

      } else if ([@"signData" isEqualToString:call.method]) {

          FlutterStandardTypedData *typedData = call.arguments[@"data"];
          NSData *data = [typedData data];

          // Algorithm may come as SHA1withRSA
          NSString *algorithm = call.arguments[@"algorithm"];
          if (algorithm == nil) {
              algorithm = @"sha256";
          } else {
              algorithm = [algorithm lowercaseString];
          }

          NSData *dataSigned = nil;

          if ([algorithm containsString:@"sha-1"] || [algorithm containsString:@"sha1"]) {
              dataSigned = [[CertificateUtils sharedWrapper] getSignatureBytesSHA1:data];
          } else if ([algorithm containsString:@"sha-256"] || [algorithm containsString:@"sha256"]) {
              dataSigned = [[CertificateUtils sharedWrapper] getSignatureBytesSHA256:data];
          } else if ([algorithm containsString:@"sha-384"] || [algorithm containsString:@"sha384"]) {
              dataSigned = [[CertificateUtils sharedWrapper] getSignatureBytesSHA384:data];
          } else {
              dataSigned = [[CertificateUtils sharedWrapper] getSignatureBytesSHA512:data];
          }

          FlutterStandardTypedData *value = [FlutterStandardTypedData typedDataWithBytes: dataSigned];

          //NSLog(@"Token signed");

          result(value);

      } else {
        result(FlutterMethodNotImplemented);
      }

    }];

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (NSString *)getCertificates {
  NSString *certificates = @"Ficheros de certificados";
  return certificates;
}

// Find files in Document directory
- (NSArray *)findFiles:(NSArray *)extensions
{

#if TARGET_IPHONE_SIMULATOR

    NSMutableArray *arrayCertsMut = [[NSMutableArray alloc] init];

    // Constraseña: 12345
    [arrayCertsMut addObject:@"FIRMAPROF_99999999R"];
    [arrayCertsMut addObject:@"CAMERFIRMA_00000000T"];

    return arrayCertsMut;

#else

    NSMutableArray *matches = [@[] mutableCopy];
    NSFileManager *fManager = [NSFileManager defaultManager];
    NSString *item;
    NSString *ext;
    NSArray *contents = [fManager contentsOfDirectoryAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] error:nil];

    // >>> this section here adds all files with the chosen extension to an array
    for (item in contents) {
        for (ext in extensions) {
            if ([[item pathExtension] isEqualToString:ext]) {
                [matches addObject:item];
            }
        }
    }

    return matches;

#endif /* if TARGET_IPHONE_SIMULATOR */
}

@end
