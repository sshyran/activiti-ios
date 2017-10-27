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
#import "ASDKMOProcessInstanceFilterMap.h"
#import "ASDKModelPaging.h"
#import "ASDKModelFilter.h"
#import "ASDKModelProcessInstance.h"

// Persistence
#import "ASDKProcessInstanceCacheMapper.h"
#import "ASDKProcessInstanceFilterMapCacheMapper.h"

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
        
        /* When fetching the first page of process instances for a specific application
         remove all references to existing process instances and clear the process instance filter map
         
         Note: The process instance filter map exists to provide membership information for
         process instances in relation to a specific filter and application.
         */
        NSError *error = nil;
        if (!filter.page &&
            ASDKModelFilterStateTypeAll != filter.filterModel.state) {
            error = [strongSelf cleanStalledProcessInstancesInContext:managedObjectContext
                                                            forFilter:filter];
        }
        
        if (!error) {
            error = [strongSelf saveProcessInstanceListAndGenerateFilterMap:processInstanceList
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

- (void)fetchProcessInstanceList:(ASDKCacheServiceProcessInstanceListCompletionBlock)completionBlock
                     usingFilter:(ASDKFilterRequestRepresentation *)filter {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKModelPaging *paging = nil;
        NSError *error = nil;
        NSArray *pagedProcessInstanceArr = nil;
        
        NSFetchRequest *processInstanceFilterMapRequest = [ASDKMOProcessInstanceFilterMap fetchRequest];
        if (ASDKModelFilterStateTypeAll == filter.filterModel.state) {
            processInstanceFilterMapRequest.predicate = [self allFilterMapsOnCurrentApplicationForFilter:filter];
        } else {
            processInstanceFilterMapRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
        }
        
        NSArray *processInstanceFilterMapArr = [managedObjectContext executeFetchRequest:processInstanceFilterMapRequest
                                                                                  error:&error];
        if (!error) {
            NSMutableArray *allProcessInstancesOfCurrentApp = [NSMutableArray array];
            
            for (ASDKMOProcessInstanceFilterMap *processInstanceFilterMap in processInstanceFilterMapArr) {
                [allProcessInstancesOfCurrentApp addObjectsFromArray:processInstanceFilterMap.processInstances.allObjects];
            }
            
            NSArray *sortedProcessInstances = [allProcessInstancesOfCurrentApp sortedArrayUsingDescriptors:@[[strongSelf sortDescriptorForFilter:filter]]];
            NSPredicate *namePredicate = [strongSelf namePredicateForFilter:filter];
            
            NSArray *matchingProcessInstanceArr = nil;
            if (namePredicate) {
                matchingProcessInstanceArr = [sortedProcessInstances filteredArrayUsingPredicate:namePredicate];
            } else {
                matchingProcessInstanceArr = sortedProcessInstances;
            }
            
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
    
    NSFetchRequest *oldProcessInstancesRequest = [ASDKMOProcessInstanceFilterMap fetchRequest];
    oldProcessInstancesRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
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

- (NSError *)saveProcessInstanceListAndGenerateFilterMap:(NSArray *)processInstanceList
                                               forFilter:(ASDKFilterRequestRepresentation *)filter
                                               inContext:(NSManagedObjectContext *)managedObjectContext {
    NSError *error = nil;
    NSArray *moProcessInstanceList = [ASDKProcessInstanceCacheModelUpsert upsertProcessInstanceListToCache:processInstanceList
                                                                                                     error:&error
                                                                                               inMOContext:managedObjectContext];
    if (error) {
        return error;
    }
    
    if (ASDKModelFilterStateTypeAll != filter.filterModel.state) {
        NSFetchRequest *processInstanceFilterMapFetchRequest = [ASDKMOProcessInstanceFilterMap fetchRequest];
        processInstanceFilterMapFetchRequest.predicate = [self filterMapMembershipPredicateForFilter:filter];
        NSArray *fetchResults = [managedObjectContext executeFetchRequest:processInstanceFilterMapFetchRequest
                                                                    error:&error];
        if (error) {
            return error;
        }
        
        ASDKMOProcessInstanceFilterMap *processInstanceFilterMap = fetchResults.firstObject;
        if (!processInstanceFilterMap) {
            processInstanceFilterMap = [NSEntityDescription insertNewObjectForEntityForName:[ASDKMOProcessInstanceFilterMap entityName]
                                                                     inManagedObjectContext:managedObjectContext];
        }
        [ASDKProcessInstanceFilterMapCacheMapper mapProcessInstanceList:moProcessInstanceList
                                                             withFilter:filter
                                                              toCacheMO:processInstanceFilterMap];
    }
    
    return nil;
}

- (void)cacheProcessInstanceDetails:(ASDKModelProcessInstance *)processInstance
                withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSError *error = nil;
        [ASDKProcessInstanceCacheModelUpsert upsertProcessInstanceToCache:processInstance
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

- (void)fetchProcesInstanceDetailsForID:(NSString *)processInstanceID
                    withCompletionBlock:(ASDKCacheServiceProcessInstanceDetailsCompletionBlock)completionBlock {
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        NSFetchRequest *fetchRequest = [ASDKMOProcessInstance fetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"modelID == %@", processInstanceID];
        
        NSError *error = nil;
        NSArray *fetchResults = [managedObjectContext executeFetchRequest:fetchRequest
                                                                    error:&error];
        
        if (completionBlock) {
            ASDKMOProcessInstance *moProcessInstance = fetchResults.firstObject;
            
            if (error || !moProcessInstance) {
                completionBlock(nil, error);
            } else {
                ASDKModelProcessInstance *processInstance = [ASDKProcessInstanceCacheMapper mapCacheMOToProcessInstance:moProcessInstance];
                completionBlock(processInstance, nil);
            }
        }
    }];
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

- (NSPredicate *)filterMapMembershipPredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    return [NSPredicate predicateWithFormat:@"applicationID == %@ && state == %ld", filter.appDefinitionID, filter.filterModel.state];
}

- (NSPredicate *)allFilterMapsOnCurrentApplicationForFilter:(ASDKFilterRequestRepresentation *)filter {
    return [NSPredicate predicateWithFormat:@"applicationID == %@", filter.appDefinitionID];
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
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startDate"
                                                         ascending:NO];
        }
            break;
        case ASDKModelFilterSortTypeCreatedAsc: {
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"startDate"
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
