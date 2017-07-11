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

#import "ASDKProfileCacheServices.h"

// Models
#import "ASDKModelProfile.h"
#import "ASDKMOProfile.h"

// Persistence
#import "ASDKProfileCacheMapper.h"


@interface ASDKProfileCacheServices ()

@property (strong, nonatomic) ASDKProfileCacheMapper *profileCacheMapper;

@end

@implementation ASDKProfileCacheServices


#pragma mark -
#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _profileCacheMapper = [ASDKProfileCacheMapper new];
    }
    
    return self;
}

#pragma mark -
#pragma mark Public interface

- (void)cacheCurrentUserProfile:(ASDKModelProfile *)profile
            withCompletionBlock:(ASDKCacheServiceCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        managedObjectContext.automaticallyMergesChangesFromParent = YES;
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        // Unset other profiles as the default ones
        NSFetchRequest *fetchRequest = [ASDKMOProfile fetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isCurrentProfile == YES"];
        
        NSError *error = nil;
        NSArray *fetchResults = [managedObjectContext executeFetchRequest:fetchRequest
                                                                    error:&error];
        
        if (!error) {
            for (ASDKMOProfile *profile in fetchResults) {
                profile.isCurrentProfile = NO;
            }
        }
        
        ASDKMOProfile *currentUserProfile = [strongSelf.profileCacheMapper mapProfileToCacheMO:profile
                                                                                usingMOContext:managedObjectContext];
        currentUserProfile.isCurrentProfile = YES;
        
        [managedObjectContext save:&error];
        
        if (completionBlock) {
            completionBlock(error);
        }
    }];
}

- (void)fetchCurrentUserProfile:(ASDKCacheServiceProfileCompletionBlock)profileCompletionBlock {
    __weak typeof(self) weakSelf = self;
    [self.persistenceStack  performBackgroundTask:^(NSManagedObjectContext *managedObjectContext) {
        __strong typeof(self) strongSelf = weakSelf;
        
        NSFetchRequest *fetchRequest = [ASDKMOProfile fetchRequest];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isCurrentProfile == YES"];
        
        NSError *error = nil;
        NSArray *fetchResults = [managedObjectContext executeFetchRequest:fetchRequest
                                                                    error:&error];
        
        if (profileCompletionBlock) {
            ASDKMOProfile *moProfile = fetchResults.firstObject;
            
            if (error || !moProfile) {
                profileCompletionBlock(nil, error);
            } else {
                ASDKModelProfile *profile = [strongSelf.profileCacheMapper mapCacheMOToProfile:moProfile];
                profileCompletionBlock(profile, nil);
            }
        }
    }];
}

@end
