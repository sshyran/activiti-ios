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

#import "ASDKProcessInstanceCacheService.h"

// Constants
#import "ASDKPersistenceStackConstants.h"

// Model upsert
#import "ASDKProcessInstanceCacheModelUpsert.h"

// Models
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKMOProcessInstance.h"
#import "ASDKModelPaging.h"
#import "ASDKModelFilter.h"
#import "ASDKModelProcessInstance.h"

// Persistence
#import "ASDKProcessInstanceCacheMapper.h"

@implementation ASDKProcessInstanceCacheService


#pragma mark -
#pragma mark Public interface

- (void)cacheProcessInstanceList:(NSArray *)processInstanceList
                     usingFilter:(ASDKFilterRequestRepresentation *)filter
             withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        // When fetching the first page of process instances for a specific application
        // remove all references to existing process instances
        NSError *error = nil;
        if (!filter.page) {
            error = [strongSelf cleanStalledProcessInstancesInContext:managedObjectContext
                                                            forFilter:filter];
        }
        
        if (!error) {
            error = [strongSelf saveProcessInstanceList:processInstanceList
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

- (void)fetchProcessInstanceList:(ASDKCacheServiceProcessInstanceListCompletionBlock)completionBlock
                     usingFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKModelPaging *paging = nil;
        NSError *error = nil;
        NSArray *pagedProcessInstanceArr = nil;
        
        NSFetchRequest *processInstanceFilterRequest = [ASDKMOProcessInstance fetchRequest];
        processInstanceFilterRequest.predicate = [self processInstancePredicateForFilter:filter];
        NSArray *matchingProcessInstanceArr = [managedObjectContext executeFetchRequest:processInstanceFilterRequest
                                                                                  error:&error];
        if (!error) {
            NSArray *sortedProcessInstances = [matchingProcessInstanceArr sortedArrayUsingDescriptors:@[[strongSelf sortDescriptorForFilter:filter]]];
            
            NSUInteger fetchOffset = filter.size * filter.page;
            NSUInteger count = MIN(sortedProcessInstances.count - fetchOffset, filter.size);
            pagedProcessInstanceArr = [sortedProcessInstances subarrayWithRange:NSMakeRange(fetchOffset, count)];
            
            paging = [strongSelf paginationWithStartIndex:filter.size * filter.page
                                        forTotalTaskCount:sortedProcessInstances.count
                                       remainingTaskCount:count];
        }
        
        if (completionBlock) {
            if (error || !pagedProcessInstanceArr.count) {
                completionBlock(nil, error, paging);
            } else {
                NSMutableArray *processInstances = [NSMutableArray array];
                for (ASDKMOProcessInstance *moProcessInstance in pagedProcessInstanceArr) {
                    ASDKModelProcessInstance *processInstance = [ASDKProcessInstanceCacheMapper mapCacheMOToProcessInstance:moProcessInstance];
                    [processInstances addObject:processInstance];
                }
                
                completionBlock(processInstances, nil, paging);
            }
        }
    }];
}


#pragma mark -
#pragma mark Operations

- (NSError *)cleanStalledProcessInstancesInContext:(NSManagedObjectContext *)managedObjectContext
                                         forFilter:(ASDKFilterRequestRepresentation *)filter {
    NSError *internalError = nil;
    
    NSFetchRequest *oldProcessInstancesRequest = [ASDKMOProcessInstance fetchRequest];
    oldProcessInstancesRequest.predicate = [self processInstancePredicateForFilter:filter];
    oldProcessInstancesRequest.resultType = NSManagedObjectIDResultType;
    
    NSBatchDeleteRequest *removeOldProcessInstancesRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldProcessInstancesRequest];
    removeOldProcessInstancesRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
    NSBatchDeleteResult *removeOldProcessInstancesResult = [managedObjectContext executeRequest:removeOldProcessInstancesRequest
                                                                                         error:&internalError];
    NSArray *moIDArr = removeOldProcessInstancesResult.result;
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey : moIDArr}
                                                 intoContexts:@[managedObjectContext]];
    if (internalError) {
        return [self clearCacheStalledDataError];
    }
    
    return nil;
}

- (NSError *)saveProcessInstanceList:(NSArray *)processInstanceList
                           inContext:(NSManagedObjectContext *)managedObjectContext {
    NSError *error = nil;
    [ASDKProcessInstanceCacheModelUpsert upsertProcessInstanceListToCache:processInstanceList
                                                                    error:&error
                                                              inMOContext:managedObjectContext];
    
    return error;
}

- (ASDKModelPaging *)paginationWithStartIndex:(NSUInteger)startIndex
                            forTotalTaskCount:(NSUInteger)taskTotalCount
                           remainingTaskCount:(NSUInteger)remainingTaskCount {
    ASDKModelPaging * paging = [ASDKModelPaging new];
    paging.size = remainingTaskCount;
    paging.start = startIndex;
    paging.total = taskTotalCount;
    
    return paging;
}


#pragma mark -
#pragma mark Predicate construction

- (NSPredicate *)processInstancePredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSPredicate *predicate = nil;
    
    switch (filter.filterModel.state) {
        case ASDKModelFilterStateTypeCompleted: {
            predicate = [self completedProcessInstancePredicateForFilter:filter];
        }
            break;
            
        case ASDKModelFilterStateTypeRunning: {
            predicate = [self runningProcessInstancesPredicateForFiter:filter];
        }
            break;
            
        default: break;
    }
    
    return predicate;
}

- (NSPredicate *)runningProcessInstancesPredicateForFiter:(ASDKFilterRequestRepresentation *)filter {
    NSMutableArray *subpredicates = [NSMutableArray array];
    
    NSPredicate *endDatePredicate = [NSPredicate predicateWithFormat:@"endDate == nil"];
    [subpredicates addObject:endDatePredicate];
    
    if (filter.appDefinitionID) {
        NSPredicate *applicationPredicate = [NSPredicate predicateWithFormat:@"applicationID == %@", filter.appDefinitionID];
        [subpredicates addObject:applicationPredicate];
    }
    if (filter.filterModel.name.length) {
        NSPredicate *namePredicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", filter.filterModel.name];
        [subpredicates addObject:namePredicate];
    }
    
    return [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                       subpredicates:subpredicates];
}

- (NSPredicate *)completedProcessInstancePredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    NSMutableArray *subpredicates = [NSMutableArray array];
    
    NSPredicate *endDatePredicate = [NSPredicate predicateWithFormat:@"endDate != nil"];
    [subpredicates addObject:endDatePredicate];
    
    if (filter.appDefinitionID) {
        NSPredicate *applicationPredicate = [NSPredicate predicateWithFormat:@"applicationID == %@", filter.appDefinitionID];
        [subpredicates addObject:applicationPredicate];
    }
    if (filter.filterModel.name.length) {
        NSPredicate *namePredicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", filter.filterModel.name];
        [subpredicates addObject:namePredicate];
    }
    
    return [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType
                                       subpredicates:subpredicates];
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
            
        default: break;
    }
    
    return sortDescriptor;
}


#pragma mark -
#pragma mark Errors

- (NSError *)clearCacheStalledDataError {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Cannot clean cache stalled data.",
                               NSLocalizedFailureReasonErrorKey     : @"One of the cache clean operations failed.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Investigate which of the clean requests failed."};
    return [NSError errorWithDomain:ASDKPersistenceStackErrorDomain
                               code:kASDKPersistenceStackCleanCacheStalledDataErrorCode
                           userInfo:userInfo];
}

@end
