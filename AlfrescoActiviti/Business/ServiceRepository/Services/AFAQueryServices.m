/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile iOS App.
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

#import "AFAQueryServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAQueryServices ()

@property (strong, nonatomic) dispatch_queue_t                      queryUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKQuerryNetworkServices             *queryNetworkService;

@end

@implementation AFAQueryServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.queryUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.queryNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKQuerryNetworkServiceProtocol)];
        self.queryNetworkService.resultsQueue = self.queryUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestTaskListWithFilter:(AFAGenericFilterModel *)taskFilter
                  completionBlock:(AFAQuerryTaskListCompletionBlock)completionBlock {
    NSParameterAssert(taskFilter);
    NSParameterAssert(completionBlock);
    
    // Create request representation for the filter model
    ASDKTaskListQuerryRequestRepresentation *queryRequestRepresentation = [ASDKTaskListQuerryRequestRepresentation new];
    queryRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    queryRequestRepresentation.processInstanceID = taskFilter.processInstanceID;
    queryRequestRepresentation.requestTaskState = (NSInteger)taskFilter.state;
    
    [self.queryNetworkService fetchTaskListWithFilterRepresentation:queryRequestRepresentation
                                                    completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                                        if (!error && taskList) {
                                                            AFALogVerbose(@"Fetched %lu task entries", (unsigned long)taskList.count);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock (taskList, nil, paging);
                                                            });
                                                        } else {
                                                            AFALogError(@"An error occured while fetching the task list with filter:%@. Reason:%@", taskFilter.description, error.localizedDescription);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(nil, error, nil);
                                                            });
                                                        }
    }];
}

@end
