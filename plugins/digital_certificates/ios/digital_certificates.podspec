#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'digital_certificates'
  s.version          = '0.0.1'
  s.summary          = 'No-op implementation of digital_certificates plugin to avoid build issues on iOS'
  s.description      = <<-DESC
temp fake digital_certificates plugin
                       DESC
  s.homepage         = 'https://github.com/flutter/plugins/tree/master/packages/shared_preferences/shared_preferences_web'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Chema Molins' => 'chemamolins@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end