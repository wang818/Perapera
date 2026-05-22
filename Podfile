platform :ios, '13.0'

target 'Perapera' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Perapera
#    pod 'YYModel', '1.0.4'
#    pod 'MJExtension'
   
   pod 'Moya', '15.0.0'
   pod 'Moya/RxSwift'
   pod 'Alamofire' , '5.0'
   
   # Dependencies used in coinup-bigclient-ios network layer
   pod 'RxSwift', '6.5.0'
   pod 'RxCocoa', '6.5.0'
   pod 'HandyJSON', '5.0.2'
   
   # Tencent Cloud COS SDK for file uploads
   pod 'QCloudCOSXML'
   
   # FFmpeg for video/audio processing (using community maintained version)
   pod 'ffmpeg-kit-ios-full', :git => 'https://github.com/luthviar/ffmpeg-kit-ios-full.git'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      
      # 修复 HandyJSON 在 Xcode 15 / Swift 5.9 Release 模式下编译崩溃的问题
      if target.name == 'HandyJSON'
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      end
      
      # 修复 Xcode 16 下 QCloud SDK 的 private header 报错
      if target.name.start_with?('QCloud')
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
    end
  end

  # 修复 Xcode 16 下 netinet6/in6.h private header 报错
  # 自动将 QCloud 组件中的 #import <netinet6/in6.h> 注释掉
  `sed -i '' 's/#import <netinet6\\/in6.h>/\\/\\/#import <netinet6\\/in6.h>/g' Pods/QCloudTrack/QCloudTrack/Classes/Default/Utils/QCloudTrackNetworkUtils.m`
  `sed -i '' 's/#import <netinet6\\/in6.h>/\\/\\/#import <netinet6\\/in6.h>/g' Pods/QCloudCore/QCloudCore/Classes/Base/QCLOUDRestNet/reachability/QCloudReachability.m`

  installer.aggregate_targets.map(&:user_project).uniq.each do |user_project|
    user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings.delete('EXCLUDED_ARCHS[sdk=iphonesimulator*]')
      end
    end
    user_project.save
  end
end
