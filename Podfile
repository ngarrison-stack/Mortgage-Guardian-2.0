platform :ios, '17.0'

target 'MortgageGuardian' do
  use_frameworks!

  # Use the Plaid pod which includes LinkKit
  pod 'Plaid', '~> 5.6.0'

  # Additional dependencies for enhanced functionality
  pod 'Alamofire', '~> 5.9.0'        # Networking
  pod 'KeychainAccess', '~> 4.2.0'    # Secure storage

end

# Post-install configuration
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
