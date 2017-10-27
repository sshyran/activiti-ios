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
                                          completionBlock:(AFAProcessInstanceContentCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    [self.processInstanceNetworkService
     fetchProcesInstanceContentForProcessInstanceID:processInstanceID
     completionBlock:^(NSArray *contentList, NSError *error) {
         if (!error) {
             AFALogVerbose(@"Fetched content collection for process with ID:%@", processInstanceID);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock (contentList, nil);
             });
         } else {
             AFALogError(@"An error occured while fetching the content collection for process with ID:%@. Reason:%@", processInstanceID, error.localizedDescription);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
             });
         }
     }];
}

- (void)requestProcessInstanceCommentsForID:(NSString *)processInstanceID
                        withCompletionBlock:(AFAProcessInstanceCommentsCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    [self.processInstanceNetworkService fetchProcessInstanceCommentsForProcessInstanceID:processInstanceID
                                        completionBlock:^(NSArray *commentList, NSError *error, ASDKModelPaging *paging) {
                                            if (!error) {
                                                AFALogVerbose(@"Fetched comment list for process instance with ID:%@", processInstanceID);
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    completionBlock (commentList, nil, paging);
                                                });
                                            } else {
                                                AFALogError(@"An error occured while fetching the comment list for process instance with ID:%@. Reason:%@", processInstanceID, error.localizedDescription);
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    completionBlock(nil, error, nil);
                                                });
                                            }
                                        }];
}

- (void)requestCreateComment:(NSString *)comment
        forProcessInstanceID:(NSString *)processInstanceID
             completionBlock:(AFAProcessInstanceCreateCommentCompletionBlock)completionBlock {
    NSParameterAssert(comment);
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    [self.processInstanceNetworkService
     createComment:comment
     forProcessInstanceID :processInstanceID
     completionBlock:^(ASDKModelComment *comment, NSError *error) {
         if (!error && comment) {
             AFALogVerbose(@"Comment for process instance ID :%@ created successfully.", processInstanceID);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(comment, nil);
             });
         } else {
             AFALogError(@"An error occured creating comment for process instance ID %@. Reason:%@", processInstanceID, error.localizedDescription);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 completionBlock(nil, error);
             });
         }
     }];
}

- (void)requestDeleteProcessInstanceWithID:(NSString *)processInstanceID
                           completionBlock:(AFAProcessInstanceDeleteCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    [self.processInstanceNetworkService deleteProcessInstanceWithID:processInstanceID
                                                    completionBlock:^(BOOL isProcessInstanceDeleted, NSError *error) {
                                                        if (!error && isProcessInstanceDeleted) {
                                                            AFALogVerbose(@"Process instance with ID:%@ has been deleted successfully.", processInstanceID);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(YES, nil);
                                                            });
                                                        } else {
                                                            AFALogError(@"An error occured while deleting the process instance with ID:%@. Reason:%@", processInstanceID, error.localizedDescription);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(NO, error);
                                                            });
                                                        }
    }];
}

- (void)requestDownloadAuditLogForProcessInstanceWithID:(NSString *)processInstanceID
                                     allowCachedResults:(BOOL)allowCachedResults
                                          progressBlock:(AFAProcessInstanceContentDownloadProgressBlock)progressBlock
                                        completionBlock:(AFAProcessInstanceContentDownloadCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    [self.processInstanceNetworkService downloadAuditLogForProcessInstanceWithID:processInstanceID
                                        allowCachedResults:allowCachedResults
                                             progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                                 AFALogVerbose(@"Downloaded %@ of content for the audit log of task with ID:%@ ", formattedReceivedBytesString, processInstanceID);
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     progressBlock (formattedReceivedBytesString, error);
                                                 });
                                             } completionBlock:^(NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                                 if (!error && downloadedContentURL) {
                                                     AFALogVerbose(@"Audit log content for task with ID:%@ was downloaded successfully.", processInstanceID);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(downloadedContentURL, isLocalContent,nil);
                                                     });
                                                 } else {
                                                     AFALogError(@"An error occured while downloading audit log content for task with ID:%@. Reason:%@", processInstanceID, error.localizedDescription);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock(nil, NO, error);
                                                     });
                                                 }
                                             }];
}


#pragma mark -
#pragma mark ASDKDataAccessorDelegate

- (void)dataAccessor:(id<ASDKServiceDataAccessorProtocol>)dataAccessor
 didLoadDataResponse:(ASDKDataAccessorResponseBase *)response {
    if (self.fetchProcessInstanceListDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceListDataAccessorResponse:response];
    } else if (self.fetchProcessInstanceDetailsDataAccessor == dataAccessor) {
        [self handleFetchProcessInstanceDetailsDataAccessorResponese:response];
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

- (void)handleFetchProcessInstanceDetailsDataAccessorResponese:(ASDKDataAccessorResponseBase *)response {
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

@end
