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

#import "AFAProcessServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAProcessServices() <ASDKDataAccessorDelegate>

// Process instance list
@property (strong, nonatomic) ASDKProcessDataAccessor                           *fetchProcessInstanceListDataAccessor;
@property (copy, nonatomic) AFAProcessServiceProcessInstanceListCompletionBlock processInstanceListCompletionBlock;
@property (copy, nonatomic) AFAProcessServiceProcessInstanceListCompletionBlock processInstanceCachedResultsBlock;

// Process instance details
@property (strong, nonatomic) ASDKProcessDataAccessor                           *fetchProcessInstanceDetailsDataAccessor;
@property (copy, nonatomic) AFAProcessInstanceCompletionBlock                   processInstanceDetailsCompletionBlock;
@property (copy, nonatomic) AFAProcessInstanceCompletionBlock                   processInstanceDetailsCachedResultsBlock;

// Process instance content
@property (strong, nonatomic) ASDKProcessDataAccessor                           *fetchProcessInstanceContentDataAccessor;
@property (copy, nonatomic) AFAProcessInstanceContentCompletionBlock            processInstanceContentCompletionBlock;
@property (copy, nonatomic) AFAProcessInstanceContentCompletionBlock            processInstanceContentCachedResultsBlock;

// Delete process instance
@property (strong, nonatomic) ASDKProcessDataAccessor                           *deleteProcessInstanceDataAccessor;
@property (copy, nonatomic) AFAProcessInstanceDeleteCompletionBlock             deleteProcessInstanceCompletionBlock;

// Create process instance comment
@property (strong, nonatomic) ASDKProcessDataAccessor                           *createProcessInstanceCommentDataAccessor;
@property (copy, nonatomic) AFAProcessInstanceCreateCommentCompletionBlock      createprocessInstanceCommentCompletionBlock;

// Process instance comment list
@property (strong, nonatomic) ASDKProcessDataAccessor                           *fetchProcessInstanceCommentListDataAccessor;
@property (copy, nonatomic)  AFAProcessInstanceCommentsCompletionBlock          processInstanceCommentsCompletionBlock;
@property (copy, nonatomic)  AFAProcessInstanceCommentsCompletionBlock          processInstanceCommentsCachedResultsBlock;

// Process instance audit log
@property (strong, nonatomic) ASDKProcessDataAccessor                           *processInstanceAuditLogDownloadDataAccessor;
@property (copy, nonatomic) AFAProcessInstanceContentDownloadProgressBlock      processInstanceAuditLogDownloadProgressBlock;
@property (copy, nonatomic) AFAProcessInstanceContentDownloadCompletionBlock    processInstanceAuditLogDownloadCompletionBlock;

@property (strong, nonatomic) dispatch_queue_t                      processUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKProcessInstanceNetworkServices    *processInstanceNetworkService;
@property (strong, nonatomic) ASDKProcessDefinitionNetworkServices  *processDefinitionNetworkService;

@end

@implementation AFAProcessServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.processUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.processInstanceNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKProcessInstanceNetworkServiceProtocol)];
        self.processDefinitionNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKProcessDefinitionNetworkServiceProtocol)];
        self.processInstanceNetworkService.resultsQueue = self.processUpdatesProcessingQueue;
        self.processDefinitionNetworkService.resultsQueue = self.processUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestProcessInstanceListWithFilter:(AFAGenericFilterModel *)filter
                         withCompletionBlock:(AFAProcessServiceProcessInstanceListCompletionBlock)completionBlock
                               cachedResults:(AFAProcessServiceProcessInstanceListCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.processInstanceListCompletionBlock = completionBlock;
    self.processInstanceCachedResultsBlock = cacheCompletionBlock;
    
    // Create request representation for the filter model
    ASDKFilterRequestRepresentation *filterRequestRepresentation = [ASDKFilterRequestRepresentation new];
    filterRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    filterRequestRepresentation.appDefinitionID = filter.appDefinitionID;
    filterRequestRepresentation.filterID = filter.filterID;
    
    ASDKModelFilter *modelFilter = [ASDKModelFilter new];
    modelFilter.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    modelFilter.sortType = (NSInteger)filter.sortType;
    modelFilter.state = (NSInteger)filter.state;
    modelFilter.assignmentType = (NSInteger)filter.assignmentType;
    modelFilter.name = filter.text;
    
    filterRequestRepresentation.filterModel = modelFilter;
    filterRequestRepresentation.page = filter.page;
    filterRequestRepresentation.size = filter.size;
    
    self.fetchProcessInstanceListDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.fetchProcessInstanceListDataAccessor fetchProcessInstancesWithFilter:filterRequestRepresentation];
}

- (void)requestProcessDefinitionListWithCompletionBlock:(AFAProcessDefinitionListCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.processDefinitionNetworkService
     fetchProcessDefinitionListWithCompletionBlock:^(NSArray *processDefinitions, NSError *error, ASDKModelPaging *paging) {
         if (!error && processDefinitions) {
             AFALogVerbose(@"Fetched %lu process definition entries", (unsigned long)processDefinitions.count);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock (processDefinitions, nil, paging);
             });
         } else {
             AFALogError(@"An error occured while fetching the process definition list. Reason:%@", error.localizedDescription);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error, nil);
             });
         }
     }];
}

- (void)requestProcessDefinitionListForAppID:(NSString *)appID
                         withCompletionBlock:(AFAProcessDefinitionListCompletionBlock)completionBlock {
    NSParameterAssert(appID);
    NSParameterAssert(completionBlock);
    
    [self.processDefinitionNetworkService
     fetchProcessDefinitionListForAppID:appID
     completionBlock:^(NSArray *processDefinitions, NSError *error, ASDKModelPaging *paging) {
         if (!error && processDefinitions) {
             AFALogVerbose(@"Fetched %lu process definition entries", (unsigned long)processDefinitions.count);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock (processDefinitions, nil, paging);
             });
         } else {
             AFALogError(@"An error occured while fetching the process definition list. Reason:%@", error.localizedDescription);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error, nil);
             });
         }
     }];
}

- (void)requestProcessInstanceStartForProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
                                        completionBlock:(AFAProcessInstanceCompletionBlock)completionBlock {
    NSParameterAssert(processDefinition);
    NSParameterAssert(completionBlock);
    
    ASDKStartProcessRequestRepresentation *startProcessRequestRepresentation = [ASDKStartProcessRequestRepresentation new];
    startProcessRequestRepresentation.processDefinitionID = processDefinition.modelID;
    startProcessRequestRepresentation.name = processDefinition.name;
    
    [self.processInstanceNetworkService
     startProcessInstanceWithStartProcessRequestRepresentation:startProcessRequestRepresentation
     completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
         if (!error && processInstance) {
             AFALogVerbose(@"Started an instance for process %@", processInstance.name);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock (processInstance, nil);
             });
         } else {
             AFALogError(@"An error occured while starting an instance for process definition %@. Reason:%@", processDefinition.name, error.localizedDescription);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
             });
         }
     }];
}

- (void)requestProcessInstanceDetailsForID:(NSString *)processInstanceID
                           completionBlock:(AFAProcessInstanceCompletionBlock)completionBlock
                             cachedResults:(AFAProcessInstanceCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.processInstanceDetailsCompletionBlock = completionBlock;
    self.processInstanceDetailsCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchProcessInstanceDetailsDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.fetchProcessInstanceDetailsDataAccessor fetchProcessInstanceDetailsForProcessInstanceID:processInstanceID];
}

- (void)requestProcessInstanceContentForProcessInstanceID:(NSString *)processInstanceID
                                          completionBlock:(AFAProcessInstanceContentCompletionBlock)completionBlock
                                            cachedResults:(AFAProcessInstanceContentCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.processInstanceContentCompletionBlock = completionBlock;
    self.processInstanceContentCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchProcessInstanceContentDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.fetchProcessInstanceContentDataAccessor fetchProcessInstanceContentForProcessInstanceID:processInstanceID];
}

- (void)requestProcessInstanceCommentsForID:(NSString *)processInstanceID
                        withCompletionBlock:(AFAProcessInstanceCommentsCompletionBlock)completionBlock
                              cachedResults:(AFAProcessInstanceCommentsCompletionBlock)cacheCompletionBlock {
    NSParameterAssert(completionBlock);
    
    self.processInstanceCommentsCompletionBlock = completionBlock;
    self.processInstanceCommentsCachedResultsBlock = cacheCompletionBlock;
    
    self.fetchProcessInstanceCommentListDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.fetchProcessInstanceCommentListDataAccessor fetchProcessInstanceCommentsForProcessInstanceID:processInstanceID];
}

- (void)requestCreateComment:(NSString *)comment
        forProcessInstanceID:(NSString *)processInstanceID
             completionBlock:(AFAProcessInstanceCreateCommentCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.createprocessInstanceCommentCompletionBlock = completionBlock;
    
    self.createProcessInstanceCommentDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.createProcessInstanceCommentDataAccessor createComment:comment
                                            forProcessInstanceID:processInstanceID];
}

- (void)requestDeleteProcessInstanceWithID:(NSString *)processInstanceID
                           completionBlock:(AFAProcessInstanceDeleteCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    self.deleteProcessInstanceCompletionBlock = completionBlock;
    
    self.deleteProcessInstanceDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    [self.deleteProcessInstanceDataAccessor deleteProcessInstanceWithID:processInstanceID];
}

- (void)requestDownloadAuditLogForProcessInstanceWithID:(NSString *)processInstanceID
                                     allowCachedResults:(BOOL)allowCachedResults
                                          progressBlock:(AFAProcessInstanceContentDownloadProgressBlock)progressBlock
                                        completionBlock:(AFAProcessInstanceContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    
    self.processInstanceAuditLogDownloadProgressBlock = progressBlock;
    self.processInstanceAuditLogDownloadCompletionBlock = completionBlock;
    
    self.processInstanceAuditLogDownloadDataAccessor = [[ASDKProcessDataAccessor alloc] initWithDelegate:self];
    self.processInstanceAuditLogDownloadDataAccessor.cachePolicy = allowCachedResults ? ASDKServiceDataAccessorCachingPolicyHybrid : ASDKServiceDataAccessorCachingPolicyAPIOnly;
    [self.processInstanceAuditLogDownloadDataAccessor downloadAuditLogForProcessInstanceWithID:processInstanceID];
}


#pragma mark -
#pragma mark ASDKDataAccessorDelegate

- (void)dataAccessor:(id<ASDKServiceDataAccessorProtocol>)dataAccessor
 didLoadDataResponse:(ASDKDataAccessorResponseBase *)response {
    if (self.fetchProcessInstanceListDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceListDataAccessorResponse:response];
    } else if (self.fetchProcessInstanceDetailsDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceDetailsDataAccessorResponse:response];
    } else if (self.fetchProcessInstanceContentDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceContentListDataAccessorResponse:response];
    } else if (self.deleteProcessInstanceDataAccessor == dataAccessor) {
        [self handleDeleteProcessInstanceDataAccessorResponse:response];
    } else if (self.createProcessInstanceCommentDataAccessor == dataAccessor) {
        [self handleCreateProcessInstanceCommentDataAccessorResponse:response];
    } else if (self.fetchProcessInstanceCommentListDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceInstanceCommentListDataAccessorResponse:response];
    } else if (self.processInstanceAuditLogDownloadDataAccessor == dataAccessor) {
        [self handleProcessInstanceAuditLogDownloadDataAccessorResponse:response];
    }
}

- (void)dataAccessorDidFinishedLoadingDataResponse:(id<ASDKServiceDataAccessorProtocol>)dataAccessor {
}


#pragma mark -
#pragma mark Private interface

- (void)handleFetchProcessInstanceListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *processInstanceListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *processInstanceList = processInstanceListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!processInstanceListResponse.error) {
        if (processInstanceListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.processInstanceCachedResultsBlock) {
                    strongSelf.processInstanceCachedResultsBlock(processInstanceList, processInstanceListResponse.error, processInstanceListResponse.paging);
                    strongSelf.processInstanceCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.processInstanceListCompletionBlock) {
            strongSelf.processInstanceListCompletionBlock(processInstanceList, processInstanceListResponse.error, processInstanceListResponse.paging);
            strongSelf.processInstanceListCompletionBlock = nil;
        }
    });
}

- (void)handleFetchProcessInstanceContentListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *processInstanceContentListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *processInstanceContentList = processInstanceContentListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!processInstanceContentListResponse.error) {
        if (processInstanceContentListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.processInstanceContentCachedResultsBlock) {
                    strongSelf.processInstanceContentCachedResultsBlock(processInstanceContentList, processInstanceContentListResponse.error);
                    strongSelf.processInstanceContentCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.processInstanceContentCompletionBlock) {
            strongSelf.processInstanceContentCompletionBlock(processInstanceContentList, processInstanceContentListResponse.error);
            strongSelf.processInstanceContentCompletionBlock = nil;
        }
    });
}

- (void)handleFetchProcessInstanceDetailsDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseModel *processInstanceResponse = (ASDKDataAccessorResponseModel *)response;
    
    __weak typeof(self) weakSelf = self;
    if (!processInstanceResponse.error) {
        if (processInstanceResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.processInstanceDetailsCachedResultsBlock) {
                    strongSelf.processInstanceDetailsCachedResultsBlock(processInstanceResponse.model, nil);
                    strongSelf.processInstanceDetailsCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.processInstanceDetailsCompletionBlock) {
            strongSelf.processInstanceDetailsCompletionBlock(processInstanceResponse.model, processInstanceResponse.error);
            strongSelf.processInstanceDetailsCompletionBlock = nil;
        }
    });
}

- (void)handleDeleteProcessInstanceDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseConfirmation *processInstanceDeleteResponse = (ASDKDataAccessorResponseConfirmation *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.deleteProcessInstanceCompletionBlock) {
            strongSelf.deleteProcessInstanceCompletionBlock(processInstanceDeleteResponse.isConfirmation, processInstanceDeleteResponse.error);
        }
    });
}

- (void)handleCreateProcessInstanceCommentDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseModel *processInstanceCommentResponse = (ASDKDataAccessorResponseModel *)response;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.createprocessInstanceCommentCompletionBlock) {
            strongSelf.createprocessInstanceCommentCompletionBlock(processInstanceCommentResponse.model, processInstanceCommentResponse.error);
        }
    });
}

- (void)handleFetchProcessInstanceInstanceCommentListDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    ASDKDataAccessorResponseCollection *processInstanceCommentListResponse = (ASDKDataAccessorResponseCollection *)response;
    NSArray *processInstanceCommentList = processInstanceCommentListResponse.collection;
    
    __weak typeof(self) weakSelf = self;
    if (!processInstanceCommentListResponse.error) {
        if (processInstanceCommentListResponse.isCachedData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                
                if (strongSelf.processInstanceCommentsCachedResultsBlock) {
                    strongSelf.processInstanceCommentsCachedResultsBlock(processInstanceCommentList, processInstanceCommentListResponse.error, processInstanceCommentListResponse.paging);
                    strongSelf.processInstanceCommentsCachedResultsBlock = nil;
                }
            });
            
            return;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (strongSelf.processInstanceCommentsCompletionBlock) {
            strongSelf.processInstanceCommentsCompletionBlock(processInstanceCommentList, processInstanceCommentListResponse.error, processInstanceCommentListResponse.paging);
            strongSelf.processInstanceCommentsCompletionBlock = nil;
        }
    });
}

- (void)handleProcessInstanceAuditLogDownloadDataAccessorResponse:(ASDKDataAccessorResponseBase *)response {
    __weak typeof(self) weakSelf = self;
    if ([response isKindOfClass:[ASDKDataAccessorResponseProgress class]]) {
        ASDKDataAccessorResponseProgress *progressResponse = (ASDKDataAccessorResponseProgress *)response;
        NSString *formattedProgressString = progressResponse.formattedProgressString;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.processInstanceAuditLogDownloadProgressBlock) {
                strongSelf.processInstanceAuditLogDownloadProgressBlock(formattedProgressString, progressResponse.error);
            }
        });
    } else if ([response isKindOfClass:[ASDKDataAccessorResponseModel class]]) {
        ASDKDataAccessorResponseModel *auditLogResponse = (ASDKDataAccessorResponseModel *)response;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            
            if (strongSelf.processInstanceAuditLogDownloadCompletionBlock) {
                strongSelf.processInstanceAuditLogDownloadCompletionBlock(auditLogResponse.model, auditLogResponse.isCachedData, auditLogResponse.error);
                strongSelf.processInstanceAuditLogDownloadCompletionBlock = nil;
                strongSelf.processInstanceAuditLogDownloadProgressBlock = nil;
            }
        });
    }
}

@end
