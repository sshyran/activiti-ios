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

#import "ASDKTaskDataAccessor.h"

// Constants
#import "ASDKLogConfiguration.h"

// Managers
#import "ASDKBootstrap.h"
#import "ASDKTaskNetworkServices.h"
#import "ASDKTaskCacheService.h"
#import "ASDKServiceLocator.h"

// Operations
#import "ASDKAsyncBlockOperation.h"

// Model
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKDataAccessorResponseCollection.h"
#import "ASDKDataAccessorResponseProgress.h"
#import "ASDKDataAccessorResponseModel.h"


static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKTaskDataAccessor ()

@property (strong, nonatomic) NSOperationQueue *processingQueue;

@end

@implementation ASDKTaskDataAccessor

- (instancetype)initWithDelegate:(id<ASDKDataAccessorDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    
    if (self) {
        _processingQueue = [self serialOperationQueue];
        _cachePolicy = ASDKServiceDataAccessorCachingPolicyHybrid;
        dispatch_queue_t profileUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue",
                                                                                 [NSBundle bundleForClass:[self class]].bundleIdentifier,
                                                                                 NSStringFromClass([self class])] UTF8String],
                                                                               DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        _networkService = (ASDKTaskNetworkServices *)[sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKTaskNetworkServiceProtocol)];
        _networkService.resultsQueue = profileUpdatesProcessingQueue;
        _cacheService = [ASDKTaskCacheService new];
    }
    
    return self;
}


#pragma mark -
#pragma mark Service - Task list

- (void)fetchTasksWithFilter:(ASDKFilterRequestRepresentation *)filter {
    // Define operations
    ASDKAsyncBlockOperation *remoteTaskListOperation = [self remoteTaskListOperationForFilter:filter];
    ASDKAsyncBlockOperation *cachedTaskListOperation = [self cachedTaskListOperationForFilter:filter];
    ASDKAsyncBlockOperation *storeInCacheTaskListOperation = [self taskListStoreInCacheOperationWithFilter:filter];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedTaskListOperation];
            [self.processingQueue addOperations:@[cachedTaskListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteTaskListOperation];
            [self.processingQueue addOperations:@[remoteTaskListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteTaskListOperation addDependency:cachedTaskListOperation];
            [storeInCacheTaskListOperation addDependency:remoteTaskListOperation];
            [completionOperation addDependency:storeInCacheTaskListOperation];
            [self.processingQueue addOperations:@[cachedTaskListOperation,
                                                  remoteTaskListOperation,
                                                  storeInCacheTaskListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default: break;
    }
}

- (ASDKAsyncBlockOperation *)remoteTaskListOperationForFilter:(ASDKFilterRequestRepresentation *)filter {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteTaskListOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskNetworkService fetchTaskListWithFilterRepresentation:filter
                                                             completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                                                 if (operation.isCancelled) {
                                                                     [operation complete];
                                                                     return;
                                                                 }
                                                                 
                                                                 ASDKDataAccessorResponseCollection *responseCollection =
                                                                 [[ASDKDataAccessorResponseCollection alloc] initWithCollection:taskList
                                                                                                                         paging:paging
                                                                                                                   isCachedData:NO
                                                                                                                          error:error];
                                                                 
                                                                 if (weakSelf.delegate) {
                                                                     [weakSelf.delegate dataAccessor:weakSelf
                                                                                 didLoadDataResponse:responseCollection];
                                                                 }
                                                                 
                                                                 operation.result = responseCollection;
                                                                 [operation complete];
                                                             }];
    }];
    
    return remoteTaskListOperation;
}

- (ASDKAsyncBlockOperation *)cachedTaskListOperationForFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedTaskListOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskCacheService fetchTaskList:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
            if (operation.isCancelled) {
                [operation complete];
                return;
            }
            
            if (!error) {
                ASDKLogVerbose(@"Task list information fetched successfully from cache for filter.\nFilter:%@", filter);
                
                ASDKDataAccessorResponseCollection *response = [[ASDKDataAccessorResponseCollection alloc] initWithCollection:taskList
                                                                                                                       paging:paging
                                                                                                                 isCachedData:YES
                                                                                                                        error:error];
                
                if (weakSelf.delegate) {
                    [weakSelf.delegate dataAccessor:weakSelf
                                didLoadDataResponse:response];
                }
            } else {
                ASDKLogError(@"An error occured while fetching cache task list information. Reason: %@", error.localizedDescription);
            }
            
            [operation complete];
        } usingFilter:filter];
    }];
    
    return cachedTaskListOperation;
}

- (ASDKAsyncBlockOperation *)taskListStoreInCacheOperationWithFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.taskCacheService cacheTaskList:remoteResponse.collection
                                           usingFilter:filter
                                   withCompletionBlock:^(NSError *error) {
                                       if (operation.isCancelled) {
                                           [operation complete];
                                           return;
                                       }
                                       
                                       if (!error) {
                                           [weakSelf.taskCacheService saveChanges];
                                       } else {
                                           ASDKLogError(@"Encountered an error while caching the task list for filter: %@. Reason:%@", filter, error.localizedDescription);
                                       }
                                       
                                       [operation complete];
                                   }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service - Task details

- (void)fetchTaskDetailsForTaskID:(NSString *)taskID {
    // Define operations
    ASDKAsyncBlockOperation *remoteTaskDetailsOperation = [self remoteTaskDetailsOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *cachedTaskDetailsOperation = [self cachedTaskDetailsOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *storeInCacheTaskDetailsOperation = [self taskDetailsStoreInCacheOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedTaskDetailsOperation];
            [self.processingQueue addOperations:@[cachedTaskDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteTaskDetailsOperation];
            [self.processingQueue addOperations:@[remoteTaskDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteTaskDetailsOperation addDependency:cachedTaskDetailsOperation];
            [storeInCacheTaskDetailsOperation addDependency:remoteTaskDetailsOperation];
            [completionOperation addDependency:storeInCacheTaskDetailsOperation];
            [self.processingQueue addOperations:@[cachedTaskDetailsOperation,
                                                  remoteTaskDetailsOperation,
                                                  storeInCacheTaskDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default: break;
    }
}

- (ASDKAsyncBlockOperation *)remoteTaskDetailsOperationForTaskID:(NSString *)taskID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteTaskDetailsOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskNetworkService fetchTaskDetailsForTaskID:taskID
                                                 completionBlock:^(ASDKModelTask *task, NSError *error) {
                                                     if (operation.isCancelled) {
                                                         [operation complete];
                                                         return;
                                                     }
                                                     
                                                     ASDKDataAccessorResponseModel *response =
                                                     [[ASDKDataAccessorResponseModel alloc] initWithModel:task
                                                                                             isCachedData:NO
                                                                                                    error:error];
                                                     if (weakSelf.delegate) {
                                                         [weakSelf.delegate dataAccessor:weakSelf
                                                                     didLoadDataResponse:response];
                                                     }
                                                     
                                                     operation.result = response;
                                                     [operation complete];
                                                 }];
    }];
    
    return remoteTaskDetailsOperation;
}

- (ASDKAsyncBlockOperation *)cachedTaskDetailsOperationForTaskID:(NSString *)taskID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedTaskDetailsOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskCacheService fetchTaskDetailsForID:taskID
                                       withCompletionBlock:^(ASDKModelTask *task, NSError *error) {
                                           if (operation.isCancelled) {
                                               [operation complete];
                                               return;
                                           }
                                           
                                           if (!error) {
                                               ASDKLogVerbose(@"Task details information fetched successfully from cache for taskID:%@", taskID);
                                               
                                               ASDKDataAccessorResponseModel *response =
                                               [[ASDKDataAccessorResponseModel alloc] initWithModel:task
                                                                                       isCachedData:YES
                                                                                              error:error];
                                               
                                               if (weakSelf.delegate) {
                                                   [weakSelf.delegate dataAccessor:weakSelf
                                                               didLoadDataResponse:response];
                                               }
                                           } else {
                                               ASDKLogError(@"An error occured while fetching cached task details for taskID:%@. Reason:%@", taskID, error.localizedDescription);
                                           }
                                           
                                           [operation complete];
                                       }];
    }];
    
    return cachedTaskDetailsOperation;
}

- (ASDKAsyncBlockOperation *)taskDetailsStoreInCacheOperationForTaskID:(NSString *)taskID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseModel *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.model) {
            [strongSelf.taskCacheService cacheTaskDetails:remoteResponse.model
                                      withCompletionBlock:^(NSError *error) {
                                          if (operation.isCancelled) {
                                              [operation complete];
                                              return;
                                          }
                                          
                                          if (!error) {
                                              [[weakSelf taskCacheService] saveChanges];
                                          } else {
                                              ASDKLogError(@"Encountered an error while caching the task details for taskID:%@. Reason:%@", taskID, error.localizedDescription);
                                          }
                                          
                                          [operation complete];
                                      }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service - Task content

- (void)fetchTaskContentForTaskID:(NSString *)taskID {
    // Define operations
    ASDKAsyncBlockOperation *remoteTaskContentOperation = [self remoteTaskContentOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *cachedTaskContentOperation = [self cachedTaskContentOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *storeInCacheOperation = [self taskContentStoreInCacheOperationForTaskID:taskID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedTaskContentOperation];
            [self.processingQueue addOperations:@[cachedTaskContentOperation, completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteTaskContentOperation];
            [self.processingQueue addOperations:@[remoteTaskContentOperation, completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteTaskContentOperation addDependency:cachedTaskContentOperation];
            [storeInCacheOperation addDependency:remoteTaskContentOperation];
            [completionOperation addDependency:storeInCacheOperation];
            [self.processingQueue addOperations:@[cachedTaskContentOperation,
                                                  remoteTaskContentOperation,
                                                  storeInCacheOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default:
            break;
    }
}

- (ASDKAsyncBlockOperation *)remoteTaskContentOperationForTaskID:(NSString *)taskID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteTaskContentOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskNetworkService fetchTaskContentForTaskID:taskID
                                                 completionBlock:^(NSArray *contentList, NSError *error) {
                                                     if (operation.isCancelled) {
                                                         [operation complete];
                                                     }
                                                     
                                                     ASDKDataAccessorResponseCollection *responseCollection =
                                                     [[ASDKDataAccessorResponseCollection alloc] initWithCollection:contentList
                                                                                                       isCachedData:NO
                                                                                                              error:error];
                                                     
                                                     if (weakSelf.delegate) {
                                                         [weakSelf.delegate dataAccessor:weakSelf
                                                                     didLoadDataResponse:responseCollection];
                                                     }
                                                     
                                                     operation.result = responseCollection;
                                                     [operation complete];
                                                 }];
    }];
    
    return remoteTaskContentOperation;
}

- (ASDKAsyncBlockOperation *)cachedTaskContentOperationForTaskID:(NSString *)taskID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedTaskContentListOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.taskCacheService fetchTaskContentListForTaskWithID:taskID
                                                   withCompletionBlock:^(NSArray *taskContentList, NSError *error) {
                                                       if (operation.isCancelled) {
                                                           [operation complete];
                                                           return;
                                                       }
                                                       
                                                       if (!error) {
                                                           ASDKLogVerbose(@"Task content list fetched successfully from cache for taskID:%@", taskID);
                                                           ASDKDataAccessorResponseCollection *response =
                                                           [[ASDKDataAccessorResponseCollection alloc] initWithCollection:taskContentList
                                                                                                             isCachedData:YES
                                                                                                                    error:error];
                                                           if (weakSelf.delegate) {
                                                               [weakSelf.delegate dataAccessor:weakSelf
                                                                           didLoadDataResponse:response];
                                                           }
                                                       } else {
                                                           ASDKLogError(@"An Error occured while fetching the cached task content list. Reason: %@", error.localizedDescription);
                                                       }
                                                       
                                                       [operation complete];
        }];
    }];
    
    return cachedTaskContentListOperation;
}

- (ASDKAsyncBlockOperation *)taskContentStoreInCacheOperationForTaskID:(NSString *)taskID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.taskCacheService cacheTaskContentList:remoteResponse.collection
                                                forTaskWithID:taskID
                                          withCompletionBlock:^(NSError *error) {
                                              if (operation.isCancelled) {
                                                  [operation complete];
                                                  return;
                                              }
                                              
                                              if (!error) {
                                                  [weakSelf.taskCacheService saveChanges];
                                              } else {
                                                  ASDKLogError(@"Encountered an error while caching the task content list for taskID: %@. Reason:%@", taskID, error.localizedDescription);
                                              }
                                              
                                              [operation complete];
            }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Cancel operations

- (void)cancelOperations {
    [super cancelOperations];
    [self.processingQueue cancelAllOperations];
    [self.taskNetworkService cancelAllNetworkOperations];
}


#pragma mark -
#pragma mark Private interface

- (ASDKTaskNetworkServices *)taskNetworkService {
    return (ASDKTaskNetworkServices *)self.networkService;
}

- (ASDKTaskCacheService *)taskCacheService {
    return (ASDKTaskCacheService *)self.cacheService;
}

- (ASDKAsyncBlockOperation *)defaultCompletionOperation {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *completionOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (operation.isCancelled) {
            [operation complete];
            return;
        }
        
        if (strongSelf.delegate) {
            [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
        }
        
        [operation complete];
    }];
    
    return completionOperation;
}

@end
