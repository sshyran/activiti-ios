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

@class ASDKTaskRequestRepresentation,
ASDKFilterRequestRepresentation,
ASDKTaskUpdateRequestRepresentation,
ASDKModelPaging,
ASDKModelTask,
ASDKModelContent,
ASDKModelFileContent,
ASDKModelUser,
ASDKModelComment,
ASDKTaskCreationRequestRepresentation;

typedef void  (^ASDKTaskListCompletionBlock) (NSArray *taskList, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKTaskDetailsCompletionBlock) (ASDKModelTask *task, NSError *error);
typedef void  (^ASDKTaskContentCompletionBlock) (NSArray *contentList, NSError *error);
typedef void  (^ASDKTaskCommentsCompletionBlock) (NSArray *commentList, NSError *error, ASDKModelPaging *paging);
typedef void  (^ASDKTaskUpdateCompletionBlock) (BOOL isTaskUpdated, NSError *error);
typedef void  (^ASDKTaskCompleteCompletionBlock) (BOOL isTaskCompleted, NSError *error);
typedef void  (^ASDKTaskContentUploadCompletionBlock) (BOOL isContentUploaded, NSError *error);
typedef void  (^ASDKTaskContentProgressBlock) (NSUInteger progress, NSError *error);
typedef void  (^ASDKTaskContentDownloadProgressBlock) (NSString *formattedReceivedBytesString, NSError *error);
typedef void  (^ASDKTaskContentDeletionCompletionBlock) (BOOL isContentDeleted, NSError *error);
typedef void  (^ASDKTaskContentDownloadCompletionBlock) (NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error);
typedef void  (^ASDKTaskUserInvolvementCompletionBlock) (BOOL isUserInvolved, NSError *error);
typedef void  (^ASDKTaskCreateCommentCompletionBlock) (ASDKModelComment *comment, NSError *error);
typedef void  (^ASDKTaskClaimCompletionBlock) (BOOL isTaskClaimed, NSError *error);

@protocol ASDKTaskNetworkServiceProtocol <NSObject>

/**
 *  Fetches an returns via the provided completion block a list of ASDKModelTask objects
 *  that conform to the properties of a filter object.
 *
 *  @param filter          Filter object describing which subset of the task list
 *                         collection should be fetched
 *  @param completionBlock Completion block providing the task list, an optional error reason and
 *                         pagination information
 */
- (void)fetchTaskListWithTaskRepresentationFilter:(ASDKTaskRequestRepresentation *)filter
                                  completionBlock:(ASDKTaskListCompletionBlock)completionBlock;

/**
 *  Fetches an returns via the provided completion block a list of ASDKModelTask objects
 *  that conform to the properties of a filter object.
 *
 *  @param filter          Filter object describing which subset of the task list
 *                         collection should be fetched
 *  @param completionBlock Completion block providing the task list, an optional error reason and
 *                         pagination information
 */
- (void)fetchTaskListWithFilterRepresentation:(ASDKFilterRequestRepresentation *)filter
                              completionBlock:(ASDKTaskListCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the provided completion block a ASDKModelTask object with all
 *  it's associated information.
 *
 *  @param taskID          ID of the task for which information is requested
 *  @param completionBlock Completion block providing the task object model and an optional error reason
 */
- (void)fetchTaskDetailsForTaskID:(NSString *)taskID
                  completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the provided completion block a ASDKModelContent object list that contains
 *  a description of the attached content for the given task ID.
 *
 *  @param taskID          ID of the task for which the content is requested
 *  @param completionBlock Completion block providing the content object list and an optional error reason
 */
- (void)fetchTaskContentForTaskID:(NSString *)taskID
                  completionBlock:(ASDKTaskContentCompletionBlock)completionBlock;

/**
 *  Fetches and returns via the provided completion block a list of ASDKModelComment objects describing
 *  comments made by other users on the mentioned task.
 *
 *  @param taskID          ID of the task for which the comments list is requested
 *  @param completionBlock Completion block providing the comments list, an optional error reason and
 *                         pagination information
 */
- (void)fetchTaskCommentsForTaskID:(NSString *)taskID
                   completionBlock:(ASDKTaskCommentsCompletionBlock)completionBlock;

/**
 *  Creates and returns a comment for a mentioned task ID via the provided completion block
 *
 *  @param comment         The body of the content
 *  @param taskID          ID of the task for which the comment is created
 *  @param completionBlock Completion block providing a created comment and an optional error reason
 */
- (void)createComment:(NSString *)comment
            forTaskID:(NSString *)taskID
      completionBlock:(ASDKTaskCreateCommentCompletionBlock)completionBlock;

/**
 *  Updates the mentioned task for one of / a combination of the values: name, description and dueDate.
 *
 *  @param taskID             ID of the task for which the update is intended
 *  @param taskRepresentation Object encapsulating the information that needs to be updated
 *  @param completionBlock    Completion block providing information on whether the update was successfully
 *                            or not and an optional error reason
 */
- (void)updateTaskForTaskID:(NSString *)taskID
     withTaskRepresentation:(ASDKTaskUpdateRequestRepresentation *)taskRepresentation
            completionBlock:(ASDKTaskUpdateCompletionBlock)completionBlock;

/**
 *  Marks as completed the mentioned task
 *
 *  @param taskID          ID of the task to be marked as complete
 *  @param completionBlock Completion block providing information on whether the task wask marked to be
 *                         completed successfully or not and an optional error reason
 */
- (void)completeTaskForTaskID:(NSString *)taskID
              completionBlock:(ASDKTaskCompleteCompletionBlock)completionBlock;

/**
 *  Uploads content from URL encapsulated inside a ASDKModelFileContent object for an ID associated task and reports
 *  back via a completion block progress and optional errors that might occur.
 *
 *  @param file            Content model encapsulating file information needed for the upload
 *  @param taskID          ID of the task for which the content is uploaded
 *  @param progressBlock   Block providing information on the upload progress and an optional error reason
 *  @param completionBlock Completion block providing information on whether the upload finished successfully
 *                         and an optional error reason.
 */
- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                     forTaskID:(NSString *)taskID
                 progressBlock:(ASDKTaskContentProgressBlock)progressBlock
               completionBlock:(ASDKTaskContentUploadCompletionBlock)completionBlock;

/**
 *  Uploads provided content data for an ID associated task and reports back via a completion and progress blocks
 *  the status of the upload, whether the operation was successfull and optional errors that might occur.
 *
 *  @param file            Content model encapsulating file information needed for the upload
 *  @param contentData     NSData object of the content to be uploaded
 *  @param taskID          ID of the task for which the content is uploaded
 *  @param progressBlock   Block providing information on the upload progress and an optional error reason
 *  @param completionBlock Completion block providing information on whether the upload finished successfully
 *                         and an optional error reason.
 */
- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                   contentData:(NSData *)contentData
                     forTaskID:(NSString *)taskID
                 progressBlock:(ASDKTaskContentProgressBlock)progressBlock
               completionBlock:(ASDKTaskContentUploadCompletionBlock)completionBlock;

/**
 *  Deletes content for the mentioned content object and reports back via a completion block whether the operation was
 *  successfull or not.
 *
 *  @param contentID       SDK content object containing information needed for deletion
 *  @param completionBlock Completion block providing information on whether the delete operation finished successfully
 *                         and an optional error reason.
 */
- (void)deleteContent:(ASDKModelContent *)content
      completionBlock:(ASDKTaskContentDeletionCompletionBlock)completionBlock;

/**
 *  Downloads content for the mentioned content object and reports back via a completion and progress blocks whether the
 *  status of the download, whether the operation was successfull and optional errors that ight occur.
 *
 *  @param content              SDK content object containing download information
 *  @param allowCachedResults   Boolean value specifying if results can be provided if already present on the disk
 *  @param progressBlock        Block providing information on the download progress and an optional error reason
 *  @param completionBlock      Completion block providing information on whether the download finished successfully and an
 *                              optional error reason.
 */
- (void)downloadContent:(ASDKModelContent *)content
     allowCachedResults:(BOOL)allowCachedResults
          progressBlock:(ASDKTaskContentDownloadProgressBlock)progressBlock
        completionBlock:(ASDKTaskContentDownloadCompletionBlock)completionBlock;

/**
 *  Involves a user with the task matching a specified task ID and reports back the result via a completion block.
 *
 *  @param user            User that will be involved with the task
 *  @param taskID          ID of the task for which the user will be involved with
 *  @param completionBlock Completion block providing information on whether the involvement operation finished successfully
 *                         and an optional error reason.
 */
- (void)involveUser:(ASDKModelUser *)user
          forTaskID:(NSString *)taskID
    completionBlock:(ASDKTaskUserInvolvementCompletionBlock)completionBlock;

/**
 *  Removes an involved user from a task matching a specified task ID and reports back the result via
 *  a completion block.
 *
 *  @param user            User that will be removed from the task contributors list
 *  @param taskID          ID of the task for which the user will be removed
 *  @param completionBlock Completion block providing information on whether the removal operation finished successfully
 */
- (void)removeInvolvedUser:(ASDKModelUser *)user
                 forTaskID:(NSString *)taskID
           completionBlock:(ASDKTaskUserInvolvementCompletionBlock)completionBlock;

/**
 *  Creates a standalone task that is not associated with a process instance.
 *
 *  @param taskRepresentation   Object encapsulating the information that needs to used for creating the task
 *  @param completionBlock      Completion block providing the newly created task object details and an optional
 *                              error reason.
 */
- (void)createTaskWithRepresentation:(ASDKTaskCreationRequestRepresentation *)taskRepresentation
                     completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock;


/**
 *  Claims a task for the current logged in user
 *
 *  @param taskID          ID of the task that will be claimed
 *  @param completionBlock Completion block providing information on whether the task is claimed and an
 *                         optional error reason
 */
- (void)claimTaskWithID:(NSString *)taskID
        completionBlock:(ASDKTaskClaimCompletionBlock)completionBlock;

/**
 *  Unclaims a task for the current logged in user
 *
 *  @param taskID          ID of the task that will be unclaimed
 *  @param completionBlock Completion block providing information on whether the task is unclaimed and
 *                         an optional error reason
 */
- (void)unclaimTaskWithID:(NSString *)taskID
          completionBlock:(ASDKTaskClaimCompletionBlock)completionBlock;

/**
 *  Assigns a task refferenced by it's ID to a user
 *
 *  @param taskID          ID of the task which will be assigned
 *  @param user            The user who will be assigned with the task
 *  @param completionBlock Completion block providing the task object model and an optional error reason
 */
- (void)assignTaskWithID:(NSString *)taskID
                  toUser:(ASDKModelUser *)user
         completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock;

/**
 *  Cancells all queued or running network operations
 */
- (void)cancelAllTaskNetworkOperations;

@end
