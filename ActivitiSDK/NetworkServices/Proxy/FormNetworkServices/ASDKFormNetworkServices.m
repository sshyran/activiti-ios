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

#import "ASDKFormNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKFormFieldValueRequestRepresentation.h"
#import "ASDKNetworkServiceConstants.h"


#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKFormNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKFormNetworkServices


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
#pragma mark ASDKFormNetworkService Protocol

- (void)startFormForProcessDefinitionID:(NSString *)processDefinitionID
                        completionBlock:(ASDKFormModelsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processDefinitionID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory startFormServicePathFormat], processDefinitionID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  [strongSelf handleSuccessfulFormModelsResponseForOperation:operation
                                                                              responseObject:responseObject
                                                                         withCompletionBlock:completionBlock];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to start form for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)completeFormForTaskID:(NSString *)taskID
withFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation
              completionBlock:(ASDKFormCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(formFieldValuesRepresentation);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory taskFormServicePathFormat], taskID]
                           parameters:[formFieldValuesRepresentation jsonDictionary]
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                      ASDKLogVerbose(@"Form completed with success for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                           encoding:NSUTF8StringEncoding],
                                                     responseDictionary);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(YES, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"Failed to complete form for request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(NO, nil);
                                      });
                                  }
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to complete form for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(NO, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)completeFormForProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
  withFormFieldValuesRequestrepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation
                           completionBlock:(ASDKStarFormCompletionBlock)completionBlock {
    NSParameterAssert(processDefinition );
    NSParameterAssert(formFieldValuesRepresentation);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    // Add the process definition ID to the list of passed parameters
    NSMutableDictionary *requestParameters = [NSMutableDictionary dictionaryWithDictionary: [formFieldValuesRepresentation jsonDictionary]];
    [requestParameters setObject:processDefinition.modelID
                          forKey:kASDKAPIProcessDefinitionIDParameter];
    [requestParameters setObject:processDefinition.name
                          forKey:kASDKAPIGenericNameParameter];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory startFormCompletionPath]
                            parameters:requestParameters
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Form completed successfully for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                  operation.request.HTTPMethod,
                                                  operation.request.URL.absoluteString,
                                                  [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                        encoding:NSUTF8StringEncoding],
                                                  responseDictionary);
                                   // Parse response data
                                   [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                      ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceDetails)
                                                                         withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                             if (error) {
                                                                                 ASDKLogError(@"Error parsing form field content. Description:%@", error.localizedDescription);
                                                                                 
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
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to complete form for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                      encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)saveFormForTaskID:(NSString *)taskID
withFormFieldValuesRequestrepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValuesRepresentation
          completionBlock:(ASDKFormSaveBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(formFieldValuesRepresentation);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[NSString stringWithFormat:[self.servicePathFactory saveFormServicePathFormat], taskID]
                            parameters:[formFieldValuesRepresentation jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   // Check status code
                                   if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                       NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                       ASDKLogVerbose(@"Form was successfully saved with request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                      operation.request.HTTPMethod,
                                                      operation.request.URL.absoluteString,
                                                      [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                            encoding:NSUTF8StringEncoding],
                                                      responseDictionary);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(YES, nil);
                                       });
                                   } else {
                                       ASDKLogVerbose(@"Failed to save form for request: %@ - %@.\nResponse:%@",
                                                      operation.request.HTTPMethod,
                                                      operation.request.URL.absoluteString,
                                                      [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(NO, nil);
                                       });
                                   }
                                   
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   ASDKLogError(@"Failed to save form for request: %@ - %@.\nBody:%@.\nReason:%@",
                                                operation.request.HTTPMethod,
                                                operation.request.URL.absoluteString,
                                                [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                      encoding:NSUTF8StringEncoding],
                                                error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(NO, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchFormForTaskWithID:(NSString *)taskID
               completionBlock:(ASDKFormModelsCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskFormServicePathFormat], taskID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  [strongSelf handleSuccessfulFormModelsResponseForOperation:operation
                                                                              responseObject:responseObject
                                                                         withCompletionBlock:completionBlock];
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch form for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)uploadContentWithModel:(ASDKModelFileContent *)file
                   contentData:(NSData *)contentData
                 progressBlock:(ASDKFormContentProgressBlock)progressBlock
               completionBlock:(ASDKFormContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(file);
    NSParameterAssert(contentData);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory contentFieldUploadServicePath]
                            parameters:nil
             constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                 NSError *error = nil;
                 
                 [formData appendPartWithFileData:contentData
                                             name:kASDKAPIContentUploadMultipartParameter
                                         fileName:file.fileName
                                         mimeType:file.mimeType];
                 
                 if (error) {
                     ASDKLogError(@"An error occured while appending multipart form data from file %@.", file.modelFileURL);
                 }
             } success:^(AFHTTPRequestOperation *operation, id responseObject) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation reference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                 ASDKLogVerbose(@"Form field content succesfully uploaded for request: %@ - %@.\nBody:%@.\nResponse:%@",
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
                                                               ASDKLogError(@"Error parsing form field content. Description:%@", error.localizedDescription);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(nil, error);
                                                               });
                                                           } else {
                                                               ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                                               
                                                               dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                                                                   // Generate the file path
                                                                   if (![self.diskServices doesFileAlreadyExistsForContent:parsedObject]) {
                                                                       
                                                                       NSString *downloadPathForContent = [self.diskServices downloadPathForContent:parsedObject];
                                                                       
                                                                       NSError *error = nil;
                                                                       // Save it into file system
                                                                       BOOL isWritten = [contentData writeToFile:downloadPathForContent
                                                                                                         options:0
                                                                                                           error:&error];
                                                                       if (isWritten) {
                                                                           ASDKLogVerbose(@"Local storage is written");
                                                                       } else {
                                                                           ASDKLogError(@"Error while storing local storage %@", error);
                                                                       }
                                                                   }
                                                               });
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(parsedObject, nil);
                                                               });
                                                           }
                                                       }];
             } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 __strong typeof(self) strongSelf = weakSelf;
                 
                 // Remove operation reference
                 [strongSelf.networkOperations removeObject:operation];
                 
                 ASDKLogError(@"Failed to upload form field content for request: %@ - %@.\nBody:%@.\nReason:%@",
                              operation.request.HTTPMethod,
                              operation.request.URL.absoluteString,
                              [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                              error.localizedDescription);
                 
                 dispatch_async(strongSelf.resultsQueue, ^{
                     completionBlock(nil, error);
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
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)downloadContentWithModel:(ASDKModelContent *)content
     allowCachedResults:(BOOL)allowCachedResults
          progressBlock:(ASDKFormContentDownloadProgressBlock)progressBlock
        completionBlock:(ASDKFormContentDownloadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    NSString *downloadPathForContent = [self.diskServices downloadPathForContent:content];
    
    // If content already exists return the URL to it to the caller and the caller
    // explicitly mentioned cached results are expected return the existing data
    if (allowCachedResults && [self.diskServices doesFileAlreadyExistsForContent:content]) {
        ASDKLogVerbose(@"Didn't performed content request. Providing cached result for content with ID: %@", content.modelID);
        dispatch_async(self.resultsQueue, ^{
            NSURL *downloadURL = [NSURL fileURLWithPath:downloadPathForContent];
            completionBlock(content.modelID, downloadURL, YES, nil);
        });
        
        return;
    }
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeHTTP];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory taskContentDownloadServicePathFormat], content.modelID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  // Check status code
                                  if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                      ASDKLogVerbose(@"The form field content was successfully downloaded with request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          NSURL *downloadURL = [NSURL fileURLWithPath:downloadPathForContent];
                                          completionBlock(content.modelID, downloadURL, NO, nil);
                                      });
                                  } else {
                                      ASDKLogVerbose(@"The form field content failed to download with request: %@ - %@.\nResponse:%@",
                                                     operation.request.HTTPMethod,
                                                     operation.request.URL.absoluteString,
                                                     [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                      
                                      dispatch_async(strongSelf.resultsQueue, ^{
                                          completionBlock(content.modelID, nil, NO, nil);
                                      });
                                  }
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to download content for form field with request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, nil, NO, error);
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
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}


- (void)fetchRestFieldValuesForTaskWithID:(NSString *)taskID
                              withFieldID:(NSString *)fieldID
                          completionBlock:(ASDKFormRestFieldValuesCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(fieldID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory restFieldValuesServicePathFormat], taskID, fieldID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  
                                  ASDKLogVerbose(@"Fetch rest field values with success for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskFormParserContentTypeRestFieldValues)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing rest field values content. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKLogVerbose(@"Successfully parsed rest field values content:%@", parsedObject);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(parsedObject, nil);
                                                                                });
                                                                            }
                                                                        }];

                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch rest field values for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchRestFieldValuesForTaskWithID:(NSString *)taskID
                              withFieldID:(NSString *)fieldID
                             withColumnID:(NSString *)columnID
                          completionBlock:(ASDKFormRestFieldValuesCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(taskID);
    NSParameterAssert(fieldID);
    NSParameterAssert(columnID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory dynamicTableRestFieldValuesServicePathFormat], taskID, fieldID, columnID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  
                                  ASDKLogVerbose(@"Fetch rest field values with success for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskFormParserContentTypeRestFieldValues)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing rest field values content. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKLogVerbose(@"Successfully parsed rest field values content:%@", parsedObject);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(parsedObject, nil);
                                                                                });
                                                                            }
                                                                        }];
                                  
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch rest field values for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation refference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchRestFieldValuesForStartFormWithProcessDefinitionID:(NSString *)processDefinitionID
                                                    withFieldID:(NSString *)fieldID
                                                completionBlock:(ASDKStartFormRestFieldValuesCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processDefinitionID);
    NSParameterAssert(fieldID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory startFormRestFieldValuesServicePathFormat], processDefinitionID, fieldID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  
                                  ASDKLogVerbose(@"Fetch rest field values with success for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskFormParserContentTypeRestFieldValues)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing rest field values content. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKLogVerbose(@"Successfully parsed rest field values content:%@", parsedObject);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(parsedObject, nil);
                                                                                });
                                                                            }
                                                                        }];
                                  
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch rest field values for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
                                               error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchRestFieldValuesForStartFormWithProcessDefinitionID:(NSString *)processDefinitionID
                                                    withFieldID:(NSString *)fieldID
                                                   withColumnID:(NSString *)columnID
                                                completionBlock:(ASDKStartFormRestFieldValuesCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(processDefinitionID);
    NSParameterAssert(fieldID);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[NSString stringWithFormat:[self.servicePathFactory startFormDynamicTableRestFieldValuesServicePathFormat], processDefinitionID, fieldID, columnID]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  
                                  ASDKLogVerbose(@"Fetch rest field values with success for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                                 operation.request.HTTPMethod,
                                                 operation.request.URL.absoluteString,
                                                 [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                       encoding:NSUTF8StringEncoding],
                                                 responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKTaskFormParserContentTypeRestFieldValues)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing rest field values content. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKLogVerbose(@"Successfully parsed rest field values content:%@", parsedObject);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(parsedObject, nil);
                                                                                });
                                                                            }
                                                                        }];
                                  
                                  
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation refference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  ASDKLogError(@"Failed to fetch rest field values for request: %@ - %@.\nBody:%@.\nReason:%@",
                                               operation.request.HTTPMethod,
                                               operation.request.URL.absoluteString,
                                               [[NSString alloc] initWithData:operation.request.HTTPBody
                                                                     encoding:NSUTF8StringEncoding],
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

- (void)handleSuccessfulFormModelsResponseForOperation:(AFHTTPRequestOperation *)operation
                                        responseObject:(id)responseObject
                                   withCompletionBlock:(ASDKFormModelsCompletionBlock)completionBlock {
    NSDictionary *responseDictionary = (NSDictionary *)responseObject;
    ASDKLogVerbose(@"Form fetched with success for request:%@ - %@.\nBody:%@.\nResponse:%@",
                   operation.request.HTTPMethod,
                   operation.request.URL.absoluteString,
                   [[NSString alloc] initWithData:operation.request.HTTPBody
                                         encoding:NSUTF8StringEncoding],
                   responseDictionary);
    
    // Parse response data
    [self.parserOperationManager parseContentDictionary:responseDictionary
                                                 ofType:CREATE_STRING(ASDKTaskFormParserContentTypeFormModels)
                                    withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                        if (error) {
                                            ASDKLogError(@"Error parsing form description. Description:%@", error.localizedDescription);
                                            
                                            dispatch_async(self.resultsQueue, ^{
                                                completionBlock(nil, error);
                                            });
                                        } else {
                                            ASDKLogVerbose(@"Successfully parsed model object:%@", parsedObject);
                                            
                                            dispatch_async(self.resultsQueue, ^{
                                                completionBlock(parsedObject, nil);
                                            });
                                        }
                                    }];
}

@end
