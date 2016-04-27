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

#import "ASDKUserNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKUserRequestRepresentation.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKUserNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKUserNetworkServices

#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.networkOperations = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchUsersWithUserRequestRepresentation:(ASDKUserRequestRepresentation *)userRequest
                                completionBlock:(ASDKUsersCompletionBlock)completionBlock {
    
    // Check mandatory properties
    NSParameterAssert(userRequest);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory userListServicePath]
                           parameters:[userRequest jsonDictionary]
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
          __strong typeof(self) strongSelf = weakSelf;
          
          // Remove operation reference
          [strongSelf.networkOperations removeObject:operation];
          
          NSDictionary *responseDictionary = (NSDictionary *)responseObject;
          ASDKLogVerbose(@"Users fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                         operation.request.HTTPMethod,
                         operation.request.URL.absoluteString,
                         [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                         responseDictionary);
          
          // Parse response data
          [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                             ofType:CREATE_STRING(ASDKUserParserContentTypeUserList)
                                                withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                    if (error) {
                                                        ASDKLogError(@"Error parsing user content. Description:%@", error.localizedDescription);
                                                        
                                                        dispatch_async(weakSelf.resultsQueue, ^{
                                                            completionBlock(nil, error, paging);
                                                        });
                                                    } else {
                                                        ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                        
                                                        dispatch_async(weakSelf.resultsQueue, ^{
                                                            completionBlock(parsedObject, nil, paging);
                                                        });
                                                    }
                                                }];
          
      } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
          __strong typeof(self) strongSelf = weakSelf;
          
          // Remove operation reference
          [strongSelf.networkOperations removeObject:operation];
          
          ASDKLogError(@"Failed to fetch users list for request: %@ - %@.\nBody:%@.\nReason:%@",
                       operation.request.HTTPMethod,
                       operation.request.URL.absoluteString,
                       [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                       error.localizedDescription);
          
          dispatch_async(strongSelf.resultsQueue, ^{
              completionBlock(nil, error, nil);
          });
      }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchPictureForUserID:(NSString *)userID
              completionBlock:(ASDKUsersPictureCompletionBlock)completionBlock {
    // Check mandatory data
    NSParameterAssert(userID);
    NSParameterAssert(completionBlock);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeImage];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory userProfileImageServicePathFormat], userID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSParameterAssert(strongSelf.resultsQueue);
                                  
                                  UIImage *profileImage = (UIImage *)responseObject;
                                  ASDKLogVerbose(@"Profile picture fetched successfully for request: %@ - %@.", operation.request.HTTPMethod, operation.request.URL.absoluteString);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(profileImage, nil);
                                  });
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSParameterAssert(strongSelf.resultsQueue);
                                  
                                  ASDKLogError(@"Failed to fetch profile picture for request:%@ - %@. Reason:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
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