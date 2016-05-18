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

- (void)fetchIntegrationNetworksWithCompletionBlock:(ASDKIntegrationNetworkListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory integrationNetworksServicePath]
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

- (void)fetchIntegrationSitesForNetworkID:(NSString *)networkID
                          completionBlock:(ASDKIntegrationSiteListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(completionBlock);
    NSCParameterAssert(networkID);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory integrationSitesServicePathFormat], networkID]
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


- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}

@end
