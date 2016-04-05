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

#import <Foundation/Foundation.h>

@class ASDKModelPaging;

typedef void  (^AFAFilterServicesFilterListCompletionBlock) (NSArray *filterList, NSError *error, ASDKModelPaging *paging);

@interface AFAFilterServices : NSObject

/**
 *  Performs a request for the default defined task filter list in the Activiti installation that are not
 *  associated with any application.
 *
 *  @param completionBlock Completion block providing the filter list, an optional error reason and
 pagination information
 */
- (void)requestTaskFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock;

/**
 *  Performs a request for the task filter list in the Activiti installation that are associated with an
 *  application.
 *
 *  @param appID            The appID for which the filter list is requested
 *  @param completionBlock  Completion block providing the filter list, an optional error reason and
 *                          pagination information
 */
- (void)requestTaskFilterListForAppID:(NSString *)appID
                  withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock;

/**
 *  Performs a request for the default defined process instance filter list in the Activiti installation that
 *  are not associated with any application.
 *
 *  @param completionBlock Completion block providing the filter list, an optional error reason and
 *                         pagination information
 */
- (void)requestProcessInstanceFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock;

/**
 *  Performs a request for the process instance filter list in the Activiti installation that are associated 
 *  with an application.
 *
 *  @param appID           The ID for which the filter list is requested
 *  @param completionBlock Completion block providing the filter list, an optional error reason and pagination
 *                         information
 */
- (void)requestProcessInstanceFilterListForAppID:(NSString *)appID
                             withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock;

@end
