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

#import "ASDKFormCacheService.h"

// Constants
#import "ASDKPersistenceStackConstants.h"

// Models
#import "ASDKMOFormFieldOptionMap.h"
#import "ASDKMOFormFieldOption.h"

// Model upsert
#import "ASDKFormFieldOptionCacheModelUpsert.h"

// Mappers
#import "ASDKFormFieldOptionMapCacheMapper.h"
#import "ASDKFormFieldOptionCacheMapper.h"

@implementation ASDKFormCacheService


#pragma mark -
#pragma mark Public interface

- (void)cacheRestFieldValues:(NSArray *)restFieldValues
                   forTaskID:(NSString *)taskID
             withFormFieldID:(NSString *)fieldID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSError *error = [strongSelf cleanStalledRestFieldValuesInContext:managedObjectContext
                                                             forPredicate:[self restFieldValuesPredicateForTaskID:taskID
                                                                                                      formFieldID:fieldID]];
        if (!error) {
            error = [strongSelf saveRestFieldValuesAndGenerateFormFieldOptionMap:restFieldValues
                                                                       forTaskID:taskID
                                                                 withFormFieldID:fieldID
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

- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID
                  withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock {
    [self fetchRestFieldValuesWithPredicate:[self restFieldValuesPredicateForTaskID:taskID
                                                                              formFieldID:fieldID]
                        withCompletionBlock:completionBlock];
}

- (void)cacheRestFieldValues:(NSArray *)restFieldValues
      forProcessDefinitionID:(NSString *)processDefinitionID
             withFormFieldID:(NSString *)fieldID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSError *error = [strongSelf cleanStalledRestFieldValuesInContext:managedObjectContext
                                                             forPredicate:[self restFieldValuesPredicateForProcessDefinitionID:processDefinitionID
                                                                                                                   formFieldID:fieldID]];
        if (!error) {
            error = [strongSelf saveRestFieldValuesAndGenerateFormFieldOptionMap:restFieldValues
                                                          forProcessDefinitionID:processDefinitionID
                                                                 withFormFieldID:fieldID
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

- (void)fetchRestFieldValuesForProcessDefinitionID:(NSString *)processDefinitionID
                                   withFormFieldID:(NSString *)fieldID
                               withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock {
    [self fetchRestFieldValuesWithPredicate:[self restFieldValuesPredicateForProcessDefinitionID:processDefinitionID
                                                                                     formFieldID:fieldID]
                        withCompletionBlock:completionBlock];
}

- (void)cacheRestFieldValues:(NSArray *)restFieldValues
                   forTaskID:(NSString *)taskID
             withFormFieldID:(NSString *)fieldID
                withColumnID:(NSString *)columnID
         withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        NSError *error = [strongSelf cleanStalledRestFieldValuesInContext:managedObjectContext
                                                             forPredicate:[self restFieldValuesPredicateForTaskID:taskID
                                                                                                      formFieldID:fieldID
                                                                                                         columnID:columnID]];
        if (!error) {
            error = [strongSelf saveRestFieldValuesAndGenerateFormFieldOptionMap:restFieldValues
                                                                       forTaskID:taskID
                                                                 withFormFieldID:fieldID
                                                                    withColumnID:columnID
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

- (void)fetchRestFieldValuesForTaskID:(NSString *)taskID
                      withFormFieldID:(NSString *)fieldID
                         withColumnID:(NSString *)columnID
                  withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock {
    [self fetchRestFieldValuesWithPredicate:[self restFieldValuesPredicateForTaskID:taskID
                                                                        formFieldID:fieldID
                                                                           columnID:columnID]
                        withCompletionBlock:completionBlock];

}


#pragma mark -
#pragma mark Operations

- (NSError *)cleanStalledRestFieldValuesInContext:(NSManagedObjectContext *)managedObjectContext
                                     forPredicate:(NSPredicate *)predicate {
    NSError *internalError = nil;
    NSFetchRequest *oldRestFieldValuesRequest = [ASDKMOFormFieldOptionMap fetchRequest];
    oldRestFieldValuesRequest.predicate = predicate;
    oldRestFieldValuesRequest.resultType = NSManagedObjectIDResultType;
    
    NSBatchDeleteRequest *removeOldRestFieldValuesRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:oldRestFieldValuesRequest];
    removeOldRestFieldValuesRequest.resultType = NSBatchDeleteResultTypeObjectIDs;
    NSBatchDeleteResult *removeOldRestFieldValuesResult = [managedObjectContext executeRequest:removeOldRestFieldValuesRequest
                                                                                         error:&internalError];
    NSArray *moIDArr = removeOldRestFieldValuesResult.result;
    [NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSDeletedObjectsKey : moIDArr}
                                                 intoContexts:@[managedObjectContext]];
    if (internalError) {
        return [self clearCacheStalledDataError];
    }
    
    return nil;
}

- (void)fetchRestFieldValuesWithPredicate:(NSPredicate *)predicate
                      withCompletionBlock:(ASDKCacheServiceTaskRestFieldValuesCompletionBlock)completionBlock {
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        NSError *error = nil;
        NSArray *matchingRestFieldValueArr = nil;
        
        NSFetchRequest *formFieldOptionMapRequest = [ASDKMOFormFieldOptionMap fetchRequest];
        formFieldOptionMapRequest.predicate = predicate;
        NSArray *formFieldOptionMapArr = [managedObjectContext executeFetchRequest:formFieldOptionMapRequest
                                                                             error:&error];
        if (!error) {
            ASDKMOFormFieldOptionMap *formFieldOptionMap = formFieldOptionMapArr.firstObject;
            matchingRestFieldValueArr = [formFieldOptionMap.restFieldValueList allObjects];
        }
        
        if (completionBlock) {
            if (error || !matchingRestFieldValueArr.count) {
                completionBlock(nil, error);
            } else {
                NSMutableArray *restFieldValues = [NSMutableArray array];
                for (ASDKMOFormFieldOption *moFormFieldOption in matchingRestFieldValueArr) {
                    ASDKModelFormFieldOption *formFieldOption = [ASDKFormFieldOptionCacheMapper mapCacheMOToFormFieldOption:moFormFieldOption];
                    [restFieldValues addObject:formFieldOption];
                }
                
                completionBlock(restFieldValues, nil);
            }
        }
    }];
}

- (NSError *)saveRestFieldValuesAndGenerateFormFieldOptionMap:(NSArray *)formFieldOptionList
                                                    forTaskID:(NSString *)taskID
                                              withFormFieldID:(NSString *)fieldID
                                                    inContext:(NSManagedObjectContext *)managedObjectContext {
    // Upsert rest field values
    NSError *error = nil;
    NSArray *moFormFieldOptionList = [ASDKFormFieldOptionCacheModelUpsert upsertFormFieldOptionListToCache:formFieldOptionList
                                                                                                     error:&error
                                                                                               inMOContext:managedObjectContext];
    if (error) {
        return error;
    }
    
    // Fetch existing or create form field option map
    NSFetchRequest *formFieldOptionMapRequest = [ASDKMOFormFieldOptionMap fetchRequest];
    formFieldOptionMapRequest.predicate = [self restFieldValuesPredicateForTaskID:taskID
                                                                      formFieldID:fieldID];
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:formFieldOptionMapRequest
                                                                error:&error];
    if (error) {
        return error;
    }
    
    ASDKMOFormFieldOptionMap *formFieldOptionMap = fetchResults.firstObject;
    if (!formFieldOptionMap) {
        formFieldOptionMap = [NSEntityDescription insertNewObjectForEntityForName:[ASDKMOFormFieldOptionMap entityName]
                                                           inManagedObjectContext:managedObjectContext];
    }
    
    [ASDKFormFieldOptionMapCacheMapper mapRestFieldValueList:moFormFieldOptionList
                                                   forTaskID:taskID
                                             withFormFieldID:fieldID
                                                   toCacheMO:formFieldOptionMap];
    
    return nil;
}

- (NSError *)saveRestFieldValuesAndGenerateFormFieldOptionMap:(NSArray *)formFieldOptionList
                                       forProcessDefinitionID:(NSString *)processDefinitionID
                                              withFormFieldID:(NSString *)fieldID
                                                    inContext:(NSManagedObjectContext *)managedObjectContext {
    // Upsert rest field values
    NSError *error = nil;
    NSArray *moFormFieldOptionList = [ASDKFormFieldOptionCacheModelUpsert upsertFormFieldOptionListToCache:formFieldOptionList
                                                                                                     error:&error
                                                                                               inMOContext:managedObjectContext];
    if (error) {
        return error;
    }
    
    // Fetch existing or create form field option map
    NSFetchRequest *formFieldOptionMapRequest = [ASDKMOFormFieldOptionMap fetchRequest];
    formFieldOptionMapRequest.predicate = [self restFieldValuesPredicateForProcessDefinitionID:processDefinitionID
                                                                                   formFieldID:fieldID];
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:formFieldOptionMapRequest
                                                                error:&error];
    if (error) {
        return error;
    }
    
    ASDKMOFormFieldOptionMap *formFieldOptionMap = fetchResults.firstObject;
    if (!formFieldOptionMap) {
        formFieldOptionMap = [NSEntityDescription insertNewObjectForEntityForName:[ASDKMOFormFieldOptionMap entityName]
                                                           inManagedObjectContext:managedObjectContext];
    }
    
    [ASDKFormFieldOptionMapCacheMapper mapRestFieldValueList:moFormFieldOptionList
                                      forProcessDefinitionID:processDefinitionID
                                             withFormFieldID:fieldID
                                                   toCacheMO:formFieldOptionMap];
    
    return nil;
}

- (NSError *)saveRestFieldValuesAndGenerateFormFieldOptionMap:(NSArray *)formFieldOptionList
                                                    forTaskID:(NSString *)taskID
                                              withFormFieldID:(NSString *)fieldID
                                                 withColumnID:(NSString *)columnID
                                                    inContext:(NSManagedObjectContext *)managedObjectContext {
    // Upsert rest field values
    NSError *error = nil;
    NSArray *moFormFieldOptionList = [ASDKFormFieldOptionCacheModelUpsert upsertFormFieldOptionListToCache:formFieldOptionList
                                                                                                     error:&error
                                                                                               inMOContext:managedObjectContext];
    if (error) {
        return error;
    }
    
    // Fetch existing or create form field option map
    NSFetchRequest *formFieldOptionMapRequest = [ASDKMOFormFieldOptionMap fetchRequest];
    formFieldOptionMapRequest.predicate = [self restFieldValuesPredicateForTaskID:taskID
                                                                      formFieldID:fieldID
                                                                         columnID:columnID];
    NSArray *fetchResults = [managedObjectContext executeFetchRequest:formFieldOptionMapRequest
                                                                error:&error];
    if (error) {
        return error;
    }
    
    ASDKMOFormFieldOptionMap *formFieldOptionMap = fetchResults.firstObject;
    if (!formFieldOptionMap) {
        formFieldOptionMap = [NSEntityDescription insertNewObjectForEntityForName:[ASDKMOFormFieldOptionMap entityName]
                                                           inManagedObjectContext:managedObjectContext];
    }
    
    [ASDKFormFieldOptionMapCacheMapper mapRestFieldValueList:moFormFieldOptionList
                                                   forTaskID:taskID
                                             withFormFieldID:fieldID
                                                withColumnID:columnID
                                                   toCacheMO:formFieldOptionMap];
    
    return nil;
}


#pragma mark -
#pragma mark Predicate construction

- (NSPredicate *)restFieldValuesPredicateForTaskID:(NSString *)taskID
                                       formFieldID:(NSString *)formFieldID {
    if (!taskID.length || !formFieldID.length) {
        return nil;
    } else {
        return [NSPredicate predicateWithFormat:@"taskID == %@ && formFieldID == %@", taskID, formFieldID];
    }
}

- (NSPredicate *)restFieldValuesPredicateForProcessDefinitionID:(NSString *)processDefinitionID
                                                    formFieldID:(NSString *)formFieldID {
    if (!processDefinitionID.length || !formFieldID.length) {
        return nil;
    } else {
        return [NSPredicate predicateWithFormat:@"processDefinitionID == %@ && formFieldID == %@", processDefinitionID, formFieldID];
    }
}

- (NSPredicate *)restFieldValuesPredicateForTaskID:(NSString *)taskID
                                       formFieldID:(NSString *)formFieldID
                                          columnID:(NSString *)columnID {
    if (!taskID.length || formFieldID.length || columnID.length) {
        return nil;
    } else {
        return [NSPredicate predicateWithFormat:@"taskID == %@ && formFieldID == %@ && columnID == %@", taskID, formFieldID, columnID];
    }
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
