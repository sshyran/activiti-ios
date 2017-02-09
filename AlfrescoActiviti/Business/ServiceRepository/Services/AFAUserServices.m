/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

#import "AFAUserServices.h"
@import ActivitiSDK;

// Configurations
#import "AFALogConfiguration.h"

// Models
#import "AFAUserFilterModel.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAUserServices ()

@property (strong, nonatomic) dispatch_queue_t              userUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKUserNetworkServices       *userNetworkService;

@end

@implementation AFAUserServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.userUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.userNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKUserNetworkServiceProtocol)];
        self.userNetworkService.resultsQueue = self.userUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestUsersWithUserFilter:(AFAUserFilterModel *)filter
                   completionBlock:(AFAUserServicesFetchCompletionBlock)completionBlock {
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    
    ASDKUserRequestRepresentation *userRequestRepresentation = [ASDKUserRequestRepresentation new];
    userRequestRepresentation.filter = filter.name;
    userRequestRepresentation.email = filter.email;
    userRequestRepresentation.excludeTaskID = filter.excludeTaskID;
    userRequestRepresentation.excludeProcessID = filter.excludeProcessID;
    userRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    [self.userNetworkService fetchUsersWithUserRequestRepresentation:userRequestRepresentation
                                                     completionBlock:^(NSArray *users, NSError *error, ASDKModelPaging *paging) {
        if (!error && users) {
            AFALogVerbose(@"Fetched %lu user entries", (unsigned long)users.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock (users, nil, paging);
            });
        } else {
            AFALogError(@"An error occured while fetching the user list. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error, nil);
            });
        }
    }];
}

- (void)requestPictureForUserID:(NSString *)userID
                completionBlock:(AFAUserPictureCompletionBlock)completionBlock {
    NSParameterAssert(userID);
    NSParameterAssert(completionBlock);
    
    [self.userNetworkService fetchPictureForUserID:userID
                                   completionBlock:^(UIImage *profileImage, NSError *error) {
       if (!error && profileImage) {
           AFALogVerbose(@"Fetched profile picture for user ID:%@", userID);
           
           dispatch_async(dispatch_get_main_queue(), ^{
               completionBlock (profileImage, nil);
           });
       } else {
           AFALogError(@"An error occured while fetching the profile picture for user ID:%@. Reason:%@", userID, error.localizedDescription);
           
           dispatch_async(dispatch_get_main_queue(), ^{
               completionBlock(nil, error);
           });
       }
    }];
}


@end
