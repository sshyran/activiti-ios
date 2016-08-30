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

// Constants
#import "AFALocalizationConstants.h"

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
    
    __weak typeof(self) weakSelf = self;
    [self.filterNetworkService fetchTaskFilterListWithFilter:filterListRequestRepresentation
                                         withCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
                                             if (!error) {
                                                 if (filterList.count) {
                                                     AFALogVerbose(@"Fetched %lu task filter entries", (unsigned long)filterList.count);
                                                     
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         completionBlock (filterList, nil, paging);
                                                     });
                                                 } else {
                                                     AFALogVerbose(@"There are no filters defined. Will populate with default ones...");
                                                     
                                                     __strong typeof(self) strongSelf = weakSelf;
                                                     [strongSelf requestCreateDefaultTaskFiltersForAppID:appID
                                                                                     withCompletionBlock:completionBlock];
                                                 }
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
    
    __weak typeof(self) weakSelf = self;
    [self.filterNetworkService fetchProcessInstanceFilterListWithFilter:filterListRequestRepresentation
                                                    withCompletionBlock:^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
                                                        if (!error) {
                                                            if (filterList.count) {
                                                                AFALogVerbose(@"Fetched %lu process instance filter entries", (unsigned long)filterList.count);
                                                                
                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                    completionBlock (filterList, nil, paging);
                                                                });
                                                            } else {
                                                                AFALogVerbose(@"There are no filters defined. Will populate with default ones...");
                                                                
                                                                __strong typeof(self) strongSelf = weakSelf;
                                                                [strongSelf requestCreateDefaultProcessInstanceFiltersForAppID:appID
                                                                                                           withCompletionBlock:completionBlock];
                                                            }
                                                        } else {
                                                            AFALogError(@"An error occured while fetching the process instance filter list. Reason:%@", error.localizedDescription);
                                                            
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                completionBlock(nil, error, nil);
                                                            });
                                                        }
                                                    }];
}


#pragma mark -
#pragma mark Private interface

- (void)requestCreateDefaultTaskFiltersForAppID:(NSString *)appID
                            withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(appID);
    NSParameterAssert(completionBlock);
    
    __block NSError *operationError = nil;
    __block NSMutableArray *filterArr = [NSMutableArray array];
    
    dispatch_group_t defaultTaskFilterGroup = dispatch_group_create();
    
    ASDKFilterModelCompletionBlock defaultFilterCompletionBlock = ^(ASDKModelFilter *filter, NSError *error) {
        if (!error && filter) {
            AFALogVerbose(@"Created default filter:%@", filter.name);
            [filterArr addObject:filter];
        } else {
            operationError = error;
        }
        dispatch_group_leave(defaultTaskFilterGroup);
    };
    
    // Involved tasks filter
    ASDKFilterCreationRequestRepresentation *involvedTasksFilter = [ASDKFilterCreationRequestRepresentation new];
    involvedTasksFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    involvedTasksFilter.appID = appID;
    involvedTasksFilter.icon = kASDKAPIIconNameInvolved;
    involvedTasksFilter.index = 0;
    involvedTasksFilter.name = NSLocalizedString(kLocalizationDefaultFilterInvolvedTasksText, @"Involved tasks text");
    
    ASDKModelFilter *involvedFilter = [ASDKModelFilter new];
    involvedFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    involvedFilter.assignmentType = ASDKTaskAssignmentTypeInvolved;
    involvedFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    involvedFilter.state = ASDKModelFilterStateTypeActive;
    
    involvedTasksFilter.filter = involvedFilter;
    
    dispatch_group_enter(defaultTaskFilterGroup);
    [self.filterNetworkService createUserTaskFilterWithRepresentation:involvedTasksFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    // My tasks filter
    ASDKFilterCreationRequestRepresentation *myTasksFilter = [ASDKFilterCreationRequestRepresentation new];
    myTasksFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    myTasksFilter.appID = appID;
    myTasksFilter.icon = kASDKAPIIconNameMy;
    myTasksFilter.index = 1;
    myTasksFilter.name = NSLocalizedString(kLocalizationDefaultFilterMyTasksText, @"My tasks text");
    
    ASDKModelFilter *myFilter = [ASDKModelFilter new];
    myFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    myFilter.assignmentType = ASDKTaskAssignmentTypeAssignee;
    myFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    myFilter.state = ASDKModelFilterStateTypeActive;
    
    myTasksFilter.filter = myFilter;
    
    dispatch_group_enter(defaultTaskFilterGroup);
    [self.filterNetworkService createUserTaskFilterWithRepresentation:myTasksFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    // Queued tasks
    ASDKFilterCreationRequestRepresentation *queuedTasksFilter = [ASDKFilterCreationRequestRepresentation new];
    queuedTasksFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    queuedTasksFilter.appID = appID;
    queuedTasksFilter.icon = kASDKAPIIconNameQueued;
    queuedTasksFilter.index = 2;
    queuedTasksFilter.name = NSLocalizedString(kLocalizationDefaultFilterQueuedTasksText, @"Queued tasks text");
    
    ASDKModelFilter *queuedFilter = [ASDKModelFilter new];
    queuedFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    queuedFilter.assignmentType = ASDKTaskAssignmentTypeCandidate;
    queuedFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    queuedFilter.state = ASDKModelFilterStateTypeActive;
    
    queuedTasksFilter.filter = queuedFilter;
    
    dispatch_group_enter(defaultTaskFilterGroup);
    [self.filterNetworkService createUserTaskFilterWithRepresentation:queuedTasksFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    // Completed tasks
    ASDKFilterCreationRequestRepresentation *completedTasksFilter = [ASDKFilterCreationRequestRepresentation new];
    completedTasksFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    completedTasksFilter.appID = appID;
    completedTasksFilter.icon = kASDKAPIIconNameCompleted;
    completedTasksFilter.index = 3;
    completedTasksFilter.name = NSLocalizedString(kLocalizationDefaultFilterCompletedTasksText, @"Completed tasks text");
    
    ASDKModelFilter *completedFilter = [ASDKModelFilter new];
    completedFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    completedFilter.assignmentType = ASDKTaskAssignmentTypeInvolved;
    completedFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    completedFilter.state = ASDKModelFilterStateTypeCompleted;
    
    completedTasksFilter.filter = completedFilter;
    
    dispatch_group_enter(defaultTaskFilterGroup);
    [self.filterNetworkService createUserTaskFilterWithRepresentation:completedTasksFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(defaultTaskFilterGroup, dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (operationError) {
            AFALogError(@"Encountered an error for default task filter create operation. Reason:%@", operationError.localizedDescription);
            completionBlock(nil, operationError, nil);
        } else {
            // Re-fetch again because filter detail information is not suficient to be reported back
            AFALogVerbose(@"Successfully created %lu default task filters. Re-fetching filter details...", (unsigned long)filterArr.count);
            [strongSelf requestTaskFilterListForAppID:appID
                                  withCompletionBlock:completionBlock];
        }
    });
}

- (void)requestCreateDefaultProcessInstanceFiltersForAppID:(NSString *)appID
                                      withCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    NSParameterAssert(appID);
    NSParameterAssert(completionBlock);
    
    __block NSError *operationError = nil;
    __block NSMutableArray *filterArr = [NSMutableArray array];
    
    dispatch_group_t defaultProcessInstanceFilterGroup = dispatch_group_create();
    
    ASDKFilterModelCompletionBlock defaultFilterCompletionBlock = ^(ASDKModelFilter *filter, NSError *error) {
        if (!error && filter) {
            AFALogVerbose(@"Created default filter:%@", filter.name);
            [filterArr addObject:filter];
        } else {
            operationError = error;
        }
        dispatch_group_leave(defaultProcessInstanceFilterGroup);
    };
    
    // Running process instances filter
    ASDKFilterCreationRequestRepresentation *runningProcessInstancesFilter = [ASDKFilterCreationRequestRepresentation new];
    runningProcessInstancesFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    runningProcessInstancesFilter.appID = appID;
    runningProcessInstancesFilter.icon = kASDKAPIIconNameRunning;
    runningProcessInstancesFilter.index = 0;
    runningProcessInstancesFilter.name = NSLocalizedString(kLocalizationDefaultFilterRunningProcessText, @"Running process instances text");
    
    ASDKModelFilter *runningFilter = [ASDKModelFilter new];
    runningFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    runningFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    runningFilter.state = ASDKModelFilterStateTypeRunning;
    
    runningProcessInstancesFilter.filter = runningFilter;
    
    dispatch_group_enter(defaultProcessInstanceFilterGroup);
    [self.filterNetworkService createProcessInstanceTaskFilterWithRepresentation:runningProcessInstancesFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    // Completed process instances filter
    ASDKFilterCreationRequestRepresentation *completedProcessInstancesFilter = [ASDKFilterCreationRequestRepresentation new];
    completedProcessInstancesFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    completedProcessInstancesFilter.appID = appID;
    completedProcessInstancesFilter.icon = kASDKAPIIconNameCompleted;
    completedProcessInstancesFilter.index = 1;
    completedProcessInstancesFilter.name = NSLocalizedString(kLocalizationDefaultFilterCompletedProcessesText, @"Completed process instances text");
    
    ASDKModelFilter *completedFilter = [ASDKModelFilter new];
    completedFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    completedFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    completedFilter.state = ASDKModelFilterStateTypeCompleted;
    
    completedProcessInstancesFilter.filter = completedFilter;
    
    dispatch_group_enter(defaultProcessInstanceFilterGroup);
    [self.filterNetworkService createProcessInstanceTaskFilterWithRepresentation:completedProcessInstancesFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    // All process instances filter
    ASDKFilterCreationRequestRepresentation *allProcessInstancesFilter = [ASDKFilterCreationRequestRepresentation new];
    allProcessInstancesFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    allProcessInstancesFilter.appID = appID;
    allProcessInstancesFilter.icon = kASDKAPIIconNameAll;
    allProcessInstancesFilter.index = 2;
    allProcessInstancesFilter.name = NSLocalizedString(kLocalizationDefaultFilterAllProcessesText, @"All process instances text");
    
    ASDKModelFilter *allFilter = [ASDKModelFilter new];
    allFilter.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    allFilter.sortType = ASDKModelFilterSortTypeCreatedDesc;
    allFilter.state = ASDKModelFilterStateTypeAll;
    
    allProcessInstancesFilter.filter = allFilter;
    
    dispatch_group_enter(defaultProcessInstanceFilterGroup);
    [self.filterNetworkService createProcessInstanceTaskFilterWithRepresentation:allProcessInstancesFilter
                                                  withCompletionBlock:defaultFilterCompletionBlock];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(defaultProcessInstanceFilterGroup, dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (operationError) {
            AFALogError(@"Encountered an error for default process instance filter create operation. Reason:%@", operationError.localizedDescription);
            completionBlock(nil, operationError, nil);
        } else {
            // Re-fetch again because filter detail information is not suficient to be reported back
            AFALogVerbose(@"Successfully created %lu default process instance filters. Re-fetching filter details...", (unsigned long)filterArr.count);
            [strongSelf requestProcessInstanceFilterListForAppID:appID
                                             withCompletionBlock:completionBlock];
        }
    });
}
@end
