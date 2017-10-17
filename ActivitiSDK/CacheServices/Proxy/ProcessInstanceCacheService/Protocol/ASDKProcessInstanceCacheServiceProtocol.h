/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

@class ASDKFilterRequestRepresentation, ASDKModelPaging;

typedef void  (^ASDKCacheServiceProcessInstanceListCompletionBlock) (NSArray *processes, NSError *error, ASDKModelPaging *paging);

@protocol ASDKProcessInstanceCacheServiceProtocol <NSObject>

/**
 * Caches provided process instances by leveraging information from the filter that was provided
 * to the actual network request and reports the operation success over a completion block.
 * The filter is provided to identify information such as to which application the process
 * instances are afiliated, what task page are we loading in etc.
 *
 * @param processInstanceList   List of process instances to be cached
 * @param filter                Filter object describing the membership of process instances
 *                              in relation to applications and specific page that has been
 *                              loaded.
 * @param completionBlock       Completion block indicating the success of the operation
 */
- (void)cacheProcessInstanceList:(NSArray *)processInstanceList
                     usingFilter:(ASDKFilterRequestRepresentation *)filter
             withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock;

/**
 * Fetches a subset of the process instance list conforming to the passed filter description.
 * The filter contains information such as to which application are the process instances afiliated
 * to the page at which the tasks are retrieved and so on.
 *
 * @param filter:           Filter object describing the rules of selection from the total available set
 * @param completionBlock   Completion block providing a list of model objects, paging
 *                          information and an optional error reason
 */
- (void)fetchProcessInstanceList:(ASDKCacheServiceProcessInstanceListCompletionBlock)completionBlock
          usingFilter:(ASDKFilterRequestRepresentation *)filter;

@end
