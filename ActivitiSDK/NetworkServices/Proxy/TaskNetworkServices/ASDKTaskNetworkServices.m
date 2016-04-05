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

#import "ASDKTaskNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKTaskRequestRepresentation.h"
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKTaskUpdateRequestRepresentation.h"
#import "ASDKTaskCreationRequestRepresentation.h"
#import "ASDKModelPaging.h"
#import "ASDKModelFileContent.h"
#import "ASDKNetworkServiceConstants.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKTaskNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKTaskNetworkServices


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
#pragma mark ASDKTaskNetworkService Protocol

- (void)fetchTaskListWithTaskRepresentationFilter:(ASDKTaskRequestRepresentation *)filter
                                  completionBlock:(ASDKTaskListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory taskListServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleSuccessfulTaskListResponseForOperation:operation
                                                                             responseObject:responseObject
                                                                        withCompletionBlock:completionBlock];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleFailedTaskListResponseForOperation:operation
                                                                                  error:error
                                                                    withCompletionBlock:completionBlock];
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchTaskListWithFilterRepresentation:(ASDKFilterRequestRepresentation *)filter
                              completionBlock:(ASDKTaskListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory taskListFromFilterServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleSuccessfulTaskListResponseForOperation:operation
                                                                             responseObject:responseObject
                                                                        withCompletionBlock:completionBlock];
                                   
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   [strongSelf handleFailedTaskListResponseForOperation:operation
                                                                                  error:error
                                                                    withCompletionBlock:completionBlock];
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchTaskDetailsForTaskID:(NSString *)taskID
                  completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskDetailsServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Task details fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskDetails)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing task details. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKModelTask *task = (ASDKModelTask *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", task);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(task, nil);
                                                                                });
                                                                            }
                                                                        }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch task details for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)fetchTaskContentForTaskID:(NSString *)taskID
                  completionBlock:(ASDKTaskContentCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskContentServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Task content fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeContent)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing task content. Description:%@", error.localizedDescription);
                                                                                
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
                                  
                                  ASDKLogError(@"Failed to fetch task content for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)fetchTaskCommentsForTaskID:(NSString *)taskID
                   completionBlock:(ASDKTaskCommentsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskCommentServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Task comments fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeComments)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing task comments. Description:%@", error.localizedDescription);
                                                                                
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
                                  
                                  ASDKLogError(@"Failed to fetch task comments for request: %@ - %@.\nBody:%@.\nReason:%@",
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
            forTaskID:(NSString *)taskID
      completionBlock:(ASDKTaskCreateCommentCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(comment);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory taskCommentServicePathFormat], taskID]
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
                                                                                     ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeComment)
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
                                  
                                  ASDKLogError(@"Failed to create task comment for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)updateTaskForTaskID:(NSString *)taskID
     withTaskRepresentation:(ASDKTaskUpdateRequestRepresentation *)taskRepresentation
            completionBlock:(ASDKTaskUpdateCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskDetailsServicePathFormat], taskID]
                           parameters:[taskRepresentation jsonDictionary]
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The task details were updated successfully for request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The task details failed to update successfully for request: %@ - %@.\nResponse:%@",
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
                                  
                                  ASDKLogError(@"Failed to update task details for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)completeTaskForTaskID:(NSString *)taskID
              completionBlock:(ASDKTaskCompleteCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskActionCompleteServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The task was marked as completed successfully for request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The task failed to be marked as completed for request: %@ - %@.\nResponse:%@",
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
                                  
                                  ASDKLogError(@"Failed to mark task as completed for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                     forTaskID:(NSString *)taskID
                 progressBlock:(ASDKTaskContentProgressBlock)progressBlock
               completionBlock:(ASDKTaskContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(file);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory taskContentUploadServicePathFormat], taskID]
                            parameters:@{kASDKAPIParamIsRelatedContent : @(YES)}
             constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                 NSError *error = nil;
                 [formData appendPartWithFileURL:file.fileURL
                                            name:kASDKAPIContentUploadMultipartParameter
                                        fileName:file.fileName
                                        mimeType:file.mimeType
                                           error:&error];
                 
                 if (error) {
                     ASDKLogError(@"An error occured while appending multipart form data from file %@.", file.fileURL);
                 }
             } success:^(AFHTTPRequestOperation *operation, id responseObject) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation refference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                 ASDKLogVerbose(@"Task content succesfully uploaded for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                operation.request.HTTPMethod,
                                operation.request.URL.absoluteString,
                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                responseDictionary);
                 
                 // Parse response data
                 [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                    ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeContent)
                                                       withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                           if (error) {
                                                               ASDKLogError(@"Error parsing task content. Description:%@", error.localizedDescription);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(NO, error);
                                                               });
                                                           } else {
                                                               ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(((ASDKModelContent *)parsedObject).isContentAvailable, nil);
                                                               });
                                                           }
                                                       }];
             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation refference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 ASDKLogError(@"Failed to upload task content for request:%@ - %@.\nBody:%@.\nReason:%@",
                              operation.request.HTTPMethod,
                              operation.request.URL.absoluteString,
                              [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                              error.localizedDescription);
                 
                 dispatch_async(strongSelf.resultsQueue, ^{
                     completionBlock(NO, error);
                 });
             }];
    
    // If a progress block is provided report transfer progress information
    if (progressBlock) {
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            NSUInteger uploadProgress = (NSUInteger)(totalBytesWritten * 100 / totalBytesExpectedToWrite);
            
            dispatch_async(self.resultsQueue, ^{
                progressBlock(uploadProgress, nil);
            });
        }];
    }
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                   contentData:(NSData *)contentData
                     forTaskID:(NSString *)taskID
                 progressBlock:(ASDKTaskContentProgressBlock)progressBlock
               completionBlock:(ASDKTaskContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(file);
    NSParameterAssert(contentData);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory taskContentUploadServicePathFormat], taskID]
                            parameters:@{kASDKAPIParamIsRelatedContent : @(YES)}
             constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                 NSError *error = nil;
                 
                 [formData appendPartWithFileData:contentData
                                             name:kASDKAPIContentUploadMultipartParameter
                                         fileName:file.fileName
                                         mimeType:file.mimeType];
                 
                 if (error) {
                     ASDKLogError(@"An error occured while appending multipart form data from file %@.", file.fileURL);
                 }
             } success:^(AFHTTPRequestOperation *operation, id responseObject) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation refference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                 ASDKLogVerbose(@"Task content succesfully uploaded for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                operation.request.HTTPMethod,
                                operation.request.URL.absoluteString,
                                [[NSString alloc] initWithData:operation.request.HTTPBody
                                                      encoding:NSUTF8StringEncoding],
                                responseDictionary);
                 
                 // Parse response data
                 [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                    ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeContent)
                                                       withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                           if (error) {
                                                               ASDKLogError(@"Error parsing task content. Description:%@", error.localizedDescription);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(NO, error);
                                                               });
                                                           } else {
                                                               ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(((ASDKModelContent *)parsedObject).isContentAvailable, nil);
                                                               });
                                                           }
                                                       }];
             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation refference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 ASDKLogError(@"Failed to upload task content for request: %@ - %@.\nBody:%@.\nReason:%@",
                              operation.request.HTTPMethod,
                              operation.request.URL.absoluteString,
                              [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                              error.localizedDescription);
                 
                 dispatch_async(strongSelf.resultsQueue, ^{
                     completionBlock(NO, error);
                 });
             }];
    
    // If a progress block is provided report transfer progress information
    if (progressBlock) {
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            __strong typeof(self) strongSelf = weakSelf;
            
            NSUInteger uploadProgress = (NSUInteger) (totalBytesWritten * 100 / totalBytesExpectedToWrite);
            
            dispatch_async(strongSelf.resultsQueue, ^{
                progressBlock(uploadProgress, nil);
            });
        }];
    }
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)deleteContent:(ASDKModelContent *)content
      completionBlock:(ASDKTaskContentDeletionCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager DELETE:[NSString stringWithFormat:[self.servicePathFactory contentServicePathFormat], content.instanceID]
                              parameters:nil
                                 success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                     __strong typeof(self) strongSelf = weakSelf;
                                     
                                     // Remove operation refference
                                     [strongSelf.networkOperations removeObject:operation];
                                     
                                     // Check status code
                                     if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                         ASDKLogVerbose(@"The task content was successfully deleted with request: %@ - %@.\nResponse:%@",
                                                        operation.request.HTTPMethod,
                                                        operation.request.URL.absoluteString,
                                                        [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                         
                                         dispatch_async(strongSelf.resultsQueue, ^{
                                             completionBlock(YES, nil);
                                         });
                                     } else {
                                         ASDKLogVerbose(@"The task content failed to have been deleted with request: %@ - %@.\nResponse:%@",
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
                                     
                                     ASDKLogError(@"Failed to delete content for task with request: %@ - %@.\nBody:%@.\nReason:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                  error.localizedDescription);
                                     
                                     dispatch_async(self.resultsQueue, ^{
                                         completionBlock(NO, error);
                                     });
                                 }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)downloadContent:(ASDKModelContent *)content
     allowCachedResults:(BOOL)allowCachedResults
          progressBlock:(ASDKTaskContentDownloadProgressBlock)progressBlock
        completionBlock:(ASDKTaskContentDownloadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    NSString *downloadPathForContent = [self.diskServices downloadPathForContent:content];
    
    // If content already exists return the URL to it to the caller and the caller
    // explicitly mentioned cached results are expected return the existing data
    if (allowCachedResults && [self.diskServices doesFileAlreadyExistsForContent:content]) {
        ASDKLogVerbose(@"Didn't performed content request. Providing cached result for content with ID: %@", content.instanceID);
        dispatch_async(self.resultsQueue, ^{
            NSURL *downloadURL = [NSURL fileURLWithPath:downloadPathForContent];
            completionBlock(downloadURL, YES, nil);
        });
        
        return;
    }
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeHTTP];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskContentDownloadServicePathFormat], content.instanceID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The task content was successfully downloaded with request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          NSURL *downloadURL = [NSURL fileURLWithPath:downloadPathForContent];
                                          completionBlock(downloadURL, NO, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The task content failed to download with request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(nil, NO, nil);
                                      });
                                  }
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to download content for task with request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, NO, error);
                                  });
                              }];
    
    // Set the output file stream
    // NOTE: output stream size checks are taken care of by AFNetworking which will call the failure block of the
    // request operation
    operation.outputStream = [NSOutputStream outputStreamWithURL:[NSURL fileURLWithPath:downloadPathForContent]
                                                          append:NO];
    [operation.outputStream open];
    
    // If a progress block is provided report transfer progress information
    if (progressBlock) {
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            __strong typeof(self) strongSelf = weakSelf;
            
            dispatch_async(strongSelf.resultsQueue, ^{
                progressBlock([weakSelf.diskServices sizeStringForByteCount:totalBytesRead] , nil);
            });
        }];
    }
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)involveUser:(ASDKModelUser *)user
          forTaskID:(NSString *)taskID
    completionBlock:(ASDKTaskUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(user);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskUserInvolveServicePathFormat], taskID]
                           parameters:@{kASDKAPIUserIdParameter : user.userID}
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The user was successfully involved for request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The user involvement failed for request: %@ - %@.\nResponse:%@",
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
                                  
                                  ASDKLogError(@"Failed to involve user for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)removeInvolvedUser:(ASDKModelUser *)user
                 forTaskID:(NSString *)taskID
           completionBlock:(ASDKTaskUserInvolvementCompletionBlock)completionBlock {
    NSParameterAssert(user);
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskUserRemoveInvolvedServicePathFormat], taskID]
                           parameters:@{kASDKAPIUserIdParameter : user.userID}
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The user's involvement was successfully removed for request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The user's involvement removal failed for request: %@ - %@.\nResponse:%@",
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
                                  
                                  ASDKLogError(@"Failed to remove involvement user for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)createTaskWithRepresentation:(ASDKTaskCreationRequestRepresentation *)taskRepresentation
                     completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskRepresentation);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager
     POST:[self.servicePathFactory taskCreationServicePath]
     parameters:[taskRepresentation jsonDictionary]
     success:^(AFHTTPRequestOperation *operation, id responseObject) {
         __strong typeof(self) strongSelf = weakSelf;
         
         // Remove operation refference
         [strongSelf.networkOperations removeObject:operation];
         
         NSDictionary *responseDictionary = (NSDictionary *)responseObject;
         ASDKLogVerbose(@"Task created successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                        operation.request.HTTPMethod,
                        operation.request.URL.absoluteString,
                        [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                        responseDictionary);
         
         // Parse response data
         [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                            ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskDetails)
                                               withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                   if (error) {
                                                       ASDKLogError(@"Error parsing task details. Description:%@", error.localizedDescription);
                                                       
                                                       dispatch_async(weakSelf.resultsQueue, ^{
                                                           completionBlock(nil, error);
                                                       });
                                                   } else {
                                                       ASDKModelTask *task = (ASDKModelTask *)parsedObject;
                                                       ASDKLogVerbose(@"Successfully parsed model object:%@", task);
                                                       
                                                       dispatch_async(weakSelf.resultsQueue, ^{
                                                           completionBlock(task, nil);
                                                       });
                                                   }
                                               }];
     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         __strong typeof(self) strongSelf = weakSelf;
         
         // Remove operation refference
         [strongSelf.networkOperations removeObject:operation];
         
         ASDKLogError(@"Failed to create task for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)claimTaskWithID:(NSString *)taskID
        completionBlock:(ASDKTaskClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskClaimServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The task has been successfully claimed with request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The task cannot be claimed with request: %@ - %@.\nResponse:%@",
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
                                  
                                  ASDKLogError(@"Failed to claim task with request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)unclaimTaskWithID:(NSString *)taskID
          completionBlock:(ASDKTaskClaimCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskUnclaimServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   // Check status code
                                   if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                       ASDKLogVerbose(@"The task has been successfully unclaimed with request: %@ - %@.\nResponse:%@",
                                                      operation.request.HTTPMethod,
                                                      operation.request.URL.absoluteString,
                                                      [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(NO, nil);
                                       });
                                   } else {
                                       ASDKLogVerbose(@"The task cannot be unclaimed with request: %@ - %@.\nResponse:%@",
                                                      operation.request.HTTPMethod,
                                                      operation.request.URL.absoluteString,
                                                      [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(YES, nil);
                                       });
                                   }
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation refference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to unclaim task with request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(YES, error);
                                   });
                               }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)assignTaskWithID:(NSString *)taskID
                  toUser:(ASDKModelUser *)user
         completionBlock:(ASDKTaskDetailsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(user);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager PUT:[NSString stringWithFormat:[self.servicePathFactory taskAssignServicePathFormat], taskID]
                           parameters:@{kASDKAPIAssigneeParameter: user.userID}
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Task assigned successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskDetails)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing task details. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKModelTask *task = (ASDKModelTask *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", task);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(task, nil);
                                                                                });
                                                                            }
                                                                        }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to assign task for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}


#pragma mark -
#pragma mark Private interface

- (void)handleSuccessfulTaskListResponseForOperation:(AFHTTPRequestOperation *)operation
                                      responseObject:(id)responseObject
                                 withCompletionBlock:(ASDKTaskListCompletionBlock)completionBlock {
    NSDictionary *responseDictionary = (NSDictionary *)responseObject;
    ASDKLogVerbose(@"Task list fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                   operation.request.HTTPMethod,
                   operation.request.URL.absoluteString,
                   [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                   responseDictionary);
    
    // Parse response data
    [self.parserOperationManager parseContentDictionary:responseDictionary
                                                 ofType:CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskList)
                                    withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                        if (error) {
                                            ASDKLogError(@"Error parsing task list. Description:%@", error.localizedDescription);
                                            
                                            dispatch_async(self.resultsQueue, ^{
                                                completionBlock(nil, error, nil);
                                            });
                                        } else {
                                            NSArray *taskList = (NSArray *)parsedObject;
                                            ASDKLogVerbose(@"Successfully parsed model object:%@", taskList);
                                            
                                            dispatch_async(self.resultsQueue, ^{
                                                completionBlock(taskList, nil, paging);
                                            });
                                        }
                                    }];
}

- (void)handleFailedTaskListResponseForOperation:(AFHTTPRequestOperation *)operation
                                           error:(NSError *)error
                             withCompletionBlock:(ASDKTaskListCompletionBlock)completionBlock {
    ASDKLogError(@"Failed to fetch task list for request: %@ - %@.\nBody:%@.\nReason:%@",
                 operation.request.HTTPMethod,
                 operation.request.URL.absoluteString,
                 [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                 error.localizedDescription);
    
    dispatch_async(self.resultsQueue, ^{
        completionBlock(nil, error, nil);
    });
}


@end
