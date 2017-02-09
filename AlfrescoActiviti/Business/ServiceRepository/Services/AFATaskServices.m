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

#import "AFATaskServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"
#import "AFATaskUpdateModel.h"
#import "AFATaskCreateModel.h"

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFATaskServices ()

@property (strong, nonatomic) dispatch_queue_t          taskUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKTaskNetworkServices   *taskNetworkService;

@end

@implementation AFATaskServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.taskUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.taskNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKTaskNetworkServiceProtocol)];
        self.taskNetworkService.resultsQueue = self.taskUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestTaskListWithFilter:(AFAGenericFilterModel *)taskFilter
              withCompletionBlock:(AFATaskServicesTaskListCompletionBlock)completionBlock {
    NSParameterAssert(taskFilter);
    NSParameterAssert(completionBlock);
    
    // Create request representation for the filter model
    ASDKFilterRequestRepresentation *filterRequestRepresentation = [ASDKFilterRequestRepresentation new];
    filterRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    filterRequestRepresentation.filterID = taskFilter.filterID;
    filterRequestRepresentation.appDefinitionID = taskFilter.appDefinitionID;
    
    ASDKModelFilter *modelFilter = [ASDKModelFilter new];
    modelFilter.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    modelFilter.sortType = (NSInteger)taskFilter.sortType;
    modelFilter.state = (NSInteger)taskFilter.state;
    modelFilter.assignmentType = (NSInteger)taskFilter.assignmentType;
    modelFilter.name = taskFilter.text;
    
    filterRequestRepresentation.filterModel = modelFilter;
    filterRequestRepresentation.page = taskFilter.page;
    filterRequestRepresentation.size = taskFilter.size;
    
    [self.taskNetworkService fetchTaskListWithFilterRepresentation:filterRequestRepresentation
                                                   completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                                       if (!error) {
                                                           AFALogVerbose(@"Fetched %lu task entries", (unsigned long)taskList.count);
                                                           
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               completionBlock (taskList, nil, paging);
                                                           });
                                                       } else {
                                                           AFALogError(@"An error occured while fetching the task list with filter:%@. Reason:%@", taskFilter.description, error.localizedDescription);
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               completionBlock(nil, error, nil);
                                                           });
                                                       }
                                                   }];
}

- (void)requestTaskDetailsForID:(NSString *)taskID
            withCompletionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService fetchTaskDetailsForTaskID:taskID
                                       completionBlock:^(ASDKModelTask *task, NSError *error) {
                                           if (!error) {
                                               AFALogVerbose(@"Fetched details for task name %@", task.name);
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock (task, nil);
                                               });
                                           } else {
                                               AFALogError(@"An error occured while fetching details for task: %@. Reason:%@", task.name, error.localizedDescription);
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock(nil, error);
                                               });
                                           }
                                       }];
}

- (void)requestTaskContentForID:(NSString *)taskID
            withCompletionBlock:(AFATaskServicesTaskContentCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService fetchTaskContentForTaskID:taskID
                                       completionBlock:^(NSArray *contentList, NSError *error) {
                                           if (!error) {
                                               AFALogVerbose(@"Fetched content collection for task with ID:%@", taskID);
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock (contentList, nil);
                                               });
                                           } else {
                                               AFALogError(@"An error occured while fetching the content collection for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   completionBlock(nil, error);
                                               });
                                           }
                                       }];
}

- (void)requestTaskCommentsForID:(NSString *)taskID
             withCompletionBlock:(AFATaskServicesTaskCommentsCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService fetchTaskCommentsForTaskID:taskID
                                        completionBlock:^(NSArray *commentList, NSError *error, ASDKModelPaging *paging) {
                                            if (!error) {
                                                AFALogVerbose(@"Fetched comment list for task with ID:%@", taskID);
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    completionBlock (commentList, nil, paging);
                                                });
                                            } else {
                                                AFALogError(@"An error occured while fetching the comment list for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    completionBlock(nil, error, nil);
                                                });
                                            }
                                        }];
}

- (void)requestTaskUpdateWithRepresentation:(AFATaskUpdateModel *)update
                                  forTaskID:(NSString *)taskID
                        withCompletionBlock:(AFATaskServicesTaskUpdateCompletionBlock)completionBlock {
    NSParameterAssert(update);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    // Create request representation for the task update model
    ASDKTaskUpdateRequestRepresentation *taskUpdateRequestRepresentation = [ASDKTaskUpdateRequestRepresentation new];
    taskUpdateRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeCustomPolicy;
    
    // Remove all nil properties but the due date
    taskUpdateRequestRepresentation.policyBlock = ^(id value, NSString *key) {
        BOOL keyShouldBeRemoved = YES;
        BOOL isNilValue = [[NSNull null] isEqual:value];
        
        if ([NSStringFromSelector(@selector(dueDate)) isEqualToString:key]) {
            keyShouldBeRemoved = NO;
        } else if (!isNilValue) {
            keyShouldBeRemoved = NO;
        }
        
        return keyShouldBeRemoved;
    };
    taskUpdateRequestRepresentation.name = update.taskName;
    taskUpdateRequestRepresentation.taskDescription = update.taskDescription;
    taskUpdateRequestRepresentation.dueDate = update.taskDueDate;
    
    [self.taskNetworkService updateTaskForTaskID:taskID
                          withTaskRepresentation:taskUpdateRequestRepresentation
                                 completionBlock:^(BOOL isTaskUpdated, NSError *error) {
                                     if (!error && isTaskUpdated) {
                                         AFALogVerbose(@"Task with ID:%@ was updated successfully", taskID);
                                         
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             completionBlock(isTaskUpdated, nil);
                                         });
                                     } else {
                                         AFALogError(@"An error occured updating task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                         
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             completionBlock(NO, error);
                                         });
                                     }
                                 }];
}

- (void)requestTaskCompletionForID:(NSString *)taskID
               withCompletionBlock:(AFATaskServicesTaskCompleteCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService completeTaskForTaskID:taskID
                                   completionBlock:^(BOOL isTaskCompleted, NSError *error) {
                                       if (!error && isTaskCompleted) {
                                           AFALogVerbose(@"Task with ID:%@ was marked as completed", taskID);
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completionBlock(isTaskCompleted, nil);
                                           });
                                       } else {
                                           AFALogError(@"An error occured while marking as completed task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completionBlock(NO, error);
                                           });
                                       }
                                   }];
}

- (void)requestContentUploadAtFileURL:(NSURL *)fileURL
                            forTaskID:(NSString *)taskID
                    withProgressBlock:(AFATaskServiceTaskContentProgressBlock)progressBlock
                      completionBlock:(AFATaskServicesTaskContentUploadCompletionBlock)completionBlock {
    NSParameterAssert(fileURL);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKModelFileContent *fileContentModel = [ASDKModelFileContent new];
    fileContentModel.modelFileURL = fileURL;
    
    [self.taskNetworkService uploadContentWithModel:fileContentModel
                                          forTaskID:taskID
                                      progressBlock:^(NSUInteger progress, NSError *error) {
                                          AFALogVerbose(@"Content for task with ID:%@ is %lu%% uploaded", taskID, (unsigned long)progress);
                                          
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              progressBlock (progress, error);
                                          });
                                      } completionBlock:^(BOOL isContentUploaded, NSError *error) {
                                          if (!error && isContentUploaded) {
                                              AFALogVerbose(@"Content for task with ID:%@ was succesfully uploaded", taskID);
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (isContentUploaded, nil);
                                              });
                                          } else {
                                              AFALogError(@"An error occured while uploading content for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (NO, error);
                                              });
                                          }
                                      }];
}

- (void)requestContentUploadAtFileURL:(NSURL *)fileURL
                      withContentData:(NSData *)contentData
                            forTaskID:(NSString *)taskID
                    withProgressBlock:(AFATaskServiceTaskContentProgressBlock)progressBlock
                      completionBlock:(AFATaskServicesTaskContentUploadCompletionBlock)completionBlock {
    NSParameterAssert(fileURL);
    NSParameterAssert(contentData);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKModelFileContent *fileContentModel = [ASDKModelFileContent new];
    fileContentModel.modelFileURL = fileURL;
    
    [self.taskNetworkService uploadContentWithModel:fileContentModel
                                        contentData:contentData
                                          forTaskID:taskID
                                      progressBlock:^(NSUInteger progress, NSError *error) {
                                          AFALogVerbose(@"Content for task with ID:%@ is %lu%% uploaded", taskID, (unsigned long)progress);
                                          
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              progressBlock (progress, error);
                                          });
                                      } completionBlock:^(BOOL isContentUploaded, NSError *error) {
                                          if (!error && isContentUploaded) {
                                              AFALogVerbose(@"Content for task with ID:%@ was succesfully uploaded", taskID);
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (isContentUploaded, nil);
                                              });
                                          } else {
                                              AFALogError(@"An error occured while uploading content for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completionBlock (NO, error);
                                              });
                                          }
                                      }];
}

- (void)requestTaskContentDeleteForContent:(ASDKModelContent *)content
                       withCompletionBlock:(AFATaslServiceTaskContentDeleteCompletionBlock)completionBlock {
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService deleteContent:content
                           completionBlock:^(BOOL isContentDeleted, NSError *error) {
                               if (!error && isContentDeleted) {
                                   AFALogVerbose(@"Content with ID:%@ was deleted successfully.", content.modelID);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(isContentDeleted, nil);
                                   });
                               } else {
                                   AFALogError(@"An error occured while deleting content with ID:%@. Reason:%@", content.modelID, error.localizedDescription);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(NO, error);
                                   });
                               }
                           }];
}

- (void)requestTaskContentDownloadForContent:(ASDKModelContent *)content
                          allowCachedResults:(BOOL)allowCachedResults
                           withProgressBlock:(AFATaskServiceTaskContentDownloadProgressBlock)progressBlock
                         withCompletionBlock:(AFATaskServiceTaskContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService downloadContent:content
                          allowCachedResults:allowCachedResults
                               progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                   AFALogVerbose(@"Downloaded %@ of content for task with ID:%@ ", formattedReceivedBytesString, content.modelID);
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       progressBlock (formattedReceivedBytesString, error);
                                   });
                               } completionBlock:^(NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                   if (!error && downloadedContentURL) {
                                       AFALogVerbose(@"Content with ID:%@ was downloaded successfully.", content.modelID);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock(downloadedContentURL, isLocalContent,nil);
                                       });
                                   } else {
                                       AFALogError(@"An error occured while downloading content with ID:%@. Reason:%@", content.modelID, error.localizedDescription);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock(nil, NO, error);
                                       });
                                   }
                               }];
}

- (void)requestTaskUserInvolvement:(ASDKModelUser *)user
                         forTaskID:(NSString *)taskID
                   completionBlock:(AFATaskServicesUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(user);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService involveUser:user
                               forTaskID:taskID
                         completionBlock:^(BOOL isUserInvolved, NSError *error) {
                             if (!error && isUserInvolved) {
                                 AFALogVerbose(@"User %@ had been involved with task:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID);
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     completionBlock(isUserInvolved, nil);
                                 });
                             } else {
                                 AFALogError(@"An error occured while involving user %@ for task %@. Reason:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID, error.localizedDescription);
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     completionBlock(NO, error);
                                 });
                             }
                         }];
}

- (void)requestToRemoveTaskUserInvolvement:(ASDKModelUser *)user
                                 forTaskID:(NSString *)taskID
                           completionBlock:(AFATaskServicesUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(user);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService removeInvolvedUser:user
                                      forTaskID:taskID
                                completionBlock:^(BOOL isUserInvolved, NSError *error) {
                                    if (!error && !isUserInvolved) {
                                        AFALogVerbose(@"User %@ had been removed from task:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID);
                                    } else {
                                        AFALogError(@"An error occured while removing user %@ for task %@. Reason:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID, error.localizedDescription);
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        completionBlock(isUserInvolved, nil);
                                    });
                                }];
}

- (void)requestCreateComment:(NSString *)comment
                   forTaskID:(NSString *)taskID
             completionBlock:(AFATaskServicesCreateCommentCompletionBlock)completionBlock {
    NSParameterAssert(comment);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService createComment:comment
                                 forTaskID:taskID
                           completionBlock:^(ASDKModelComment *comment, NSError *error) {
                               if (!error && comment) {
                                   AFALogVerbose(@"Comment for task ID :%@ created successfully.", taskID);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(comment, nil);
                                   });
                               } else {
                                   AFALogError(@"An error occured creating comment for task id %@. Reason:%@", taskID, error.localizedDescription);
                                   
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       completionBlock(nil, error);
                                   });
                               }
                           }];
}

- (void)requestCreateTaskWithRepresentation:(AFATaskCreateModel *)taskRepresentation
                            completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskRepresentation);
    NSParameterAssert(completionBlock);
    
    ASDKTaskCreationRequestRepresentation *taskCreationRequestRepresentation = [ASDKTaskCreationRequestRepresentation new];
    taskCreationRequestRepresentation.taskName = taskRepresentation.taskName;
    taskCreationRequestRepresentation.taskDescription = taskRepresentation.taskDescription;
    taskCreationRequestRepresentation.appDefinitionID = taskRepresentation.applicationID;
    taskCreationRequestRepresentation.assigneeID = taskRepresentation.assigneeID;
    taskCreationRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    [self.taskNetworkService createTaskWithRepresentation:taskCreationRequestRepresentation
                                          completionBlock:^(ASDKModelTask *task, NSError *error) {
                                              if (!error) {
                                                  AFALogVerbose(@"Created task %@", task.name);
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      completionBlock (task, nil);
                                                  });
                                              } else {
                                                  AFALogError(@"An error occured while creating task: %@. Reason:%@", task.name, error.localizedDescription);
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      completionBlock(nil, error);
                                                  });
                                              }
                                          }];
}

- (void)requestTaskClaimForTaskID:(NSString *)taskID
                  completionBlock:(AFATaskServicesClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService claimTaskWithID:taskID
                             completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                                 if (!error && isTaskClaimed) {
                                     AFALogVerbose(@"Claimed task with ID:%@", taskID);
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock (YES, nil);
                                     });
                                 } else {
                                     AFALogError(@"An error occured while claiming task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                     
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         completionBlock(NO, error);
                                     });
                                 }
                             }];
}

- (void)requestTaskUnclaimForTaskID:(NSString *)taskID
                    completionBlock:(AFATaskServicesClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService unclaimTaskWithID:taskID
                               completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                                   if (!error && !isTaskClaimed) {
                                       AFALogVerbose(@"Unclaimed task with ID:%@", taskID);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock (NO, nil);
                                       });
                                   } else {
                                       AFALogError(@"An error occured while unclaiming task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completionBlock(YES, error);
                                       });
                                   }
                               }];
}

- (void)requestTaskAssignForTaskWithID:(NSString *)taskID
                                toUser:(ASDKModelUser *)user
                       completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(user);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService assignTaskWithID:taskID
                                       toUser:user
                              completionBlock:^(ASDKModelTask *task, NSError *error) {
                                  if (!error && task) {
                                      AFALogVerbose(@"Assigned user:%@ to task:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], task.name);
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          completionBlock(task, nil);
                                      });
                                  } else {
                                      AFALogError(@"An error occured while assigning user:%@ to task with ID:%@. Reason:%@", [NSString stringWithFormat:@"%@ %@", user.userFirstName, user.userLastName], taskID, error.localizedDescription);
                                      
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          completionBlock(nil, error);
                                      });
                                  }
                              }];
}

- (void)requestDownloadAuditLogForTaskWithID:(NSString *)taskID
                          allowCachedResults:(BOOL)allowCachedResults
                               progressBlock:(AFATaskServiceTaskContentDownloadProgressBlock)progressBlock
                             completionBlock:(AFATaskServiceTaskContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService downloadAuditLogForTaskWithID:taskID
                                        allowCachedResults:allowCachedResults
                                             progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                                 AFALogVerbose(@"Downloaded %@ of content for the audit log of task with ID:%@ ", formattedReceivedBytesString, taskID);
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     progressBlock (formattedReceivedBytesString, error);
                                                 });
                                             } completionBlock:^(NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                                 if (!error && downloadedContentURL) {
                                                     AFALogVerbose(@"Audit log content for task with ID:%@ was downloaded successfully.", taskID);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(downloadedContentURL, isLocalContent,nil);
                                                     });
                                                 } else {
                                                     AFALogError(@"An error occured while downloading audit log content for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(nil, NO, error);
                                                     });
                                                 }
                                             }];
}

- (void)requestChecklistForTaskWithID:(NSString *)taskID
                      completionBlock:(AFATaskServicesTaskListCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    [self.taskNetworkService fetchChecklistForTaskWithID:taskID
                                         completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                             if (!error) {
                                                 AFALogVerbose(@"Fetched checklist for task with ID:%@", taskID);
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     completionBlock(taskList, nil, paging);
                                                 });
                                             } else {
                                                 AFALogError(@"An error occured while fetching the checklist for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     completionBlock(nil, error, nil);
                                                 });
                                             }
    }];
    
}

- (void)requestChecklistCreateWithRepresentation:(AFATaskCreateModel *)taskRepresentation
                                          taskID:(NSString *)taskID
                                 completionBlock:(AFATaskServicesTaskDetailsCompletionBlock)completionBlock {
    NSParameterAssert(taskRepresentation);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKTaskCreationRequestRepresentation *checklistCreationRequestRepresentation = [ASDKTaskCreationRequestRepresentation new];
    checklistCreationRequestRepresentation.taskName = taskRepresentation.taskName;
    checklistCreationRequestRepresentation.taskDescription = taskRepresentation.taskDescription;
    checklistCreationRequestRepresentation.assigneeID = taskRepresentation.assigneeID;
    checklistCreationRequestRepresentation.parentTaskID = taskID;
    checklistCreationRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    [self.taskNetworkService createChecklistWithRepresentation:checklistCreationRequestRepresentation
                                                        taskID:taskID
                                               completionBlock:^(ASDKModelTask *task, NSError *error) {
                                                   if (!error) {
                                                       AFALogVerbose(@"Created checklist item %@", task.name);
                                                       
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           completionBlock (task, nil);
                                                       });
                                                   } else {
                                                       AFALogError(@"An error occured while creating checklist item: %@. Reason:%@", task.name, error.localizedDescription);
                                                       
                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                           completionBlock(nil, error);
                                                       });
                                                   }
    }];
}

- (void)requestChecklistOrderUpdateWithOrderArrat:(NSArray *)orderArray
                                           taskID:(NSString *)taskID
                                  completionBlock:(AFATaskServicesTaskUpdateCompletionBlock)completionBlock {
    NSParameterAssert(orderArray);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    
    ASDKTaskChecklistOrderRequestRepresentation *checklistOrderRequestRepresentation = [ASDKTaskChecklistOrderRequestRepresentation new];
    checklistOrderRequestRepresentation.checklistOrder = orderArray;
    
    [self.taskNetworkService updateChecklistOrderWithRepresentation:checklistOrderRequestRepresentation
                                                             taskID:taskID
                                                    completionBlock:^(BOOL isTaskUpdated, NSError *error) {
                                                        if (!error && isTaskUpdated) {
                                                            AFALogVerbose(@"Updated checklist order for task with ID:%@", taskID);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(YES, nil);
                                                            });
                                                        } else {
                                                            AFALogError(@"An error occured while updating the checklist order for task with ID:%@. Reason:%@", taskID, error.localizedDescription);
                                                        }
    }];
}

@end
