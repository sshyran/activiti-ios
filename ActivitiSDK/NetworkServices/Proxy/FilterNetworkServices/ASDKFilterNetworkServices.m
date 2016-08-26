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

#import "ASDKFilterNetworkServices.h"

// Constants
#import "ASDKLogConfiguration.h"

// Models
#import "ASDKModelPaging.h"
#import "ASDKFilterListRequestRepresentation.h"
#import "ASDKFilterCreationRequestRepresentation.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKFilterNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKFilterNetworkServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.networkOperations = [NSMutableArray array];
    }
    
    return self;
}


#pragma mark -
#pragma mark ASDKFilterNetworkService Protocol

- (void)fetchTaskFilterListWithCompletionBlock:(ASDKFilterListCompletionBlock)completionBlock {
    [self fetchTaskFilterListWithFilter:nil
                    withCompletionBlock:completionBlock];
}

- (void)fetchTaskFilterListWithFilter:(ASDKFilterListRequestRepresentation *)filter
                  withCompletionBlock:(ASDKFilterListCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory taskFilterListServicePath]
                           parameters:[filter jsonDictionary]
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Filter list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKFilterParserContentTypeFilterList)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            NSParameterAssert(weakSelf.resultsQueue);
                                                                            
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing filter list. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error, nil);
                                                                                });
                                                                            } else {
                                                                                NSArray *taskList = (NSArray *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", taskList);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(taskList, nil, paging);
                                                                                });
                                                                            }
                                                                        }];
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch filter list for request:%@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchProcessInstanceFilterListWithCompletionBlock:(ASDKFilterListCompletionBlock)completionBlock {
    [self fetchProcessInstanceFilterListWithFilter:nil
                               withCompletionBlock:completionBlock];
}

- (void)fetchProcessInstanceFilterListWithFilter:(ASDKFilterListRequestRepresentation *)filter
                             withCompletionBlock:(ASDKFilterListCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory processInstanceFilterListServicePath]
                           parameters:[filter jsonDictionary]
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Filter list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKFilterParserContentTypeFilterList)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            NSParameterAssert(weakSelf.resultsQueue);
                                                                            
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing filter list. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error, nil);
                                                                                });
                                                                            } else {
                                                                                NSArray *taskList = (NSArray *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", taskList);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(taskList, nil, paging);
                                                                                });
                                                                            }
                                                                        }];
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch filter list for request:%@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)createUserTaskFilterWithRepresentation:(ASDKFilterCreationRequestRepresentation *)filter
                           withCompletionBlock:(ASDKFilterModelCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory taskFilterListServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleSuccessfulFilterCreationResponseForOperation:operation
                                                                                   responseObject:responseObject
                                                                                  completionBlock:completionBlock];
                               } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleFailedFilterCreationResponseForOperation:operation
                                                                                        error:error
                                                                          withCompletionBlock:completionBlock];
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)createProcessInstanceTaskFilterWithRepresentation:(ASDKFilterCreationRequestRepresentation *)filter
                                      withCompletionBlock:(ASDKFilterModelCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory processInstanceFilterListServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleSuccessfulFilterCreationResponseForOperation:operation
                                                                                   responseObject:responseObject
                                                                                  completionBlock:completionBlock];
                               } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleFailedFilterCreationResponseForOperation:operation
                                                                                        error:error
                                                                          withCompletionBlock:completionBlock];
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}


#pragma mark -
#pragma mark Private interface

- (void)handleSuccessfulFilterCreationResponseForOperation:(AFHTTPRequestOperation *)operation
                                          responseObject:(id)responseObject
                                         completionBlock:(ASDKFilterModelCompletionBlock)completionBlock {
    // Remove operation reference
    [self.networkOperations removeObject:operation];
    
    NSDictionary *responseDictionary = (NSDictionary *)responseObject;
    ASDKLogVerbose(@"Filter created successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                   operation.request.HTTPMethod,
                   operation.request.URL.absoluteString,
                   [[NSString alloc] initWithData:operation.request.HTTPBody
                                         encoding:NSUTF8StringEncoding],
                   responseDictionary);
    
    // Parse response data
    __weak typeof(self) weakSelf = self;
    [self.parserOperationManager parseContentDictionary:responseDictionary
                                                       ofType:CREATE_STRING(ASDKFilterParserContentTypeFilterDetails)
                                          withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                              __strong typeof(self) strongSelf = weakSelf;
                                              NSParameterAssert(strongSelf.resultsQueue);
                                              
                                              if (error) {
                                                  ASDKLogError(@"Error parsing filter details. Description:%@", error.localizedDescription);
                                                  
                                                  dispatch_async(weakSelf.resultsQueue, ^{
                                                      completionBlock(nil, error);
                                                  });
                                              } else {
                                                  ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                  
                                                  dispatch_async(weakSelf.resultsQueue, ^{
                                                      completionBlock((ASDKModelFilter *)parsedObject, nil);
                                                  });
                                              }
                                          }];
}

- (void)handleFailedFilterCreationResponseForOperation:(AFHTTPRequestOperation *)operation
                                           error:(NSError *)error
                             withCompletionBlock:(ASDKFilterModelCompletionBlock)completionBlock {
    ASDKLogError(@"Failed to create filter for request: %@ - %@.\nBody:%@.\nReason:%@",
                 operation.request.HTTPMethod,
                 operation.request.URL.absoluteString,
                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                 error.localizedDescription);
    
    dispatch_async(self.resultsQueue, ^{
        completionBlock(nil, error);
    });
}

@end
