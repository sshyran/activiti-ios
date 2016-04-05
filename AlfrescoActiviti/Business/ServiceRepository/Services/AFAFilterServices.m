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

#import "AFAFilterServices.h"
@import ActivitiSDK;

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAFilterServices ()

@property (strong, nonatomic) dispatch_queue_t                      filterUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKFilterNetworkServices             *filterNetworkService;

@end

@implementation AFAFilterServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.filterUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.filterNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFilterNetworkServiceProtocol)];
        self.filterNetworkService.resultsQueue = self.filterUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestTaskFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.filterNetworkService fetchTaskFilterListWithCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
        if (!error && filterList) {
            AFALogVerbose(@"Fetched %lu task filter entries", (unsigned long)filterList.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock (filterList, nil, paging);
            });
        } else {
            AFALogError(@"An error occured while fetching the task filter list. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error, nil);
            });
        }
    }];
}

- (void)requestTaskFilterListForAppID:(NSString *)appID
                  withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(appID);
    NSParameterAssert(completionBlock);
    
    ASDKFilterListRequestRepresentation *filterListRequestRepresentation = [ASDKFilterListRequestRepresentation new];
    filterListRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    filterListRequestRepresentation.appID = appID;
    
    [self.filterNetworkService fetchTaskFilterListWithFilter:filterListRequestRepresentation
                                         withCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
                                             if (!error && filterList) {
                                                 AFALogVerbose(@"Fetched %lu task filter entries", (unsigned long)filterList.count);
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     completionBlock (filterList, nil, paging);
                                                 });
                                             } else {
                                                 AFALogError(@"An error occured while fetching the task filter list. Reason:%@", error.localizedDescription);
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     completionBlock(nil, error, nil);
                                                 });
                                             }
                                         }];
}

- (void)requestProcessInstanceFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.filterNetworkService  fetchProcessInstanceFilterListWithCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
        if (!error && filterList) {
            AFALogVerbose(@"Fetched %lu process instance filter entries", (unsigned long)filterList.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock (filterList, nil, paging);
            });
        } else {
            AFALogError(@"An error occured while fetching the process instance filter list. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error, nil);
            });
        }
    }];
}

- (void)requestProcessInstanceFilterListForAppID:(NSString *)appID
                             withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(appID);
    NSParameterAssert(completionBlock);
    
    ASDKFilterListRequestRepresentation *filterListRequestRepresentation = [ASDKFilterListRequestRepresentation new];
    filterListRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    filterListRequestRepresentation.appID = appID;
    
    [self.filterNetworkService fetchProcessInstanceFilterListWithFilter:filterListRequestRepresentation
                                                    withCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
                                                        if (!error && filterList) {
                                                            AFALogVerbose(@"Fetched %lu process instance filter entries", (unsigned long)filterList.count);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock (filterList, nil, paging);
                                                            });
                                                        } else {
                                                            AFALogError(@"An error occured while fetching the process instance filter list. Reason:%@", error.localizedDescription);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(nil, error, nil);
                                                            });
                                                        }
                                                    }];
}

@end
