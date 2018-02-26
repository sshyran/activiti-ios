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

@end
