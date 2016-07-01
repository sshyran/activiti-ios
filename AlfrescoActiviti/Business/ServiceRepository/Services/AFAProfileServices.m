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

#import "AFAProfileServices.h"

// Constants
#import "AFABusinessConstants.h"

// Configurations
#import "AFALogConfiguration.h"

// Managers
#import "AFAKeychainWrapper.h"
@import ActivitiSDK;

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAProfileServices ()

@property (strong, nonatomic) dispatch_queue_t              profileUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKProfileNetworkServices    *profileNetworkService;

@end

@implementation AFAProfileServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.profileUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.profileNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKProfileNetworkServiceProtocol)];
        self.profileNetworkService.resultsQueue = self.profileUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestLoginForServerConfiguration:(ASDKModelServerConfiguration *)serverConfiguration
                       withCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock {
    NSParameterAssert(serverConfiguration);
    NSParameterAssert(completionBlock);
    
    [self.profileNetworkService authenticateUser:serverConfiguration.username
                                    withPassword:serverConfiguration.password
                             withCompletionBlock:^(BOOL didAutheticate, NSError *error) {
                                 if (!error && didAutheticate) {
                                     AFALogVerbose(@"User logged in successfully");
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock(YES, nil);
                                     });
                                 } else {
                                     AFALogError(@"An error occured while the user tried to login. Reason:%@", error.localizedDescription);
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock(NO, error);
                                     });
                                 }
                             }];
}

- (void)requestLogoutWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.profileNetworkService logoutWithCompletionBlock:^(BOOL isLogoutPerformed, NSError *error) {
        if (!error && isLogoutPerformed) {
            AFALogVerbose(@"User logged out successfully");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(NO, nil);
            });
        } else {
            AFALogError(@"An error occured while the user tried to logout. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
               completionBlock(YES, error);
            });
        }
    }];
}

- (void)requestProfileImageWithCompletionBlock:(AFAProfileServicesProfileImageCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.profileNetworkService fetchProfileImageWithCompletionBlock:^(UIImage *profileImage, NSError *error) {
        if (!error) {
            AFALogVerbose(@"Profile image fetched successfully (%@)", profileImage ? @"ContentAvailable" : @"NoContent");
            
            dispatch_async(dispatch_get_main_queue(), ^{
               completionBlock(profileImage, nil);
            });
        } else {
            AFALogError(@"An error occured while loading the profile picture. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
    }];
}

- (void)requestProfileWithCompletionBlock:(AFAProfileCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.profileNetworkService fetchProfileWithCompletionBlock:^(ASDKModelProfile *profile, NSError *error) {
        if (!error) {
            AFALogVerbose(@"Profile information fetched successfully for user :%@", [NSString stringWithFormat:@"%@ %@", profile.userFirstName, profile.userLastName]);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(profile, nil);
            });
        } else {
            AFALogError(@"An error occured while fetching profile information for the current user. Reason:%@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error);
            });
        }
    }];
}

- (void)requestProfileUpdateWithModel:(ASDKModelProfile *)profileModel
                      completionBlock:(AFAProfileCompletionBlock)completionBlock {
    NSParameterAssert(profileModel);
    NSParameterAssert(completionBlock);
    
    [self.profileNetworkService updateProfileWithModel:profileModel
                                       completionBlock:^(ASDKModelProfile *profile, NSError *error) {
                                           if (!error) {
                                               AFALogVerbose(@"Profile information updated successfully for the current user.");
                                               
                                               // If the user updated the email address (username) then replace the authentication provider in the
                                               // SDK with the new username and also update the keychain values if the user checked the remember
                                               // credentials option
                                               ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
                                               if (![profile.email isEqualToString:sdkBootstrap.serverConfiguration.username]) {
                                                   ASDKBasicAuthentificationProvider *authenticationProvider = [[ASDKBasicAuthentificationProvider alloc] initWithUserName:profile.email
                                                                                                                                                                  password:sdkBootstrap.serverConfiguration.password];
                                                   [sdkBootstrap replaceAuthenticationProvider:authenticationProvider];
                                                   
                                                   if ([AFAKeychainWrapper keychainStringFromMatchingIdentifier:kUsernameCredentialIdentifier]) {
                                                       [AFAKeychainWrapper updateKeychainValue:profile.email
                                                                                 forIdentifier:kUsernameCredentialIdentifier];
                                                   }
                                               }
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock(profile, nil);
                                               });
                                           } else {
                                               AFALogError(@"An error occured while updating profile information for the current user. Reason:%@", error.localizedDescription);
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock(nil, error);
                                               });
                                           }
    }];
}

- (void)requestProfilePasswordUpdatedWithNewPassword:(NSString *)updatedPassword
                                         oldPassword:(NSString *)oldPassword
                                     completionBlock:(AFAProfilePasswordCompletionBlock)completionBlock {
    NSParameterAssert(updatedPassword);
    NSParameterAssert(oldPassword);
    
    [self.profileNetworkService updateProfileWithNewPassword:updatedPassword
                                                 oldPassword:oldPassword
                                             completionBlock:^(BOOL isPasswordUpdated, NSError *error) {
                                                 if (!error) {
                                                     AFALogVerbose(@"Profile password updated successfully for the current user.");
                                                     
                                                     // If the password has been updated replace the authentication provider in the SDK with
                                                     // the new password and also update the keychain values if the user checked the remember
                                                     // credentials option
                                                     if (isPasswordUpdated) {
                                                         ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
                                                         ASDKBasicAuthentificationProvider *authenticationProvider = [[ASDKBasicAuthentificationProvider alloc] initWithUserName:sdkBootstrap.serverConfiguration.username
                                                                                                                                                                        password:updatedPassword];
                                                         [sdkBootstrap replaceAuthenticationProvider:authenticationProvider];
                                                         
                                                         if ([AFAKeychainWrapper keychainStringFromMatchingIdentifier:kPasswordCredentialIdentifier]) {
                                                             [AFAKeychainWrapper updateKeychainValue:updatedPassword
                                                                                       forIdentifier:kPasswordCredentialIdentifier];
                                                         }
                                                     }
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(isPasswordUpdated, nil);
                                                     });
                                                 } else {
                                                     AFALogError(@"An error occured while updating profile password for the current user. Reason:%@", error.localizedDescription);
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(NO, error);
                                                     });
                                                 }
    }];
}

- (void)requestUploadProfileImageAtFileURL:(NSURL *)fileURL
                               contentData:(NSData *)contentData
                             progressBlock:(AFAProfileContentProgressBlock)progressBlock
                           completionBlock:(AFAProfileContentUploadCompletionBlock)completionBlock {
    NSParameterAssert(fileURL);
    NSParameterAssert(contentData);
    NSParameterAssert(completionBlock);
    
    ASDKModelFileContent *fileContentModel = [ASDKModelFileContent new];
    fileContentModel.modelFileURL = fileURL;
    
    [self.profileNetworkService uploadProfileImageWithModel:fileContentModel
                                        contentData:contentData
                                      progressBlock:^(NSUInteger progress, NSError *error) {
                                          AFALogVerbose(@"Profile image is %lu%% uploaded", (unsigned long)progress);
                                          
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              progressBlock (progress, error);
                                          });
                                      } completionBlock:^(ASDKModelContent *profileImageContent, NSError *error) {
                                          if (!error) {
                                              AFALogVerbose(@"Profile image was succesfully uploaded");
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (YES, nil);
                                              });
                                          } else {
                                              AFALogError(@"An error occured while uploading the profile picture. Reason:%@", error.localizedDescription);
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (NO, error);
                                              });
                                          }
                                      }];
}

- (void)cancellProfileNetworkRequests {
    [self.profileNetworkService cancelAllProfileNetworkOperations];
}

@end
