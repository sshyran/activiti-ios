platform :ios, '8.0'
use_frameworks!

# Error & crash reporting pods
def reporting_pods
	pod 'HockeySDK'
	pod "Lookback", :configurations => ["Debug", "Release"]
end

# Shared pods
def shared_pods
	pod 'CocoaLumberjack'
	pod 'Mantle'
	pod 'JGProgressHUD'
	pod 'AFNetworking', '2.6.1'
end

abstract_target 'Shared' do
	shared_pods

	target 'AlfrescoActiviti' do
		reporting_pods
	end

	target 'ActivitiSDK' do
	end
end

target 'AlfrescoActivitiTests' do
end

target 'ActivitiSDKTests' do
end