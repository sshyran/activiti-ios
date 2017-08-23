/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

#import "ASDKTaskCacheService.h"

// Constants
#import "ASDKPersistenceStackConstants.h"

// Models
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKModelTask.h"
#import "ASDKMOTask.h"
#import "ASDKModelFilter.h"
#import "ASDKMOTaskFilterMap.h"
#import "ASDKModelPaging.h"

// Persistence
#import "ASDKTaskCacheMapper.h"
#import "ASDKTaskFilterMapCacheMapper.h"

@interface ASDKTaskCacheService ()

@property (strong, nonatomic) ASDKTaskCacheMapper           *taskCacheMapper;

@end

@implementation ASDKTaskCacheService


#pragma mark -
#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _taskCacheMapper = [ASDKTaskCacheMapper new];
    }
    
    return self;
}

- (void)cacheTaskList:(NSArray *)taskList
          usingFilter:(ASDKFilterRequestRepresentation *)filter
  withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        /* When fetching the first page of tasks for a specific application
         remove all references to existing tasks and clear the filter task map
         
         Note: The filter task map exists to provide membership information for
         tasks in relation to a specific filter. Information like whether
         the current task is being made available to the user because he's
         a candidate and not a direct assignee is not retrieved by using the
         tasks/filter API but by employing the details of a task hence the need
         to locally store these kind of relations.
         */
        NSError *error = nil;
        if (!filter.page) {
            error = [strongSelf cleanStalledTasksAndFilterMapInContext:managedObjectContext
                                                             forFilter:filter];
        }
        
        if (!error) {
            error = [strongSelf saveTasksAndGenerateFilterMap:taskList
                                                    forFilter:filter
                                                    inContext:managedObjectContext];
        }
        
        if (completionBlock) {
            completionBlock(error);
        }
    }];
}

- (void)fetchTaskList:(ASDKCacheServiceTaskListCompletionBlock)completionBlock
          usingFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        
        NSArray *matchingTaskArr = nil;
        ASDKModelPaging *paging = nil;
        NSError *error = nil;
        
        NSFetchRequest *taskFilterMapRequest = [ASDKMOTaskFilterMap fetchRequest];
        taskFilterMapRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
        NSArray *taskFilterMapArr = [managedObjectContext executeFetchRequest:taskFilterMapRequest
                                                                        error:&error];
        if (!error) {
            ASDKMOTaskFilterMap *taskFilterMap = taskFilterMapArr.firstObject;
            NSUInteger fetchOffset = filter.size * filter.page;
            
            // Compute fetch predicate based on the passed filter and assigned filter map
            NSFetchRequest *fetchRequest = [ASDKMOTask fetchRequest];
            fetchRequest.sortDescriptors = @[[strongSelf sortDescriptorForFilter:filter]];
            
            NSMutableArray *predicates = [NSMutableArray array];
            NSPredicate *applicationMembershipPredicate = [strongSelf applicationMembershipPredicateForFilter:filter];
            [predicates addObject:applicationMembershipPredicate];
            
            NSPredicate *taskStatePredicate = [strongSelf taskStatePredicateForFilter:filter];
            if (taskStatePredicate) {
                [predicates addObject:taskStatePredicate];
            }
            
            NSPredicate *namePredicate = [strongSelf namePredicateForFilter:filter];
            if (namePredicate) {
                [predicates addObject:namePredicate];
            }
            
            NSPredicate *taskIDsPredicate = [strongSelf assignmentPredicateForFilter:filter
                                                                           filterMap:taskFilterMap];
            if (taskIDsPredicate) {
                [predicates addObject:taskIDsPredicate];
            } else {
                // If the assignment predicate is nil this means that it's assigned
                // filter map is empty so a fetch would be irrelevant
                if (completionBlock) {
                    paging = [ASDKModelPaging new];
                    paging.size = 0;
                    paging.start = fetchOffset;
                    paging.total = 0;
                    
                    completionBlock(nil, nil, paging);
                    return;
                }
            }
            
            NSCompoundPredicate *compoundPredicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                                                                 subpredicates:predicates];
            
            // Count the total number of cached tasks to create pagination information
            NSFetchRequest *taskCountFetchRequest = [ASDKMOTask fetchRequest];
            taskCountFetchRequest.predicate = compoundPredicate;
            taskCountFetchRequest.includesSubentities = NO;
            taskCountFetchRequest.includesPropertyValues = NO;
            
            NSUInteger taskTotalCount = [managedObjectContext countForFetchRequest:taskCountFetchRequest
                                                                             error:&error];
            
            // Configure the fetch request
            fetchRequest.predicate = compoundPredicate;
            fetchRequest.fetchLimit = filter.size;
            fetchRequest.fetchOffset = fetchOffset;
            
            matchingTaskArr = [managedObjectContext executeFetchRequest:fetchRequest
                                                                  error:&error];
            
            paging = [ASDKModelPaging new];
            paging.size = filter.size;
            paging.start = fetchOffset;
            paging.total = taskTotalCount;
        }
        
        if (completionBlock) {
            if (error || !matchingTaskArr.count) {
                completionBlock(nil, error, paging);
            } else {
                NSMutableArray *tasks = [NSMutableArray array];
                for (ASDKMOTask *moTask in matchingTaskArr) {
                    ASDKModelTask *task = [strongSelf.taskCacheMapper mapCacheMOToTask:moTask];
                    [tasks addObject:task];
                }
                
                completionBlock(tasks, nil, paging);
            }
        }
    }];
}


#pragma mark -
#pragma mark Utils

- (NSError *)clearCacheStalledDataError {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Cannot clean task cache stalled date.",
                               NSLocalizedFailureReasonErrorKey     : @"One of the cache clean operations failed.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Investigate which of the clean requests failed."};
    return [NSError errorWithDomain:ASDKPersistenceStackErrorDomain
                               code:kASDKPersistenceStackCleanCacheStalledDataErrorCode
                           userInfo:userInfo];
}


#pragma mark -
#pragma mark Operations

- (NSError *)cleanStalledTasksAndFilterMapInContext:(NSManagedObjectContext *)managedObjectContext
                                          forFilter:(ASDKFilterRequestRepresentation *)filter {
    NSError *taskDeleteError = nil;
    NSError *taskFilterMapDeleteError = nil;
    NSBatchDeleteResult *taskDeletionResult = nil;
    NSBatchDeleteResult *taskFilterMapDeletionresult = nil;
    
    NSFetchRequest *oldTaskFilterMap = [ASDKMOTaskFilterMap fetchRequest];
    oldTaskFilterMap.predicate = [self filterMapMembershipPredicateForFilter:filter];
    
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:oldTaskFilterMap
                                                                error:&taskFilterMapDeleteError];
    
    if (!taskFilterMapDeleteError) {
        ASDKMOTaskFilterMap *filterMap = fetchResults.firstObject;
        NSArray *taskIDsForFilter = [filterMap.tasks valueForKeyPath:@"@distinctUnionOfObjects.modelID"];
        
        if (taskIDsForFilter.count) {
            NSFetchRequest *oldTasksFetchRequest = [ASDKMOTask fetchRequest];
            oldTasksFetchRequest.predicate = [NSPredicate predicateWithFormat:@"modelID IN %@", taskIDsForFilter];
            NSBatchDeleteRequest *removeOldTasksRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldTasksFetchRequest];
            removeOldTasksRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
            taskDeletionResult = [managedObjectContext executeRequest:removeOldTasksRequest
                                                                error:&taskDeleteError];
        }
        
        NSBatchDeleteRequest *removeOldTaskFilterMapRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldTaskFilterMap];
        removeOldTaskFilterMapRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
        taskFilterMapDeletionresult = [managedObjectContext executeRequest:removeOldTaskFilterMapRequest
                                                                     error:&taskFilterMapDeleteError];
    }
    
    if (taskDeleteError || taskFilterMapDeleteError) {
        return [self clearCacheStalledDataError];
    } else {
        NSArray *taskMOIDArr = taskDeletionResult.result;
        NSArray *filterMapMOIDArr = taskFilterMapDeletionresult.result;
        
        NSArray *deletedItems = [taskMOIDArr arrayByAddingObjectsFromArray:filterMapMOIDArr];
        if (deletedItems.count) {
            [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey : deletedItems}
                                                         intoContexts:@[managedObjectContext]];
        }
    }
    
    return nil;
}

- (NSError *)saveTasksAndGenerateFilterMap:(NSArray *)taskList
                                 forFilter:(ASDKFilterRequestRepresentation *)filter
                                 inContext:(NSManagedObjectContext *)managedObjectContext {
    NSError *error = nil;
    
    NSMutableArray *moTasks = [NSMutableArray array];
    
    for (ASDKModelTask *task in taskList) {
        ASDKMOTask *moTask = [self.taskCacheMapper mapTaskToCacheMO:task
                                                     usingMOContext:managedObjectContext];
        [moTasks addObject:moTask];
    }
    
    NSFetchRequest *taskFilterMapRequest = [ASDKMOTaskFilterMap fetchRequest];
    taskFilterMapRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
    
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:taskFilterMapRequest
                                                                error:&error];
    
    if (error) {
        return error;
    }
    
    ASDKTaskFilterMapCacheMapper *filterMapCacheMapper = [ASDKTaskFilterMapCacheMapper new];
    if (!fetchResults.count) {
        [filterMapCacheMapper mapTaskList:moTasks
                               withFilter:filter
                           usingMOContext:managedObjectContext];
    } else {
        ASDKMOTaskFilterMap *filterMap = fetchResults.firstObject;
        [filterMapCacheMapper mapToExistingTaskFilterMap:filterMap
                                                taskList:moTasks];
    }
    
    [managedObjectContext save:&error];
    
    return error;
}


#pragma mark -
#pragma mark Predicate construction

- (NSPredicate *)applicationMembershipPredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    return [NSPredicate predicateWithFormat:@"processDefinitionDeploymentID == %@ || category == %@",
            filter.appDeploymentID,
            filter.appDefinitionID];
}

- (NSPredicate *)filterMapMembershipPredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSPredicate *appIDPredicate = [NSPredicate predicateWithFormat:@"applicationID == %@", filter.appDefinitionID];
    NSPredicate *assignmentTypePredicate = [NSPredicate predicateWithFormat:@"assignmentType == %ld", filter.filterModel.assignmentType];
    NSPredicate *statePredicate = [NSPredicate predicateWithFormat:@"state == %ld", filter.filterModel.state];
    
    return [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[appIDPredicate, assignmentTypePredicate, statePredicate]];
}

- (NSPredicate *)taskStatePredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSPredicate *statePredicate = nil;
    
    switch (filter.filterModel.state) {
        case ASDKModelFilterStateTypeCompleted: {
            statePredicate = [NSPredicate predicateWithFormat:@"endDate != nil"];
        }
            break;
            
        case ASDKModelFilterStateTypeRunning: {
            statePredicate = [NSPredicate predicateWithFormat:@"endDate == nil"];
        }
            break;
            
        case ASDKModelFilterStateTypeActive:
        case ASDKModelFilterStateTypeAll:
            break;
            
        default:
            break;
    }
    
    return statePredicate;
}

- (NSPredicate *)assignmentPredicateForFilter:(ASDKFilterRequestRepresentation *)filter
                                    filterMap:(ASDKMOTaskFilterMap *)filterMap {
    NSPredicate *assignmentPredicate = nil;
    switch (filter.filterModel.assignmentType) {
        case ASDKModelFilterAssignmentTypeAssignee: {
            assignmentPredicate = [NSPredicate predicateWithFormat:@"assignee != nil"];
        }
            break;
            
        case ASDKModelFilterAssignmentTypeInvolved:
        case ASDKModelFilterAssignmentTypeCandidate: {
            NSArray *taskIDsForFilter = [filterMap.tasks valueForKeyPath:@"@distinctUnionOfObjects.modelID"];
            if (taskIDsForFilter.count) {
                assignmentPredicate = [NSPredicate predicateWithFormat:@"modelID IN %@", taskIDsForFilter];
            }
        }
            
        default: break;
    }
    
    return assignmentPredicate;
}

- (NSPredicate *)namePredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    if (filter.filterModel.name.length) {
        return [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", filter.filterModel.name];
    }
    
    return nil;
}


#pragma mark -
#pragma mark Sort descriptor construction

- (NSSortDescriptor *)sortDescriptorForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSSortDescriptor *sortDescriptor = nil;
    
    switch (filter.filterModel.sortType) {
        case ASDKModelFilterSortTypeCreatedDesc: {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate"
                                                         ascending:NO];
        }
            break;
        case ASDKModelFilterSortTypeCreatedAsc: {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate"
                                                         ascending:YES];
        }
            break;
            
        case ASDKModelFilterSortTypeDueDesc: {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dueDate"
                                                         ascending:NO];
        }
            break;
            
        case ASDKModelFilterSortTypeDueAsc: {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dueDate"
                                                         ascending:YES];
        }
            break;
            
        default: break;
    }
    
    return sortDescriptor;
}

@end
