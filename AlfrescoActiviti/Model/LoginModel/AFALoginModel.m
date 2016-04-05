/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile iOS App.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ******************************************************************************/

#import "AFALoginModel.h"

// Constants
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"

// Categories
#import "UIColor+AFATheme.h"

// Models
#import "AFACredentialModel.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAKeychainWrapper.h"

@import ActivitiSDK;

@interface AFALoginModel ()

@property (strong, nonatomic) AFACredentialModel *credentialModel;

@end

@implementation AFALoginModel


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.usernameAttributedPlaceholderText = [[NSAttributedString alloc] initWithString:NSLocalizedString(kLocalizationLoginUsernamePlaceholderText, @"Username placeholder text")
                                                                                 attributes:@{NSForegroundColorAttributeName : [UIColor placeholderColorForCredentialTextField]}];
        self.passwordAttributedPlaceholderText = [[NSAttributedString alloc] initWithString:NSLocalizedString(kLocalizationLoginPasswordPlaceholderText, @"Password placeholder text")
                                                                                 attributes:@{NSForegroundColorAttributeName : [UIColor placeholderColorForCredentialTextField]}];
        self.hostnameAttributedPlaceholderText = [[NSAttributedString alloc] initWithString:NSLocalizedString(kLocalizationLoginHostnamePlaceholderText, @"Hostname placeholder text")
                                                                                 attributes:@{NSForegroundColorAttributeName : [UIColor placeholderColorForCredentialTextField]}];
        self.credentialModel = [AFACredentialModel new];
    }
    
    return self;
}

#pragma mark -
#pragma mark Public interface

- (void)updateHostNameEntry:(NSString *)hostname {
    self.credentialModel.hostname = hostname;
}

- (void)updateUserNameEntry:(NSString *)username {
    self.credentialModel.username = username;
}

- (void)updatePasswordEntry:(NSString *)password {
    self.credentialModel.password = password;
}

- (void)updateRememberCredentials:(BOOL)rememberCredentials {
    self.credentialModel.rememberCredentials = rememberCredentials;
}

- (void)updateCommunicationOverSecureLayer:(BOOL)secureLayer {
    self.credentialModel.isCommunicationOverSecureLayer = secureLayer;
}

- (BOOL)canUserSignIn {
    return self.credentialModel.hostname.length &&
    self.credentialModel.username.length &&
    self.credentialModel.password.length;
}

- (void)requestLoginWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock {
    // Authorization in progress
    self.authState = AFALoginViewModelAuthentificationStateInProgress;

    // Create the server configuration for the SDK bootstrap
    ASDKModelServerConfiguration *serverConfiguration = [ASDKModelServerConfiguration new];
    serverConfiguration.hostAddress = self.credentialModel.hostname;
    serverConfiguration.username = self.credentialModel.username;
    serverConfiguration.password = self.credentialModel.password;
    serverConfiguration.isCommunicationOverSecureLayer = self.credentialModel.isCommunicationOverSecureLayer;
    
    // Initiate the Activiti SDK bootstrap with the given server configuration
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    [sdkBootstrap setupServicesWithServerConfiguration:serverConfiguration];
    
    // Register a clean profile services instance
    AFAServiceRepository *serviceRepository = [AFAServiceRepository sharedRepository];
    if ([serviceRepository serviceObjectForPurpose:AFAServiceObjectTypeProfileServices]) {
        [serviceRepository removeServiceForPurpose:AFAServiceObjectTypeProfileServices];
    }
    
    AFAProfileServices *profileServices = [AFAProfileServices new];
    [serviceRepository registerServiceObject:profileServices
                                  forPurpose:AFAServiceObjectTypeProfileServices];
    
    __weak typeof(self) weakSelf = self;
    [profileServices requestLoginForServerConfiguration:serverConfiguration
                                    withCompletionBlock:^(BOOL isLoggedIn, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        // Check first if the request wasn't previously canceled
        if (AFALoginViewModelAuthentificationStateCanceled != strongSelf.authState &&
            AFALoginViewModelAuthentificationStatePreparing != strongSelf.authState) {
            if (!error && isLoggedIn) {
                // Login is successfull - Check whether the user has choosen to remember credentials
                // and store them in the keychain
                if (self.credentialModel.rememberCredentials) {
                    // Former credentials are registered, will update them
                    
                    NSString *isCommunicationOverSecureLayerString = serverConfiguration.isCommunicationOverSecureLayer ? kBooleanTrueCredentialIdentifier : kBooleanFalseCredentialIdentifier;
                    
                    if ([AFAKeychainWrapper keychainStringFromMatchingIdentifier:kUsernameCredentialIdentifier] &&
                        [AFAKeychainWrapper keychainStringFromMatchingIdentifier:kPasswordCredentialIdentifier]) {
                        [AFAKeychainWrapper updateKeychainValue:serverConfiguration.username
                                                  forIdentifier:kUsernameCredentialIdentifier];
                        [AFAKeychainWrapper updateKeychainValue:serverConfiguration.password
                                                  forIdentifier:kPasswordCredentialIdentifier];
                        [AFAKeychainWrapper updateKeychainValue:serverConfiguration.hostAddress
                                                  forIdentifier:kHostNameCredentialIdentifier];
                        [AFAKeychainWrapper updateKeychainValue:isCommunicationOverSecureLayerString
                                                  forIdentifier:kSecureLayerCredentialIdentifier];
                    } else { // Insert new values in the keychain
                        [AFAKeychainWrapper createKeychainValue:serverConfiguration.username
                                                  forIdentifier:kUsernameCredentialIdentifier];
                        [AFAKeychainWrapper createKeychainValue:serverConfiguration.password
                                                  forIdentifier:kPasswordCredentialIdentifier];
                        [AFAKeychainWrapper createKeychainValue:serverConfiguration.hostAddress
                                                  forIdentifier:kHostNameCredentialIdentifier];
                        [AFAKeychainWrapper createKeychainValue:isCommunicationOverSecureLayerString
                                                  forIdentifier:kSecureLayerCredentialIdentifier];
                    }
                }
                
                strongSelf.authState = AFALoginViewModelAuthentificationStateAuthorized;
                completionBlock(YES, nil);
            } else {
                // An error occured
                strongSelf.authState = AFALoginViewModelAuthentificationStateFailed;
                
                [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kUsernameCredentialIdentifier];
                [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kPasswordCredentialIdentifier];
                [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kHostNameCredentialIdentifier];
                [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kSecureLayerCredentialIdentifier];
                
                completionBlock(NO, error);
            }
        }
    }];
}

- (void)requestLogoutWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock {
    AFAServiceRepository *serviceRepository = [AFAServiceRepository sharedRepository];
    AFAProfileServices *profileServices = [serviceRepository serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    
    __weak typeof(self) weakSelf = self;
    [profileServices requestLogoutWithCompletionBlock:^(BOOL isLoggedIn, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error && !isLoggedIn) {
            // Logout is successful - remove also any remembered credentials from the keychain
            [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kUsernameCredentialIdentifier];
            [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kPasswordCredentialIdentifier];
            [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kHostNameCredentialIdentifier];
            [AFAKeychainWrapper deleteItemFromKeychainWithIdentifier:kSecureLayerCredentialIdentifier];
            
            strongSelf.authState = AFALoginViewModelAuthentificationStateLoggedOut;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(NO, nil);
            });
        } else {
            // An error occured
            strongSelf.authState = AFALoginViewModelAuthentificationStateFailed;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(YES, error);
            });
        }
    }];
}

- (void)cancelLoginRequest {
    // If user performed an action, meaning the authorization state changes
    // from preparing state then cancel the authorization
    if (AFALoginViewModelAuthentificationStatePreparing != self.authState) {
        self.authState = AFALoginViewModelAuthentificationStateCanceled;
    }
    
    // Cancel also the request
     AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    [profileServices cancellProfileNetworkRequests];
}

@end
