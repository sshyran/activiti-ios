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

// Models
#import "ASDKFilterRequestRepresentation.h"
#import "ASDKModelTask.h"
#import "ASDKMOTask.h"
#import "ASDKModelFilter.h"

// Persistence
#import "ASDKTaskCacheMapper.h"

@interface ASDKTaskCacheService ()

@property (strong, nonatomic) ASDKTaskCacheMapper *taskCacheMapper;

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
        
        NSError *error = nil;
        
        // When fetching the first page of tasks for a specific application
        // remove all references
        if (!filter.page) {
            NSFetchRequest *oldTasksFetchRequest = [ASDKMOTask fetchRequest];
            oldTasksFetchRequest.predicate = [self applicationMembershipPredicateForFilter:filter];
            
            NSBatchDeleteRequest *removeOldTasksRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldTasksFetchRequest];
            removeOldTasksRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
            
            NSBatchDeleteResult *deletionResult = [managedObjectContext executeRequest:removeOldTasksRequest
                                                                                 error:&error];
            NSArray *moIDArr = deletionResult.result;
            [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey : moIDArr}
                                                         intoContexts:@[managedObjectContext]];
        }
        
        if (!error) {
            for (ASDKModelTask *task in taskList) {
                [strongSelf.taskCacheMapper mapTaskToCacheMO:task
                                              usingMOContext:managedObjectContext];
            }
            
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
        
        NSFetchRequest *fetchRequest = [ASDKMOTask fetchRequest];
        
        // Compute fetch predicate based on the passed filter
        NSPredicate *applicationMembershipPredicate = [self applicationMembershipPredicateForFilter:filter];
        
        
        NSError *error = nil;
        NSMutableArray *tasks = [NSMutableArray array];
        
#warning revise paging info
        if (completionBlock) {
            if (error || !tasks.count) {
                completionBlock(nil, error, nil);
            } else {
                completionBlock(tasks, nil, nil);
            }
        }
    }];
}


#pragma mark -
#pragma mark Utils

- (NSPredicate *)applicationMembershipPredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    return [NSPredicate predicateWithFormat:@"processDefinitionDeploymentID == %@ || category == %@",
            filter.appDeploymentID,
            filter.appDefinitionID];
}

- (NSPredicate *)taskStatePredicateForFilter:(ASDKFilterRequestRepresentation *)filter {
    return [NSPredicate predicateWithFormat:@""];
}

@end
