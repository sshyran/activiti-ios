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

typedef void (^ASDKCacheServiceTaskRestFieldValuesCompletionBlock) (NSArray *restFieldValues, NSError *error);

@protocol ASDKFormCacheServicesProtocol <NSObject>

/**
 * Caches provided rest field value list for the specified task and field ID and
 * reports the operation success over a completion block.
 *
 @param restFieldValues List of rest field values to be cached
 @param taskID          Task ID describing the membership of rest field value items
 @param fieldID         ID of the form field the rest values are assigned to
 @param completionBlock Completion block indicating the success of the operation
 */
- (void)cacheRestFieldValues:(NSArray *)restFieldValues
                   forTaskID:(NSString *)taskID
             withFormFieldID:(NSString *)fieldID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock;

/**
 * Fetches and reports via a completion block the rest field values for the specified
 * task ID and form field ID.
 *
 @param taskID          Task ID describing the membership of rest field value items
 @param fieldID         ID of the form field the rest values are assigned to
 @param completionBlock Completion block returning the rest field values
 */
- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID
                  withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock;

/**
 * Caches provided rest field value list for the specified process definition and
 * field ID and reports the operation success over a completion block.
 *
 * @param restFieldValues       List of rest field values to be cached
 * @param processDefinitionID   Process definition ID of the start form for which the rest
 *                              field values are cached
 * @param fieldID               ID of the form field the rest values are assigned to
 * @param completionBlock       Completion block indicating the success of the operation
 */
- (void)cacheRestFieldValues:(NSArray *)restFieldValues
      forProcessDefinitionID:(NSString *)processDefinitionID
             withFormFieldID:(NSString *)fieldID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock;

/**
 * Fetches and reports via a completion block the rest field values of the start form
 * for the specified process definition ID and form field ID.
 *
 * @param processDefinitionID   Process definition ID of the start form for which the rest
 *                              field values are retrieved from cache
 * @param fieldID               ID of the form field the rest values are assigned to
 * @param completionBlock       Completion block returning the rest field values
 */
- (void)fetchRestFieldValuesForProcessDefinitionID:(NSString *)processDefinitionID
                                   withFormFieldID:(NSString *)fieldID
                               withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock;

/**
 * Caches provided rest field value list for the specified dynamic table attached to
 * a task form and reports the operation success over a completion block.
 *
 * @param restFieldValues   List of rest field values to be cached
 * @param taskID            Task ID describing the membership of the dynamic table
 * @param fieldID           ID of the form field the rest values are assigned to
 * @param columnID          ID of the dynamic table column the rest values are assigned to
 * @param completionBlock   Completion block indicating the success of the operation
 */
- (void)cacheRestFieldValues:(NSArray *)restFieldValues
                   forTaskID:(NSString *)taskID
             withFormFieldID:(NSString *)fieldID
                withColumnID:(NSString *)columnID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock;

/**
 * Fetches and reports via a completion block the rest field values assigned to
 * the specified dynamic table that is part of a task form.
 *
 * @param taskID            Task ID describing the membership of the dynamic table
 * @param fieldID           ID of the form field the rest values are assigned to
 * @param columnID          ID of the dynamic table column the rest values are assigned to
 * @param completionBlock   Completion block returning the rest field values
 */
- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID
                         withColumnID:(NSString *)columnID
                  withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock;

@end
