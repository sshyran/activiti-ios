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

@class ASDKModelPaging,
ASDKFilterRequestRepresentation;

typedef void  (^ASDKCacheServiceTaskListCompletionBlock) (NSArray *taskList, NSError *error, ASDKModelPaging *paging);

@protocol ASDKTaskCacheServiceProtocol <NSObject>

/**
 * Caches provided tasks by leveraging information from the filter that was provided
 * to the actual network request and reports the operation success over a completion block.
 * The filter is provided to identify information such as to which application the tasks
 * are afiliated, what task page are we loading in etc.
 *
 * @param taskList          List of tasks to be cached
 * @param filter            Filter object describing the membership of tasks in relation
 *                          to applications and specific page that has been loaded.
 * @param completionBlock   Completion block indicating the success of the operation
 */
- (void)cacheTaskList:(NSArray *)taskList
          usingFilter:(ASDKFilterRequestRepresentation *)filter
  withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock;


/**
 * Fetches a subset of the task list conforming to the passed filter description.
 * The filter contains information such as to which application are the tasks afiliated to
 * the page at which the tasks are retrieved and so on.
 *
 * @param filter:           Filter object describing the rules of selection from the total available set
 * @param completionBlock   Completion block providing a list of model objects, paging
 *                          information and an optional error reason
 */
- (void)fetchTaskList:(ASDKCacheServiceTaskListCompletionBlock)completionBlock
          usingFilter:(ASDKFilterRequestRepresentation *)filter;

@end
