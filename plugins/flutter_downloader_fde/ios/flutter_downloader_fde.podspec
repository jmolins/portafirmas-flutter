#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_downloader_fde'
  s.version          = '0.0.1'
  s.summary          = 'No-op implementation of flutter_downloader_fde desktop plugin to avoid build issues on iOS'
  s.description      = <<-DESC
temp fake flutter_downloader_fde plugin
                       DESC
  s.homepage         = 'https://github.com/jmolins'
  s.author           = { 'Chema Molins' => 'chemamolins@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end

