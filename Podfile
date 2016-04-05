platform :ios, '8.0'
use_frameworks!

target 'AlfrescoActiviti' do
	pod 'HockeySDK'
	pod "Lookback", :configurations => ["Debug", "Release"]
end

target 'AlfrescoActivitiTests' do

end

target 'ActivitiSDK' do
	link_with ['ActivitiSDK', 'AlfrescoActiviti']
	
	pod 'AFNetworking'
	pod 'CocoaLumberjack'
    pod 'Mantle'
    pod 'JGProgressHUD'
end

target 'ActivitiSDKTests' do

end