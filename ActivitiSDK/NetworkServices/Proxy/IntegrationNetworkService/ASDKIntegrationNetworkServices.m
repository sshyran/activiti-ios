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

#import "ASDKIntegrationNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKNetworkServiceConstants.h"
#import "ASDKIntegrationNodeContentRequestRepresentation.h"
#import "ASDKModelContent.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKIntegrationNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKIntegrationNetworkServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.networkOperations = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchIntegrationAccountsWithCompletionBlock:(ASDKIntegrationAccountListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory integrationAccountsServicePath]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Integration accounts list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                               ofType:CREATE_STRING(ASDKIntegrationParserContentTypeAccountList)
                                                                  withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                      if (error) {
                                                                          ASDKLogError(@"Error parsing integration account list. Description:%@", error.localizedDescription);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(nil, error, nil);
                                                                          });
                                                                      } else {
                                                                          NSArray *integrationAccountsList = (NSArray *)parsedObject;
                                                                          ASDKLogVerbose(@"Successfully parsed model object:%@", integrationAccountsList);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(integrationAccountsList, nil, paging);
                                                                          });
                                                                      }
                                                                  }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch integration accounts list for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(self.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchIntegrationNetworksForSourceID:(NSString *)sourceID
                            completionBlock:(ASDKIntegrationNetworkListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(sourceID);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory integrationNetworksServicePathFormat], sourceID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Integration network list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                               ofType:CREATE_STRING(ASDKIntegrationParserContentTypeNetworkList)
                                                                  withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                      if (error) {
                                                                          ASDKLogError(@"Error parsing integration network list. Description:%@", error.localizedDescription);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(nil, error, nil);
                                                                          });
                                                                      } else {
                                                                          NSArray *integrationAccountsList = (NSArray *)parsedObject;
                                                                          ASDKLogVerbose(@"Successfully parsed model object:%@", integrationAccountsList);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(integrationAccountsList, nil, paging);
                                                                          });
                                                                      }
                                                                  }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch integration network list for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(self.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchIntegrationSitesForSourceID:(NSString *)sourceID
                               networkID:(NSString *)networkID
                         completionBlock:(ASDKIntegrationSiteListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(sourceID);
    NSParameterAssert(networkID);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory integrationSitesServicePathFormat],sourceID, networkID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Integration site list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                               ofType:CREATE_STRING(ASDKIntegrationParserContentTypeSiteList)
                                                                  withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                      if (error) {
                                                                          ASDKLogError(@"Error parsing integration site list. Description:%@", error.localizedDescription);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(nil, error, nil);
                                                                          });
                                                                      } else {
                                                                          NSArray *integrationAccountsList = (NSArray *)parsedObject;
                                                                          ASDKLogVerbose(@"Successfully parsed model object:%@", integrationAccountsList);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(integrationAccountsList, nil, paging);
                                                                          });
                                                                      }
                                                                  }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch integration site list for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(self.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchIntegrationContentForSourceID:(NSString *)sourceID
                                 networkID:(NSString *)networkID
                                    siteID:(NSString *)siteID
                           completionBlock:(ASDKIntegrationContentListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(sourceID);
    NSParameterAssert(networkID);
    NSParameterAssert(siteID);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory integrationSiteContentServicePathFormat], sourceID, networkID, siteID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Integration site content fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                               ofType:CREATE_STRING(ASDKIntegrationParserContentTypeSiteContentList)
                                                                  withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                      if (error) {
                                                                          ASDKLogError(@"Error parsing integration site content. Description:%@", error.localizedDescription);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(nil, error, nil);
                                                                          });
                                                                      } else {
                                                                          NSArray *integrationAccountsList = (NSArray *)parsedObject;
                                                                          ASDKLogVerbose(@"Successfully parsed model object:%@", integrationAccountsList);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(integrationAccountsList, nil, paging);
                                                                          });
                                                                      }
                                                                  }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch integration site content for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(self.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchIntegrationFolderContentForSourceID:(NSString *)sourceID
                                       networkID:(NSString *)networkID
                                        folderID:(NSString *)folderID
                                 completionBlock:(ASDKIntegrationContentListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(sourceID);
    NSParameterAssert(networkID);
    NSParameterAssert(folderID);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory integrationFolderContentServicePathFormat], sourceID, networkID, folderID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Integration folder content fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                               ofType:CREATE_STRING(ASDKIntegrationParserContentTypeFolderContentList)
                                                                  withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                      if (error) {
                                                                          ASDKLogError(@"Error parsing integration folder content. Description:%@", error.localizedDescription);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(nil, error, nil);
                                                                          });
                                                                      } else {
                                                                          NSArray *integrationAccountsList = (NSArray *)parsedObject;
                                                                          ASDKLogVerbose(@"Successfully parsed model object:%@", integrationAccountsList);
                                                                          
                                                                          dispatch_async(self.resultsQueue, ^{
                                                                              completionBlock(integrationAccountsList, nil, paging);
                                                                          });
                                                                      }
                                                                  }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch integration folder content for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(self.resultsQueue, ^{
                                      completionBlock(nil, error, nil);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)uploadIntegrationContentWithRepresentation:(ASDKIntegrationNodeContentRequestRepresentation *)nodeContentRepresentation
                                   completionBlock:(ASDKIntegrationContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(nodeContentRepresentation);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory integrationContentUploadServicePath]
                            parameters:[nodeContentRepresentation jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Integration content uploaded successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                                ofType:CREATE_STRING(ASDKIntegrationParserContentTypeUploadedContent)
                                                                   withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                       if (error) {
                                                                           ASDKLogError(@"Error parsing integration content. Description:%@", error.localizedDescription);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(nil, error);
                                                                           });
                                                                       } else {
                                                                           ASDKModelContent *content = (ASDKModelContent *)parsedObject;
                                                                           ASDKLogVerbose(@"Successfully parsed model object:%@", content);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(content, nil);
                                                                           });
                                                                       }
                                                                   }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to upload integration content for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(self.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)uploadIntegrationContentForTaskID:(NSString *)taskID
                       withRepresentation:(ASDKIntegrationNodeContentRequestRepresentation *)nodeContentRepresentation
                          completionBlock:(ASDKIntegrationContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(nodeContentRepresentation);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory integrationContentUploadForTaskServicePathFormat], taskID]
                            parameters:[nodeContentRepresentation jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Task integration content uploaded successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   
                                   // Parse response data
                                   [self.parserOperationManager parseContentDictionary:responseDictionary
                                                                                ofType:CREATE_STRING(ASDKIntegrationParserContentTypeUploadedContent)
                                                                   withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                       if (error) {
                                                                           ASDKLogError(@"Error parsing task integration content. Description:%@", error.localizedDescription);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(nil, error);
                                                                           });
                                                                       } else {
                                                                           ASDKModelContent *content = (ASDKModelContent *)parsedObject;
                                                                           ASDKLogVerbose(@"Successfully parsed model object:%@", content);
                                                                           
                                                                           dispatch_async(self.resultsQueue, ^{
                                                                               completionBlock(content, nil);
                                                                           });
                                                                       }
                                                                   }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to upload task integration content for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(self.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}


- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}

@end
