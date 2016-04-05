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

#import "ASDKProcessInstanceNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKStartProcessRequestRepresentation.h"
#import "ASDKNetworkServiceConstants.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKProcessInstanceNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKProcessInstanceNetworkServices

#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.networkOperations = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchProcessInstanceListWithFilterRepresentation:(ASDKFilterRequestRepresentation *)filter
                                         completionBlock:(ASDKProcessInstanceListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory processInstancesListServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Process instance list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                                ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceList)
                                                                   withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                       if (error) {
                                                                           ASDKLogError(@"Error parsing process instance list. Description:%@", error.localizedDescription);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(nil, error, nil);
                                                                           });
                                                                       } else {
                                                                           NSArray *processInstanceList = (NSArray *)parsedObject;
                                                                           ASDKLogVerbose(@"Successfully parsed model object:%@", processInstanceList);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(processInstanceList, nil, paging);
                                                                           });
                                                                       }
                                                                   }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to fetch process instance list for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(self.resultsQueue, ^{
                                       completionBlock(nil, error, nil);
                                   });
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)startProcessInstanceWithStartProcessRequestRepresentation:(ASDKStartProcessRequestRepresentation *)request
                                                  completionBlock:(ASDKProcessInstanceCompletionBlock)completionBlock {
    
    // Check mandatory properties
    NSParameterAssert(request);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.requestSerializer = [self requestSerializerOfType:ASDKNetworkServiceRequestSerializerTypeJSON];
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory startProcessInstanceServicePath]
                            parameters:[request jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Reinstate the authentication request serializer
                                   strongSelf.requestOperationManager.requestSerializer = strongSelf.requestOperationManager.authenticationProvider;

                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Process instance started successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                                ofType:CREATE_STRING(ASDKProcessParserContentTypeStartProcessInstance)
                                                                   withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                       if (error) {
                                                                           ASDKLogError(@"Error parsing process instance. Description:%@", error.localizedDescription);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(nil, error);
                                                                           });
                                                                       } else {
                                                                           ASDKModelProcessInstance *startedProcessInstance = (ASDKModelProcessInstance *)parsedObject;
                                                                           ASDKLogVerbose(@"Successfully parsed model object:%@", startedProcessInstance);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(startedProcessInstance, nil);
                                                                           });
                                                                       }
                                                                   }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Reinstate the authentication request serializer
                                   strongSelf.requestOperationManager.requestSerializer = strongSelf.requestOperationManager.authenticationProvider;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to start process instance for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(self.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchProcessInstanceDetailsForID:(NSString *)processInstanceID
                         completionBlock:(ASDKProcessInstanceCompletionBlock)completionBlock {
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory processInstanceDetailsServicePathFormat], processInstanceID]
                            parameters:nil
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Process instance details fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                                ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceDetails)
                                                                   withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                       if (error) {
                                                                           ASDKLogError(@"Error parsing model. Description:%@", error.localizedDescription);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(nil, error);
                                                                           });
                                                                       } else {
                                                                           ASDKModelProcessInstance *processInstanceDetails = (ASDKModelProcessInstance *)parsedObject;
                                                                           ASDKLogVerbose(@"Successfully parsed model object:%@", processInstanceDetails);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(processInstanceDetails, nil);
                                                                           });
                                                                       }
                                                                   }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to fetch process instance details for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(self.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchProcesInstanceContentForProcessInstanceID:(NSString *)processInstanceID
                                       completionBlock:(ASDKProcessInstanceContentCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory processInstanceContentServicePathFormat], processInstanceID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Process instance content fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceContent)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing model. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                NSArray *contentList = (NSArray *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", contentList);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(contentList, nil);
                                                                                });
                                                                            }
                                                                        }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch process instance content for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchProcessInstanceCommentsForProcessInstanceID:(NSString *)processInstanceID
                                         completionBlock:(ASDKProcessInstanceCommentsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory processInstanceCommentServicePathFormat], processInstanceID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Process instance comments fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComments)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing process instance comments. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error, nil);
                                                                                });
                                                                            } else {
                                                                                NSArray *commentList = (NSArray *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", commentList);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(commentList, nil, paging);
                                                                                });
                                                                            }
                                                                        }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch process instance comments for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)createComment:(NSString *)comment
 forProcessInstanceID:(NSString *)processInstanceID
      completionBlock:(ASDKProcessInstanceCreateCommentCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(comment);
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory processInstanceCommentServicePathFormat], processInstanceID]
                            parameters:@{kASDKAPIMessageParameter : comment}
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Comment created successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                      ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComment)
                                                                         withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                             if (error) {
                                                                                 ASDKLogError(@"Error parsing task. Description:%@", error.localizedDescription);
                                                                                 
                                                                                 dispatch_async(weakSelf.resultsQueue, ^{
                                                                                     completionBlock(nil, error);
                                                                                 });
                                                                             } else {
                                                                                 ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                                                 
                                                                                 dispatch_async(weakSelf.resultsQueue, ^{
                                                                                     completionBlock(parsedObject, nil);
                                                                                 });
                                                                             }
                                                                         }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to create process instance comment for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)deleteProcessInstanceWithID:(NSString *)processInstanceID
                    completionBlock:(ASDKProcessInstanceDeleteCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processInstanceID);
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager DELETE:[NSString stringWithFormat:[self.servicePathFactory processInstanceDetailsServicePathFormat], processInstanceID]
                              parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     __strong typeof(self) strongSelf = weakSelf;
                                     
                                     // Remove operation refference
                                     [strongSelf.networkOperations removeObject:operation];
                                     
                                     // Check status code
                                     if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                         ASDKLogVerbose(@"The process instance was deleted successfully for request: %@ - %@.\nResponse:%@",
                                                        operation.request.HTTPMethod,
                                                        operation.request.URL.absoluteString,
                                                        [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                         
                                         dispatch_async(strongSelf.resultsQueue, ^{
                                             completionBlock(YES, nil);
                                         });
                                     } else {
                                         ASDKLogVerbose(@"Failed to delete process instance for request: %@ - %@.\nResponse:%@",
                                                        operation.request.HTTPMethod,
                                                        operation.request.URL.absoluteString,
                                                        [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                         
                                         dispatch_async(strongSelf.resultsQueue, ^{
                                             completionBlock(NO, nil);
                                         });
                                     }
                                 } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                     __strong typeof(self) strongSelf = weakSelf;
                                     
                                     // Remove operation refference
                                     [strongSelf.networkOperations removeObject:operation];
                                     
                                     ASDKLogError(@"Failed to delete process instance for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  error.localizedDescription);
                                     
                                     dispatch_async(strongSelf.resultsQueue, ^{
                                         completionBlock(NO, error);
                                     });
                                 }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}

@end