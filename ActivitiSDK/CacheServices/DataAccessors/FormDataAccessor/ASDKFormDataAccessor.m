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

#import "ASDKFormDataAccessor.h"

// Constants
#import "ASDKLogConfiguration.h"

// Managers
#import "ASDKBootstrap.h"
#import "ASDKServiceLocator.h"
#import "ASDKFormNetworkServices.h"
#import "ASDKFormCacheService.h"

// Operations
#import "ASDKAsyncBlockOperation.h"

// Models
#import "ASDKDataAccessorResponseModel.h"
#import "ASDKDataAccessorResponseConfirmation.h"
#import "ASDKDataAccessorResponseProgress.h"
#import "ASDKDataAccessorResponseFileContent.h"
#import "ASDKDataAccessorResponseCollection.h"


static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKFormDataAccessor ()

@property (strong, nonatomic) NSOperationQueue *processingQueue;

@end

@implementation ASDKFormDataAccessor

- (instancetype)initWithDelegate:(id<ASDKDataAccessorDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    
    if (self) {
        _processingQueue = [self serialOperationQueue];
        _cachePolicy = ASDKServiceDataAccessorCachingPolicyHybrid;
        dispatch_queue_t formUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue",
                                                                              [NSBundle bundleForClass:[self class]].bundleIdentifier,
                                                                              NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        // Acquire and set up the form network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        _networkService = (ASDKFormNetworkServices *)[sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormNetworkServiceProtocol)];
        _networkService.resultsQueue = formUpdatesProcessingQueue;
        _cacheService = [ASDKFormCacheService new];
    }
    
    return self;
}


#pragma mark -
#pragma mark Service - Complete task form

- (void)completeFormForTaskID:(NSString *)taskID
withFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation {
    NSParameterAssert(taskID);
    NSParameterAssert(formFieldValuesRepresentation);
    
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.formNetworkService completeFormForTaskID:taskID
           withFormFieldValueRequestRepresentation:formFieldValuesRepresentation
                                   completionBlock:^(BOOL isFormCompleted, NSError *error) {
                                       __strong typeof(self) strongSelf = weakSelf;
                                       
                                       ASDKDataAccessorResponseConfirmation *responseConfirmation =
                                       [[ASDKDataAccessorResponseConfirmation alloc] initWithConfirmation:isFormCompleted
                                                                                             isCachedData:NO
                                                                                                    error:error];
                                       
                                       if (strongSelf.delegate) {
                                           [strongSelf.delegate dataAccessor:strongSelf
                                                         didLoadDataResponse:responseConfirmation];
                                           
                                           [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
                                       }
                                   }];
    
}


#pragma mark -
#pragma mark Service - Complete process definition form

- (void)completeFormForProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
withFormFieldValuesRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation {
    NSParameterAssert(processDefinition);
    NSParameterAssert(formFieldValuesRepresentation);
    
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.formNetworkService completeFormForProcessDefinition:processDefinition withFormFieldValuesRequestRepresentation:formFieldValuesRepresentation completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKDataAccessorResponseModel *responseModel =
        [[ASDKDataAccessorResponseModel alloc] initWithModel:processInstance
                                                isCachedData:NO
                                                       error:error];
        
        if (strongSelf.delegate) {
            [strongSelf.delegate dataAccessor:strongSelf
                          didLoadDataResponse:responseModel];
            
            [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
        }
    }];
}


#pragma mark -
#pragma mark Service - Save task form

- (void)saveFormForTaskID:(NSString *)taskID
withFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation {
    NSParameterAssert(taskID);
    NSParameterAssert(formFieldValuesRepresentation);
    
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.formNetworkService saveFormForTaskID:taskID
      withFormFieldValuesRequestRepresentation:formFieldValuesRepresentation
                               completionBlock:^(BOOL isFormSaved, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   ASDKDataAccessorResponseConfirmation *responseConfirmation =
                                   [[ASDKDataAccessorResponseConfirmation alloc] initWithConfirmation:isFormSaved
                                                                                         isCachedData:NO
                                                                                                error:error];
                                   
                                   if (strongSelf.delegate) {
                                       [strongSelf.delegate dataAccessor:strongSelf
                                                     didLoadDataResponse:responseConfirmation];
                                       
                                       [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
                                   }
                               }];
}


#pragma mark -
#pragma mark Service - Upload form field content

- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                   contentData:(NSData *)contentData {
    NSParameterAssert(file);
    NSParameterAssert(contentData);
    
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.formNetworkService uploadContentWithModel:file
                                        contentData:contentData
                                      progressBlock:^(NSUInteger progress, NSError *error) {
                                          __strong typeof(self) strongSelf = weakSelf;
                                          
                                          ASDKDataAccessorResponseProgress *responseProgress =
                                          [[ASDKDataAccessorResponseProgress alloc] initWithProgress:progress
                                                                                               error:error];
                                          
                                          if (strongSelf.delegate) {
                                              [strongSelf.delegate dataAccessor:strongSelf
                                                            didLoadDataResponse:responseProgress];
                                          }
                                      } completionBlock:^(ASDKModelContent *contentModel, NSError *error) {
                                          __strong typeof(self) strongSelf = weakSelf;
                                          
                                          ASDKDataAccessorResponseModel *responseModel =
                                          [[ASDKDataAccessorResponseModel alloc] initWithModel:contentModel
                                                                                  isCachedData:NO
                                                                                         error:error];
                                          
                                          if (strongSelf.delegate) {
                                              [strongSelf.delegate dataAccessor:strongSelf
                                                            didLoadDataResponse:responseModel];
                                              
                                              [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
                                          }
                                      }];
}


#pragma mark -
#pragma mark Service - Download form field content

- (void)downloadContentWithModel:(ASDKModelContent *)content {
    NSParameterAssert(content);
    
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    
    BOOL areCachedResultsAllowed = (ASDKServiceDataAccessorCachingPolicyCacheOnly == self.cachePolicy) || (ASDKServiceDataAccessorCachingPolicyHybrid   == self.cachePolicy) ? YES : NO;
    [self.formNetworkService downloadContentWithModel:content
                                   allowCachedResults:areCachedResultsAllowed
                                        progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            ASDKDataAccessorResponseProgress *responseProgress =
                                            [[ASDKDataAccessorResponseProgress alloc] initWithFormattedProgressString:formattedReceivedBytesString
                                                                                                                error:error];
                                            
                                            if (strongSelf.delegate) {
                                                [strongSelf.delegate dataAccessor:strongSelf
                                                              didLoadDataResponse:responseProgress];
                                            }
                                        } completionBlock:^(NSString *contentID, NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            ASDKDataAccessorResponseFileContent *responseFileContent =
                                            [[ASDKDataAccessorResponseFileContent alloc] initWithContent:content
                                                                                              contentURL:downloadedContentURL
                                                                                            isCachedData:isLocalContent
                                                                                                   error:error];
                                            
                                            if (strongSelf.delegate) {
                                                [strongSelf.delegate dataAccessor:strongSelf
                                                              didLoadDataResponse:responseFileContent];
                                                
                                                [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
                                            }
                                        }];
}


#pragma mark -
#pragma mark Service - Fetch REST values for task

- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID {
    // Define operations
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [self remoteRestFieldValuesOperationForTaskID:taskID
                                                                                            withFormFieldID:fieldID];
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [self cachedRestFieldValuesOperationForTaskID:taskID
                                                                                            withFormFieldID:fieldID];
    ASDKAsyncBlockOperation *storeInCacheRestFieldValuesOperation = [self restFieldValuesStoreInCacheOperationForTaskID:taskID
                                                                                                        withFormFieldID:fieldID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteRestFieldValuesOperation];
            [self.processingQueue addOperations:@[remoteRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteRestFieldValuesOperation addDependency:cachedRestFieldValuesOperation];
            [storeInCacheRestFieldValuesOperation addDependency:remoteRestFieldValuesOperation];
            [completionOperation addDependency:storeInCacheRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  remoteRestFieldValuesOperation,
                                                  storeInCacheRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default:break;
    }
}

- (ASDKAsyncBlockOperation *)remoteRestFieldValuesOperationForTaskID:(NSString *)taskID
                                                     withFormFieldID:(NSString *)fieldID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf.formNetworkService fetchRestFieldValuesForTaskWithID:taskID
                                                             withFieldID:fieldID
                                                         completionBlock:^(NSArray *restFieldValues, NSError *error) {
                                                             if (operation.isCancelled) {
                                                                 [operation complete];
                                                                 return;
                                                             }
                                                             
                                                             ASDKDataAccessorResponseCollection *responseCollection =
                                                             [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
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
    
    return remoteRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)cachedRestFieldValuesOperationForTaskID:(NSString *)taskID
                                                     withFormFieldID:(NSString *)fieldID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.formCacheService
         fetchRestFieldValuesForTaskID:taskID
         withFormFieldID:fieldID
         withCompletionBlock:^(NSArray *restFieldValues, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             if (!error) {
                 ASDKLogVerbose(@"Rest field values fetched succesfully from cache for taskID:%@ and formFieldID:%@", taskID, fieldID);
                 
                 ASDKDataAccessorResponseCollection *response = [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
                                                                                                                  isCachedData:YES
                                                                                                                         error:error];
                 if (weakSelf.delegate) {
                     [weakSelf.delegate dataAccessor:weakSelf
                                 didLoadDataResponse:response];
                 } else {
                     ASDKLogError(@"An error occured while fetching cached rest field values for taskID:%@ and formFieldID:%@. Reason: %@", taskID, fieldID, error.localizedDescription);
                 }
                 
                 [operation complete];
             }
         }];
    }];
    
    return cachedRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)restFieldValuesStoreInCacheOperationForTaskID:(NSString *)taskID
                                                           withFormFieldID:(NSString *)fieldID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.formCacheService cacheRestFieldValues:remoteResponse.collection
                                                    forTaskID:taskID
                                              withFormFieldID:fieldID
                                          withCompletionBlock:^(NSError *error) {
                                              if (operation.isCancelled) {
                                                  [operation complete];
                                                  return;
                                              }
                                              
                                              if (!error) {
                                                  ASDKLogVerbose(@"Rest field values cached successfully for taskID:%@ and formFieldID:%@.", taskID, fieldID);
                                                  [weakSelf.formCacheService saveChanges];
                                              } else {
                                                  ASDKLogError(@"Encountered an error while caching rest field values for taskID:%@ and formFieldID:%@", taskID, fieldID);
                                              }
                                              
                                              [operation complete];
                                          }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service - Fetch REST values in start form

- (void)fetchRestFieldValuesOfStartFormForProcessDefinitionID:(NSString *)processDefinitionID
                                              withFormFieldID:(NSString *)fieldID {
    // Define operations
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [self remoteRestFieldValuesOperationForProcessDefinitionID:processDefinitionID
                                                                                                         withFormFieldID:fieldID];
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [self cachedRestFieldValuesOperationForProcessDefinitionID:processDefinitionID
                                                                                                           withFormField:fieldID];
    ASDKAsyncBlockOperation *storeInCacheRestFieldValuesOperation =
    [self restFieldValuesStoreInCacheOperationForProcessDefinitionID:processDefinitionID
                                                     withFormFieldID:fieldID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteRestFieldValuesOperation];
            [self.processingQueue addOperations:@[remoteRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteRestFieldValuesOperation addDependency:cachedRestFieldValuesOperation];
            [storeInCacheRestFieldValuesOperation addDependency:remoteRestFieldValuesOperation];
            [completionOperation addDependency:storeInCacheRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  remoteRestFieldValuesOperation,
                                                  storeInCacheRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default:break;
    }
}

- (ASDKAsyncBlockOperation *)remoteRestFieldValuesOperationForProcessDefinitionID:(NSString *)processDefinitionID
                                                                  withFormFieldID:(NSString *)fieldID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf.formNetworkService
         fetchRestFieldValuesForStartFormWithProcessDefinitionID:processDefinitionID
         withFieldID:fieldID
         completionBlock:^(NSArray *restFieldValues, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             ASDKDataAccessorResponseCollection *responseCollection =
             [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
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
    
    return remoteRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)cachedRestFieldValuesOperationForProcessDefinitionID:(NSString *)processDefinitionID
                                                                    withFormField:(NSString *)fieldID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.formCacheService
         fetchRestFieldValuesForProcessDefinitionID:processDefinitionID
         withFormFieldID:fieldID
         withCompletionBlock:^(NSArray *restFieldValues, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             if (!error) {
                 ASDKLogVerbose(@"Rest field values fetched succesfully from cache for processDefinitionID:%@ and formFieldID:%@", processDefinitionID, fieldID);
                 
                 ASDKDataAccessorResponseCollection *response = [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
                                                                                                                  isCachedData:YES
                                                                                                                         error:error];
                 if (weakSelf.delegate) {
                     [weakSelf.delegate dataAccessor:weakSelf
                                 didLoadDataResponse:response];
                 } else {
                     ASDKLogError(@"An error occured while fetching cached rest field values for processDefinitionID:%@ and formFieldID:%@. Reason: %@", processDefinitionID, fieldID, error.localizedDescription);
                 }
                 
                 [operation complete];
             }
         }];
    }];
    
    return cachedRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)restFieldValuesStoreInCacheOperationForProcessDefinitionID:(NSString *)processDefinitionID
                                                                        withFormFieldID:(NSString *)fieldID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.formCacheService cacheRestFieldValues:remoteResponse.collection
                                       forProcessDefinitionID:processDefinitionID
                                              withFormFieldID:fieldID
                                          withCompletionBlock:^(NSError *error) {
                                              if (operation.isCancelled) {
                                                  [operation complete];
                                                  return;
                                              }
                                              
                                              if (!error) {
                                                  ASDKLogVerbose(@"Rest field values cached successfully for processDefinitionID:%@ and formFieldID:%@.", processDefinitionID, fieldID);
                                                  [weakSelf.formCacheService saveChanges];
                                              } else {
                                                  ASDKLogError(@"Encountered an error while caching rest field values for processDefinitionID:%@ and formFieldID:%@", processDefinitionID, fieldID);
                                              }
                                              
                                              [operation complete];
                                          }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service -  Fetch REST values for task in dynamic table

- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID
                         withColumnID:(NSString *)columnID {
    // Define operations
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [self remoteRestFieldValuesOperationForTaskID:taskID
                                                                                            withFormFieldID:fieldID
                                                                                               withColumnID:columnID];
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [self cachedRestFieldValuesOperationForTaskID:taskID
                                                                                            withFormFieldID:fieldID
                                                                                               withColumnID:columnID];
    ASDKAsyncBlockOperation *storeInCacheRestFieldValuesOperation =
    [self restFieldValuesStoreInCacheOperationForTaskID:taskID
                                        withFormFieldID:fieldID
                                           withColumnID:columnID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteRestFieldValuesOperation];
            [self.processingQueue addOperations:@[remoteRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteRestFieldValuesOperation addDependency:cachedRestFieldValuesOperation];
            [storeInCacheRestFieldValuesOperation addDependency:remoteRestFieldValuesOperation];
            [completionOperation addDependency:storeInCacheRestFieldValuesOperation];
            [self.processingQueue addOperations:@[cachedRestFieldValuesOperation,
                                                  remoteRestFieldValuesOperation,
                                                  storeInCacheRestFieldValuesOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default:break;
    }
}

- (ASDKAsyncBlockOperation *)remoteRestFieldValuesOperationForTaskID:(NSString *)taskID
                                                     withFormFieldID:(NSString *)fieldID
                                                        withColumnID:(NSString *)columnID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf.formNetworkService
         fetchRestFieldValuesForTaskWithID:taskID
         withFieldID:fieldID
         withColumnID:columnID
         completionBlock:^(NSArray *restFieldValues, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             ASDKDataAccessorResponseCollection *responseCollection =
             [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
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
    
    return remoteRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)cachedRestFieldValuesOperationForTaskID:(NSString *)taskID
                                                     withFormFieldID:(NSString *)fieldID
                                                        withColumnID:(NSString *)columnID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedRestFieldValuesOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.formCacheService
         fetchRestFieldValuesForTaskID:taskID
         withFormFieldID:fieldID
         withColumnID:columnID
         withCompletionBlock:^(NSArray *restFieldValues, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             if (!error) {
                 ASDKLogVerbose(@"Rest field values fetched succesfully from cache for taskID:%@ , formFieldID:%@ and columnID:%@", taskID, fieldID, columnID);
                 
                 ASDKDataAccessorResponseCollection *response = [[ASDKDataAccessorResponseCollection alloc] initWithCollection:restFieldValues
                                                                                                                  isCachedData:YES
                                                                                                                         error:error];
                 if (weakSelf.delegate) {
                     [weakSelf.delegate dataAccessor:weakSelf
                                 didLoadDataResponse:response];
                 } else {
                     ASDKLogError(@"An error occured while fetching cached rest field values for taskID:%@ , formFieldID:%@ and columnID:%@ . Reason: %@", taskID, fieldID, columnID, error.localizedDescription);
                 }
                 
                 [operation complete];
             }
         }];
    }];
    
    return cachedRestFieldValuesOperation;
}

- (ASDKAsyncBlockOperation *)restFieldValuesStoreInCacheOperationForTaskID:(NSString *)taskID
                                                           withFormFieldID:(NSString *)fieldID
                                                              withColumnID:(NSString *)columnID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.formCacheService cacheRestFieldValues:remoteResponse.collection
                                                    forTaskID:taskID
                                              withFormFieldID:fieldID
                                                 withColumnID:columnID
                                          withCompletionBlock:^(NSError *error) {
                                              if (operation.isCancelled) {
                                                  [operation complete];
                                                  return;
                                              }
                                              
                                              if (!error) {
                                                  ASDKLogVerbose(@"Rest field values cached successfully for taskID:%@ , formFieldID:%@ and columnID:%@.", taskID, fieldID, columnID);
                                                  [weakSelf.formCacheService saveChanges];
                                              } else {
                                                  ASDKLogError(@"Encountered an error while caching rest field values for taskID:%@ , formFieldID:%@ and columnID:%@", taskID, fieldID, columnID);
                                              }
                                              
                                              [operation complete];
                                          }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service - Fetch REST values for dynamic table in start form

- (void)fetchRestFieldValuesOfStartFormWithProcessDefinitionID:(NSString *)processDefinitionID
                                                 withFormField:(NSString *)fieldID
                                                  withColumnID:(NSString *)columnID {
    
}


#pragma mark -
#pragma mark Cancel operations

- (void)cancelOperations {
    [super cancelOperations];
    [self.processingQueue cancelAllOperations];
    [self.formNetworkService cancelAllNetworkOperations];
}


#pragma mark -
#pragma mark Private interface

- (ASDKFormNetworkServices *)formNetworkService {
    return (ASDKFormNetworkServices *)self.networkService;
}

- (ASDKFormCacheService *)formCacheService {
    return (ASDKFormCacheService *)self.cacheService;
}

- (ASDKAsyncBlockOperation *)defaultCompletionOperation {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *completionOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (operation.isCancelled) {
            [operation complete];
        }
        
        if (strongSelf.delegate) {
            [strongSelf.delegate dataAccessorDidFinishedLoadingDataResponse:strongSelf];
        }
        
        [operation complete];
    }];
    
    return completionOperation;
}

@end
