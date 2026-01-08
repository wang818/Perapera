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

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
