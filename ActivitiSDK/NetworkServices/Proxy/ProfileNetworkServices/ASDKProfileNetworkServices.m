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

#import "ASDKProfileNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKProfileInformationRequestRepresentation.h"
#import "ASDKProfilePasswordRequestRepresentation.h"
#import "ASDKModelPaging.h"
#import "ASDKModelFileContent.h"
#import "ASDKNetworkServiceConstants.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKProfileNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKProfileNetworkServices


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
#pragma mark ASDKProfileNetworkService Protocol

- (void)fetchProfileWithCompletionBlock:(ASDKProfileCompletionBlock)completionBlock {
    // Check mandatory data
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory profileServicePath]
                           parameters:nil
                              success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                  ASDKLogVerbose(@"Profile data fetched successfully for request: %@ - %@.\nBody:%@.\nResponse:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding], responseDictionary);
                                  
                                  // Parse response data
                                  [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                     ofType:CREATE_STRING(ASDKProfileParserContentTypeProfile)
                                                                        withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                            NSParameterAssert(weakSelf.resultsQueue);
                                                                            
                                                                            if (error) {
                                                                                ASDKLogError(@"Error parsing profile data. Description:%@", error.localizedDescription);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(nil, error);
                                                                                });
                                                                            } else {
                                                                                ASDKModelProfile *profile = (ASDKModelProfile *)parsedObject;
                                                                                ASDKLogVerbose(@"Successfully parsed model object:%@", profile);
                                                                                
                                                                                dispatch_async(weakSelf.resultsQueue, ^{
                                                                                    completionBlock(profile, nil);
                                                                                });
                                                                            }
                                                                        }];
                              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                  __strong typeof(self) strongSelf = weakSelf;
                                  
                                  // Remove operation reference
                                  [strongSelf.networkOperations removeObject:operation];
                                  
                                  NSParameterAssert(strongSelf.resultsQueue);
                                  
                                  ASDKLogError(@"Failed to fetch profile data for request: %@ - %@.\nBody:%@.\nReason:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding], error.localizedDescription);
                                  
                                  dispatch_async(strongSelf.resultsQueue, ^{
                                      completionBlock(nil, error);
                                  });
                              }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)updateProfileWithModel:(ASDKModelProfile *)profileModel
               completionBlock:(ASDKProfileCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(profileModel.userFirstName &&
                      profileModel.userLastName &&
                      profileModel.email &&
                      profileModel.companyName &&
                      completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    // Populate a request representation with the needed information
    ASDKProfileInformationRequestRepresentation *profileInformationRequestRepresentation = [ASDKProfileInformationRequestRepresentation new];
    profileInformationRequestRepresentation.userID = profileModel.modelID;
    profileInformationRequestRepresentation.userFirstName = profileModel.userFirstName;
    profileInformationRequestRepresentation.userLastName = profileModel.userLastName;
    profileInformationRequestRepresentation.email = profileModel.email;
    profileInformationRequestRepresentation.companyName = profileModel.companyName;
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory profileServicePath]
                            parameters:[profileInformationRequestRepresentation jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                   ASDKLogVerbose(@"Profile data was updated successfully for request: %@ - %@.\nBody:%@.\nResponse:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding], responseDictionary);
                                   
                                   // Parse response data
                                   [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                                      ofType:CREATE_STRING(ASDKProfileParserContentTypeProfile)
                                                                         withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                                             NSParameterAssert(weakSelf.resultsQueue);
                                                                             
                                                                             if (error) {
                                                                                 ASDKLogError(@"Error parsing profile data. Description:%@", error.localizedDescription);
                                                                                 
                                                                                 dispatch_async(weakSelf.resultsQueue, ^{
                                                                                     completionBlock(nil, error);
                                                                                 });
                                                                             } else {
                                                                                 ASDKModelProfile *updatedProfile = (ASDKModelProfile *)parsedObject;
                                                                                 ASDKLogVerbose(@"Successfully parsed model object:%@", updatedProfile);
                                                                                 
                                                                                 dispatch_async(weakSelf.resultsQueue, ^{
                                                                                     completionBlock(updatedProfile, nil);
                                                                                 });
                                                                             }
                                                                         }];
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSParameterAssert(strongSelf.resultsQueue);
                                   
                                   ASDKLogError(@"Failed to update profile data for request: %@ - %@.\nBody:%@.\nReason:%@.", operation.request.HTTPMethod, operation.request.URL.absoluteString, [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding], error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(nil, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)fetchProfileImageWithCompletionBlock:(ASDKProfileImageCompletionBlock)completionBlock {
    // Check mandatory data
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeImage];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager GET:[self.servicePathFactory profilePicturePath]
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

- (void)updateProfileWithNewPassword:(NSString *)updatedPassword
                         oldPassword:(NSString *)oldPassword
                     completionBlock:(ASDKProfilePasswordCompletionBlock)completionBlock {
    // Check mandatory fields
    NSParameterAssert(updatedPassword &&
                      oldPassword &&
                      completionBlock);
    
    // Populate a request representation with the needed information
    ASDKProfilePasswordRequestRepresentation *profilePasswordRequestRepresentation = [ASDKProfilePasswordRequestRepresentation new];
    profilePasswordRequestRepresentation.updatedPassword = updatedPassword;
    profilePasswordRequestRepresentation.oldPassword = oldPassword;
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory profilePasswordPath]
                            parameters:[profilePasswordRequestRepresentation jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSParameterAssert(strongSelf.resultsQueue);
                                   
                                   // Check status code
                                   if (ASDKHTTPCode200OK == operation.response.statusCode) {
                                       ASDKLogVerbose(@"Profile password was updated successfully for request: %@ - %@.\nResponse:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(YES, nil);
                                       });
                                   } else {
                                       ASDKLogVerbose(@"Profile password failed to update successfully for request: %@ - %@.\nResponse:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode]);
                                       
                                       dispatch_async(strongSelf.resultsQueue, ^{
                                           completionBlock(NO, nil);
                                       });
                                   }
                               } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                   __strong typeof(self) strongSelf = weakSelf;
                                   
                                   // Remove operation reference
                                   [strongSelf.networkOperations removeObject:operation];
                                   
                                   NSParameterAssert(strongSelf.resultsQueue);
                                   ASDKLogError(@"Failed to update profile password for request: %@ - %@. Reason:%@", operation.request.HTTPMethod, operation.request.URL.absoluteString, error.localizedDescription);
                                   
                                   dispatch_async(strongSelf.resultsQueue, ^{
                                       completionBlock(NO, error);
                                   });
                               }];
    
    // Keep network operation reference to be able to cancel it
    [self.networkOperations addObject:operation];
}

- (void)uploadProfileImageWithModel:(ASDKModelFileContent *)file
                        contentData:(NSData *)contentData
                      progressBlock:(ASDKProfileContentProgressBlock)progressBlock
                    completionBlock:(ASDKProfileImageContentUploadCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(file);
    NSParameterAssert(contentData);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory profilePictureUploadPath]
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
                 ASDKLogVerbose(@"Profile picture succesfully uploaded for request: %@ - %@.\nBody:%@.\nResponse:%@",
                                operation.request.HTTPMethod,
                                operation.request.URL.absoluteString,
                                [[NSString alloc] initWithData:operation.request.HTTPBody
                                                      encoding:NSUTF8StringEncoding],
                                responseDictionary);
                 
                 // Parse response data
                 [strongSelf.parserOperationManager parseContentDictionary:responseDictionary
                                                                    ofType:CREATE_STRING(ASDKProfileParserContentTypeContent)
                                                       withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                                           if (error) {
                                                               ASDKLogError(@"Error parsing profile image content. Description:%@", error.localizedDescription);
                                                               
                                                               dispatch_async(weakSelf.resultsQueue, ^{
                                                                   completionBlock(parsedObject, error);
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
                 
                 ASDKLogError(@"Failed to upload profile picture for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)cancelAllProfileNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}

@end
