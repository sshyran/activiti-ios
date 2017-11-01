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

#import "ASDKProcessDataAccessor.h"

// Constants
#import "ASDKLogConfiguration.h"

// Operations
#import "ASDKAsyncBlockOperation.h"

// Managers
#import "ASDKBootstrap.h"
#import "ASDKProcessInstanceNetworkServices.h"
#import "ASDKServiceLocator.h"
#import "ASDKProcessInstanceCacheService.h"

// Model
#import "ASDKDataAccessorResponseCollection.h"
#import "ASDKDataAccessorResponseModel.h"

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKProcessDataAccessor ()

@property (strong, nonatomic) NSOperationQueue *processingQueue;

@end

@implementation ASDKProcessDataAccessor

- (instancetype)initWithDelegate:(id<ASDKDataAccessorDelegate>)delegate {
    self = [super initWithDelegate:delegate];
    
    if (self) {
        _processingQueue = [self serialOperationQueue];
        _cachePolicy = ASDKServiceDataAccessorCachingPolicyHybrid;
        dispatch_queue_t processUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue",
                                                                                 [NSBundle bundleForClass:[self class]].bundleIdentifier,
                                                                                 NSStringFromClass([self class])] UTF8String],
                                                                               DISPATCH_QUEUE_SERIAL);
        // Acquire and set up the process instance network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        _networkService = (ASDKProcessInstanceNetworkServices *)[sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKProcessInstanceNetworkServiceProtocol)];
        _networkService.resultsQueue = processUpdatesProcessingQueue;
        _cacheService = [ASDKProcessInstanceCacheService new];
    }
    
    return self;
}


#pragma mark -
#pragma mark Service - Process instance list

- (void)fetchProcessInstancesWithFilter:(ASDKFilterRequestRepresentation *)filter {
    NSParameterAssert(filter);
    
    // Define operations
    ASDKAsyncBlockOperation *remoteProcessInstanceListOperation = [self remoteProcessInstanceListOperationForFilter:filter];
    ASDKAsyncBlockOperation *cachedProcessInstanceListOperation = [self cachedProcessInstanceListOperationForFilter:filter];
    ASDKAsyncBlockOperation *storeInCacheProcessInstanceListOperation = [self processInstanceListStoreInCacheOperationWithFilter:filter];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedProcessInstanceListOperation];
            [self.processingQueue addOperations:@[cachedProcessInstanceListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteProcessInstanceListOperation];
            [self.processingQueue addOperations:@[remoteProcessInstanceListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteProcessInstanceListOperation addDependency:cachedProcessInstanceListOperation];
            [storeInCacheProcessInstanceListOperation addDependency:remoteProcessInstanceListOperation];
            [completionOperation addDependency:storeInCacheProcessInstanceListOperation];
            [self.processingQueue addOperations:@[cachedProcessInstanceListOperation,
                                                  remoteProcessInstanceListOperation,
                                                  storeInCacheProcessInstanceListOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default: break;
    }
}

- (ASDKAsyncBlockOperation *)remoteProcessInstanceListOperationForFilter:(ASDKFilterRequestRepresentation *)filter {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteProcessInstanceListOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.processInstanceNetworkService
         fetchProcessInstanceListWithFilterRepresentation:filter
         completionBlock:^(NSArray *processes, NSError *error, ASDKModelPaging *paging) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             ASDKDataAccessorResponseCollection *responseCollection =[[ASDKDataAccessorResponseCollection alloc] initWithCollection:processes
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
    
    return remoteProcessInstanceListOperation;
}

- (ASDKAsyncBlockOperation *)cachedProcessInstanceListOperationForFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedProcessInstanceListOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.processInstanceCacheService fetchProcessInstanceList:^(NSArray *processes, NSError *error, ASDKModelPaging *paging) {
            if (operation.isCancelled) {
                [operation complete];
                return;
            }
            
            if (!error) {
                ASDKLogVerbose(@"Process instance list information successfully fetched from the cache for filter.\nFilter:%@", filter);
                
                ASDKDataAccessorResponseCollection *response = [[ASDKDataAccessorResponseCollection alloc] initWithCollection:processes
                                                                                                                       paging:paging
                                                                                                                 isCachedData:YES
                                                                                                                        error:error];
                if (weakSelf.delegate) {
                    [weakSelf.delegate dataAccessor:weakSelf
                                didLoadDataResponse:response];
                }
            } else {
                ASDKLogError(@"An error occured while fetching cache process instance list information. Reason: %@", error.localizedDescription);
            }
            
            [operation complete];
        } usingFilter:filter];
    }];
    
    return cachedProcessInstanceListOperation;
}

- (ASDKAsyncBlockOperation *)processInstanceListStoreInCacheOperationWithFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseCollection *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.collection) {
            [strongSelf.processInstanceCacheService cacheProcessInstanceList:remoteResponse.collection
                                                                 usingFilter:filter
                                                         withCompletionBlock:^(NSError *error) {
                                                             if (operation.isCancelled) {
                                                                 [operation complete];
                                                                 return;
                                                             }
                                                             
                                                             if (!error) {
                                                                 ASDKLogVerbose(@"Process intance list was successfully cached for filter.\nFilter: %@", filter);
                                                                 
                                                                 [weakSelf.processInstanceCacheService saveChanges];
                                                             } else {
                                                                 ASDKLogError(@"Encountered an error while caching the process instance list for filter: %@. Reason: %@", filter, error.localizedDescription);
                                                             }
                                                             
                                                             [operation complete];
                                                         }];
        }
    }];
    
    return storeInCacheOperation;
}


#pragma mark -
#pragma mark Service - Process instance details

- (void)fetchProcessInstanceDetailsForProcessInstanceID:(NSString *)processInstanceID {
    NSParameterAssert(processInstanceID);
    
    // Define operations
    ASDKAsyncBlockOperation *remoteProcessInstanceDetailsOperation = [self remoteProcessInstanceDetailsForProcessInstanceID:processInstanceID];
    ASDKAsyncBlockOperation *cachedProcessInstanceDetailsOperation = [self cachedProcessInstanceDetailsForProcessInstanceID:processInstanceID];
    ASDKAsyncBlockOperation *storeInCacheProcessInstanceDetailsOperation = [self processInstanceDetailsStoreInCacheOperationForProcessInstanceID:processInstanceID];
    ASDKAsyncBlockOperation *completionOperation = [self defaultCompletionOperation];
    
    // Handle cache policies
    switch (self.cachePolicy) {
        case ASDKServiceDataAccessorCachingPolicyCacheOnly: {
            [completionOperation addDependency:cachedProcessInstanceDetailsOperation];
            [self.processingQueue addOperations:@[cachedProcessInstanceDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyAPIOnly: {
            [completionOperation addDependency:remoteProcessInstanceDetailsOperation];
            [self.processingQueue addOperations:@[remoteProcessInstanceDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        case ASDKServiceDataAccessorCachingPolicyHybrid: {
            [remoteProcessInstanceDetailsOperation addDependency:cachedProcessInstanceDetailsOperation];
            [storeInCacheProcessInstanceDetailsOperation addDependency:remoteProcessInstanceDetailsOperation];
            [completionOperation addDependency:storeInCacheProcessInstanceDetailsOperation];
            [self.processingQueue addOperations:@[cachedProcessInstanceDetailsOperation,
                                                  remoteProcessInstanceDetailsOperation,
                                                  storeInCacheProcessInstanceDetailsOperation,
                                                  completionOperation]
                              waitUntilFinished:NO];
        }
            break;
            
        default: break;
    }
}

- (ASDKAsyncBlockOperation *)remoteProcessInstanceDetailsForProcessInstanceID:(NSString *)processInstanceID {
    if ([self.delegate respondsToSelector:@selector(dataAccessorDidStartFetchingRemoteData:)]) {
        [self.delegate dataAccessorDidStartFetchingRemoteData:self];
    }
    
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *remoteProcessInstanceDetailsOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.processInstanceNetworkService fetchProcessInstanceDetailsForID:processInstanceID
                                                                   completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                                                       if (operation.isCancelled) {
                                                                           [operation complete];
                                                                           return;
                                                                       }
                                                                       
                                                                       ASDKDataAccessorResponseModel *response = [[ASDKDataAccessorResponseModel alloc] initWithModel:processInstance
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
    
    return remoteProcessInstanceDetailsOperation;
}

- (ASDKAsyncBlockOperation *)cachedProcessInstanceDetailsForProcessInstanceID:(NSString *)processInstanceID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *cachedProcessInstanceDetailsOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf.processInstanceCacheService
         fetchProcesInstanceDetailsForID:processInstanceID
         withCompletionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
             if (operation.isCancelled) {
                 [operation complete];
                 return;
             }
             
             if (!error) {
                 if (processInstance) {
                     ASDKLogVerbose(@"Process instance details information successfully fetched from cache for processInstanceID:%@", processInstanceID);
                     
                     ASDKDataAccessorResponseModel *response = [[ASDKDataAccessorResponseModel alloc] initWithModel:processInstance
                                                                                                       isCachedData:YES
                                                                                                              error:error];
                     
                     if (weakSelf.delegate) {
                         [weakSelf.delegate dataAccessor:weakSelf
                                     didLoadDataResponse:response];
                     }
                 }
             } else {
                 ASDKLogError(@"An error occured while fetching cached process instance details for processInstanceID:%@. Reason:%@", processInstanceID, error.localizedDescription);
             }
             
             [operation complete];
         }];
    }];
    
    return cachedProcessInstanceDetailsOperation;
}

- (ASDKAsyncBlockOperation *)processInstanceDetailsStoreInCacheOperationForProcessInstanceID:(NSString *)processInstanceID {
    __weak typeof(self) weakSelf = self;
    ASDKAsyncBlockOperation *storeInCacheOperation = [ASDKAsyncBlockOperation blockOperationWithBlock:^(ASDKAsyncBlockOperation *operation) {
        __strong typeof(self) strongSelf = weakSelf;
        ASDKAsyncBlockOperation *dependencyOperation = (ASDKAsyncBlockOperation *)operation.dependencies.firstObject;
        ASDKDataAccessorResponseModel *remoteResponse = dependencyOperation.result;
        
        if (remoteResponse.model) {
            [strongSelf.processInstanceCacheService cacheProcessInstanceDetails:remoteResponse.model
                                                            withCompletionBlock:^(NSError *error) {
                                                                if (operation.isCancelled) {
                                                                    [operation complete];
                                                                    return;
                                                                }
                                                                
                                                                if (!error) {
                                                                    ASDKLogVerbose(@"Process instance details successfully cached for processInstanceID: %@", processInstanceID);
                                                                    [[weakSelf processInstanceCacheService] saveChanges];
                                                                } else {
                                                                    ASDKLogError(@"Encountered an error while caching the process instance details for processInstanceID: %@. Reason: %@", processInstanceID, error.localizedDescription);
                                                                    
                                                                    [operation complete];
                                                                }
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
}


#pragma mark -
#pragma mark Private interface

- (ASDKProcessInstanceNetworkServices *)processInstanceNetworkService {
    return (ASDKProcessInstanceNetworkServices *)self.networkService;
}

- (ASDKProcessInstanceCacheService *)processInstanceCacheService {
    return (ASDKProcessInstanceCacheService *)self.cacheService;
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
