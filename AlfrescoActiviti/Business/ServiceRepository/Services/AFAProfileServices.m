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
@import ActivitiSDK;

// Configurations
#import "AFALogConfiguration.h"

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
            AFALogVerbose(@"Profile information fetched successfully for user :%@", [NSString stringWithFormat:@"%@ %@", profile.firstName, profile.lastName]);
            
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

- (void)cancellProfileNetworkRequests {
    [self.profileNetworkService cancelAllProfileNetworkOperations];
}

@end
