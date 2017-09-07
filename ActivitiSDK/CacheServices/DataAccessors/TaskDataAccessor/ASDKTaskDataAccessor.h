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

#import "ASDKDataAccessor.h"

@class ASDKFilterRequestRepresentation,
ASDKTaskUpdateRequestRepresentation,
ASDKModelContent;

@interface ASDKTaskDataAccessor : ASDKDataAccessor

/**
 * Requests a list of tasks for the current logged in user conforming to the properties 
 * of a provided filter and reports network or cached data through the designated
 * data accessor delegate.
 *
 * @param filter Filter object describing which subset of the task list should be fetched
 */
- (void)fetchTasksWithFilter:(ASDKFilterRequestRepresentation *)filter;

/**
 * Requests the details of a task and reports network or cached data through the designated
 * data accessor delegate.
 *
 * @param taskID The ID of the task for which the details are requested
 */
- (void)fetchTaskDetailsForTaskID:(NSString *)taskID;

/**
 * Requests the content associated with a task and reports network or cached data through the 
 * designated data accessor delegate.
 *
 * @param taskID The ID of the task for which the content is requested
 */
- (void)fetchTaskContentForTaskID:(NSString *)taskID;

/**
 * Requests the comments associated with a task and reports network or cached data through the
 * designated data accessor delegate.
 *
 * @param taskID The ID of the task for which the comments are requested
 */
- (void)fetchTaskCommentsForTaskID:(NSString *)taskID;

/**
 * Requests the checklist tasks associated with a task and reports network or cached data 
 * through the designated data accessor delegate.
 *
 * @param taskID The ID of the task for which the checklist is requested
 */
- (void)fetchTaskCheckListForTaskID:(NSString *)taskID;

/**
 * Updates a task's details with properties defined within the update representation and
 * reports through the designated data accessor delegate.
 *
 * @param taskID                    The ID of the task for which the update is performed
 * @param taskUpdateRepresentation  Model object describing the task properties to be updated
 */
- (void)updateTaskWithID:(NSString *)taskID
      withRepresentation:(ASDKTaskUpdateRequestRepresentation *)taskUpdateRepresentation;

/**
 * Attempts to complete the specified task and reports the result through the designated
 * data accessor delegate.
 *
 * @param taskID The ID of the task for which the completion is requested
 */
- (void)completeTaskWithID:(NSString *)taskID;

/**
 * Uploads task associated content defined as an NSData object for the given task ID. Additional information
 * that is needed for the upload process should be provided as a URL for the resource to
 * be uploaded.
 *
 * @param taskID        The ID of the task for which the content upload is performed
 * @param fileURL       URL of the resource to be uploaded
 * @param contentData   NSData object with the actual content
 */
- (void)uploadContentForTaskWithID:(NSString *)taskID
                   fromFileURL:(NSURL *)fileURL
               withContentData:(NSData *)contentData;


/**
 * Requests the specified content associated with a task and reports network or cached data
 * through the designated data accessor delegate.
 *
 * @param content Content to be downloaded
 */
- (void)downloadTaskContent:(ASDKModelContent *)content;

/**
 * Requests the thumbnail representation that is associated with a task's content and reports
 * network or cached data through the designated data accesor delegate.
 *
 * @param content Content to be downloaded
 */
- (void)downloadThumbnailForTaskContent:(ASDKModelContent *)content;

/**
 * Deletes the passed content that was previously associated with a task.
 *
 * @param content Content to be deleted
 */
- (void)deleteContent:(ASDKModelContent *)content;

/**
 * Cancels ongoing operations for the current data accessor.
 */
- (void)cancelOperations;

@end
