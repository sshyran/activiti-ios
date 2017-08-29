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

// Model upsert
#import "ASDKTaskCacheModelUpsert.h"

// Persistence
#import "ASDKTaskCacheMapper.h"
#import "ASDKTaskFilterMapCacheMapper.h"

@implementation ASDKTaskCacheService


#pragma mark -
#pragma makr Public interface

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
        
        if (!error) {
            [managedObjectContext save:&error];
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
        
        ASDKModelPaging *paging = nil;
        NSError *error = nil;
        NSArray *pagedTaskArr = nil;
        
        NSFetchRequest *taskFilterMapRequest = [ASDKMOTaskFilterMap fetchRequest];
        taskFilterMapRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
        NSArray *taskFilterMapArr = [managedObjectContext executeFetchRequest:taskFilterMapRequest
                                                                        error:&error];
        if (!error) {
            NSArray *matchingTaskArr = nil;
            
            ASDKMOTaskFilterMap *taskFilterMap = taskFilterMapArr.firstObject;
            NSArray *sortedTasks = [taskFilterMap.tasks sortedArrayUsingDescriptors:@[[strongSelf sortDescriptorForFilter:filter]]];
            NSPredicate *namePredicate = [strongSelf namePredicateForFilter:filter];
            if (namePredicate) {
                matchingTaskArr = [sortedTasks filteredArrayUsingPredicate:namePredicate];
            } else {
                matchingTaskArr = sortedTasks;
            }
            
            NSUInteger fetchOffset = filter.size * filter.page;
            NSUInteger count = MIN(matchingTaskArr.count - fetchOffset, filter.size);
            pagedTaskArr = [matchingTaskArr subarrayWithRange:NSMakeRange(fetchOffset, count)];
            
            paging = [strongSelf paginationWithFilter:filter
                                    forTotalTaskCount:sortedTasks.count
                                   remainingTaskCount:count];
        }
        
        if (completionBlock) {
            if (error || !pagedTaskArr.count) {
                completionBlock(nil, error, paging);
            } else {
                NSMutableArray *tasks = [NSMutableArray array];
                for (ASDKMOTask *moTask in pagedTaskArr) {
                    ASDKModelTask *task = [ASDKTaskCacheMapper mapCacheMOToTask:moTask];
                    [tasks addObject:task];
                }
                
                completionBlock(tasks, nil, paging);
            }
        }
    }];
}

- (void)cacheTaskDetails:(ASDKModelTask *)task
     withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSError *error = nil;
        [ASDKTaskCacheModelUpsert upsertTaskToCache:task
                                              error:&error
                                        inMOContext:managedObjectContext];
        
        if (!error) {
            [managedObjectContext save:&error];
        }
        
        if (completionBlock) {
            completionBlock(error);
        }
    }];
}

- (void)fetchTaskDetailsForID:(NSString *)taskID
          withCompletionBlock:(ASDKCacheServiceTaskDetailsCompletionBlock)completionBlock {
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        NSFetchRequest *fetchRequest = [ASDKMOTask fetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"modelID == %@", taskID];
        
        NSError *error = nil;
        NSArray *fetchResults = [managedObjectContext executeFetchRequest:fetchRequest
                                                                    error:&error];
        
        if (completionBlock) {
            ASDKMOTask *moTask = fetchResults.firstObject;
            
            if (error || !moTask) {
                completionBlock(nil, error);
            } else {
                ASDKModelTask *task = [ASDKTaskCacheMapper mapCacheMOToTask:moTask];
                completionBlock(task, nil);
            }
        }
    }];
}



#pragma mark -
#pragma mark Operations

- (NSError *)cleanStalledTasksAndFilterMapInContext:(NSManagedObjectContext *)managedObjectContext
                                          forFilter:(ASDKFilterRequestRepresentation *)filter {
    NSError *error = nil;
    
    NSFetchRequest *oldTaskFilterMapRequest = [ASDKMOTaskFilterMap fetchRequest];
    oldTaskFilterMapRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
    oldTaskFilterMapRequest.resultType = NSManagedObjectIDResultType;
    NSBatchDeleteRequest *removeOldTaskFilterMapRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldTaskFilterMapRequest];
    removeOldTaskFilterMapRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
    NSBatchDeleteResult *taskFilterMapDeletionresult = [managedObjectContext executeRequest:removeOldTaskFilterMapRequest
                                                                                      error:&error];
    
    NSArray *moIDArr = taskFilterMapDeletionresult.result;
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey : moIDArr}
                                                 intoContexts:@[managedObjectContext]];
    
    if (error) {
        return [self clearCacheStalledDataError];
    }
    
    return nil;
}

- (NSError *)saveTasksAndGenerateFilterMap:(NSArray *)taskList
                                 forFilter:(ASDKFilterRequestRepresentation *)filter
                                 inContext:(NSManagedObjectContext *)managedObjectContext {
    NSError *error = nil;
    NSArray *moTasks = [ASDKTaskCacheModelUpsert upsertTaskListToCache:taskList
                                                                 error:&error
                                                           inMOContext:managedObjectContext];
    if (error) {
        return error;
    }
    
    NSFetchRequest *taskFilterMapFetchRequest = [ASDKMOTaskFilterMap fetchRequest];
    taskFilterMapFetchRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:taskFilterMapFetchRequest
                                                                error:&error];
    if (error) {
        return error;
    }
    ASDKMOTaskFilterMap *taskFilterMap = fetchResults.firstObject;
    if (!taskFilterMap) {
        taskFilterMap = [NSEntityDescription insertNewObjectForEntityForName:[ASDKMOTaskFilterMap entityName]
                                                      inManagedObjectContext:managedObjectContext];
    }
    [ASDKTaskFilterMapCacheMapper mapTaskList:moTasks
                                   withFilter:filter
                                    toCacheMO:taskFilterMap];
    
    return nil;
}

- (ASDKModelPaging *)paginationWithFilter:(ASDKFilterRequestRepresentation *)filter
                        forTotalTaskCount:(NSUInteger)taskTotalCount
                       remainingTaskCount:(NSUInteger)remainingTaskCount {
    
    
    ASDKModelPaging * paging = [ASDKModelPaging new];
    paging.size = remainingTaskCount;
    paging.start = filter.size * filter.page;
    paging.total = taskTotalCount;
    
    return paging;
}


- (ASDKModelPaging *)emptyPagination {
    ASDKModelPaging *paging = [ASDKModelPaging new];
    paging.size = 0;
    paging.start = 0;
    paging.total = 0;
    
    return paging;
}


#pragma mark -
#pragma mark Predicate construction

- (NSPredicate *)filterMapMembershipPredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSPredicate *appIDPredicate = [NSPredicate predicateWithFormat:@"applicationID == %@", filter.appDefinitionID];
    NSPredicate *assignmentTypePredicate = [NSPredicate predicateWithFormat:@"assignmentType == %ld", filter.filterModel.assignmentType];
    NSPredicate *statePredicate = [NSPredicate predicateWithFormat:@"state == %ld", filter.filterModel.state];
    
    return [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[appIDPredicate, assignmentTypePredicate, statePredicate]];
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


#pragma mark -
#pragma mark Errors

- (NSError *)clearCacheStalledDataError {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Cannot clean task cache stalled date.",
                               NSLocalizedFailureReasonErrorKey     : @"One of the cache clean operations failed.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Investigate which of the clean requests failed."};
    return [NSError errorWithDomain:ASDKPersistenceStackErrorDomain
                               code:kASDKPersistenceStackCleanCacheStalledDataErrorCode
                           userInfo:userInfo];
}

@end
