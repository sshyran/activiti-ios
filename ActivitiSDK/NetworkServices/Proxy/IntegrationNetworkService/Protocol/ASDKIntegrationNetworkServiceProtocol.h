/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile SDK.
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

#import <Foundation/Foundation.h>

@class ASDKModelPaging;

typedef void  (^ASDKIntegrationAccountListCompletionBlock) (NSArray *accounts, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationNetworkListCompletionBlock) (NSArray *networks, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKIntegrationSiteListCompletionBlock) (NSArray *sites, NSError *error, ASDKModelPaging *paging);

@protocol ASDKIntegrationNetworkServiceProtocol <NSObject>

/**
 *  Fetches and returns via the completion block a list of external integration service accounts  
 *
 *  @param completionBlock Completion block providing an integration account list, an optional
 *                         error reason and paging information
 */
- (void)fetchIntegrationAccountsWithCompletionBlock:(ASDKIntegrationAccountListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of external integration networks
 *
 *  @param completionBlock Completion block providing a network list, an optional error reason and
 *                         paging information
 */
- (void)fetchIntegrationNetworksWithCompletionBlock:(ASDKIntegrationNetworkListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the completion block a list of external integration sites that are
 *  associated with a specified network ID.
 * 
 *  @param networkID       The network ID for which the site list is retrieved
 *
 *  @param completionBlock Completion block providing a site list, an optional error reason and 
 *                         pagin information
 */
- (void)fetchIntegrationSitesForNetworkID:(NSString *)networkID
                          completionBlock:(ASDKIntegrationSiteListCompletionBlock)completionBlock;

@end
