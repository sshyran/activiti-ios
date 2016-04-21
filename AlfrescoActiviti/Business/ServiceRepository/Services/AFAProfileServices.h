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

@import Foundation;
@import UIKit;

@class ASDKModelServerConfiguration,
ASDKModelProfile;

typedef void  (^AFAProfileServicesLoginCompletionBlock) (BOOL isLoggedIn, NSError *error);
typedef void  (^AFAProfileServicesProfileImageCompletionBlock) (UIImage *profileImage, NSError *error);
typedef void  (^AFAProfileCompletionBlock) (ASDKModelProfile *profile, NSError *error);

@interface AFAProfileServices : NSObject

/**
 *  Performs a login call based on values from an already provided server configuration
 *
 *  @param serverConfiguration  Container object that encapsulates information needed to perform a
 *                              user authetication
 *  @param completionBlock      Completion block describing whether the login was successful and an
                                optional error reason.
 */
- (void)requestLoginForServerConfiguration:(ASDKModelServerConfiguration *)serverConfiguration
                       withCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock;

/**
 *  Performs a logout call for the current logged in user
 *
 *  @param completionBlock Completion block describing whether the logout was successful and an
 *                         optional error reason.
 */
- (void)requestLogoutWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock;

/**
 *  Performs a request for the profile image
 *
 *  @param completionBlock Completion block providing an UIImage instance and an optional error reason
 */
- (void)requestProfileImageWithCompletionBlock:(AFAProfileServicesProfileImageCompletionBlock)completionBlock;

/**
 *  Performs a request for the detailed profile information
 *
 *  @param completionBlock Completion block providing a reference to the profile model object and an
 *                         optional error reason.
 */
- (void)requestProfileWithCompletionBlock:(AFAProfileCompletionBlock)completionBlock;

/**
 *  Cancels all requests related to profile activity
 */
- (void)cancellProfileNetworkRequests;

@end
