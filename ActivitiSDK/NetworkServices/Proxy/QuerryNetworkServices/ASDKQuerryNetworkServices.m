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

#import "ASDKQuerryNetworkServices.h"
#import "ASDKLogConfiguration.h"
#import "ASDKTaskListQuerryRequestRepresentation.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKQuerryNetworkServices ()

@property (strong, nonatomic) NSMutableArray *networkOperations;

@end

@implementation ASDKQuerryNetworkServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.networkOperations = [NSMutableArray array];
    }
    
    return self;
}

- (void)fetchTaskListWithFilterRepresentation:(ASDKTaskListQuerryRequestRepresentation *)filter
                              completionBlock:(ASDKQuerryTaskListCompletionBlock)completionBlock {
    // Check mandatory properties
    NSParameterAssert(filter);
    NSParameterAssert(completionBlock);
    NSParameterAssert(self.resultsQueue);
    
    self.requestOperationManager.responseSerializer = [self responseSerializerOfType:ASDKNetworkServiceResponseSerializerTypeJSON];
    
    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperation *operation =
    [self.requestOperationManager POST:[self.servicePathFactory taskQueryServicePath]
                            parameters:[filter jsonDictionary]
                               success:^(AFHTTPRequestOperation *operation, id responseObject) {
           __strong typeof(self) strongSelf = weakSelf;
           
           // Remove operation refference
           [strongSelf.networkOperations removeObject:operation];
           
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
       } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
           __strong typeof(self) strongSelf = weakSelf;
           
           // Remove operation refference
           [strongSelf.networkOperations removeObject:operation];
           
           ASDKLogError(@"Failed to fetch task list for request: %@ - %@.\nBody:%@.\nReason:%@",
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

- (void)cancelAllTaskNetworkOperations {
    [self.networkOperations makeObjectsPerformSelector:@selector(cancel)];
    [self.networkOperations removeAllObjects];
}

@end
