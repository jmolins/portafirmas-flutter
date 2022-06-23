# Portafirmas General del Estado client app

**Portafirmas General del Estado** client application built with Flutter

Features supported in version 1.0:

- Login to different servers
- List types of requests: pending, signed, rejected
- Sign, approve and reject a request or a group of requests
- View request details and associated documents
- Only local certificates are supported to login and sign
- Supported builds: Android, iOS and Windows

# Build Instructions
## Rebuild mobx sources with:

`flutter packages pub run build_runner build`  
or  
`flutter packages pub run build_runner build --delete-conflicting-outputs`

## Adding OpenSSL dependency to iOS build

When building the app for the first time, or after a maintenance clean up, the Podfile file is created.

In order to add the OpenSSL dependency, include the pod directive in the target section of the Podfile, as in the following snippet:

    target 'Runner' do
      ...
      # Pods for Runner
      pod 'OpenSSL-Universal'
      ...
    end

## Recompile with -Xlint:deprecation (android build)

In order to view all messages during build, add the following lines to android project level build.gradle

    allprojects {
      gradle.projectsEvaluated {
        tasks.withType(JavaCompile) {
          options.compilerArgs << "-Xlint:unchecked" << "-Xlint:deprecation"
        }
      }
    }
