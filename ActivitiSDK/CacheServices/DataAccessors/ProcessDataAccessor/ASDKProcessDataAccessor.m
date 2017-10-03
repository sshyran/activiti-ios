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
    return nil;
}

- (ASDKAsyncBlockOperation *)cachedProcessInstanceListOperationForFilter:(ASDKFilterRequestRepresentation *)filter {
    return nil;
}

- (ASDKAsyncBlockOperation *)processInstanceListStoreInCacheOperationWithFilter:(ASDKFilterRequestRepresentation *)filter {
    return nil;
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
