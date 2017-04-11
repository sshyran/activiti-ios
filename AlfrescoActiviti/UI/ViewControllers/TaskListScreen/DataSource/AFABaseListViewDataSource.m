/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

#import "AFABaseListViewDataSource.h"
@import ActivitiSDK;

// Constants
#import "AFABusinessConstants.h"


@implementation AFABaseListViewDataSource


#pragma mark -
#pragma mark Public interface

- (instancetype)initWithDataEntries:(NSArray *)dataEntries
                         themeColor:(UIColor *)themeColor {
    // Override behaviour in subclasses
    self = [super init];
    return self;
}

- (NSArray *)processAdditionalEntries:(NSArray *)additionalEntriesArr
                   forExistingEntries:(NSArray *)existingEntriesArr
                               paging:(ASDKModelPaging *)paging {
    if (paging.start) {
        NSSet *existingEntriesSet = [[NSSet alloc] initWithArray:existingEntriesArr];
        NSSet *serverEntriesSet = [[NSSet alloc] initWithArray:additionalEntriesArr];
        
        // Make sure that the incoming data is not a subset of the existing collection
        if (![serverEntriesSet isSubsetOfSet:existingEntriesSet]) {
            NSMutableArray *serverEntriesArr = [NSMutableArray arrayWithArray:additionalEntriesArr];
            [serverEntriesArr removeObjectsInArray:existingEntriesArr];
            
            // If so, add it to the already existing content and return the updated collection
            NSMutableArray *additionedEntries = [NSMutableArray arrayWithArray:existingEntriesArr];
            [additionedEntries addObjectsFromArray:serverEntriesArr];
            
            additionalEntriesArr = additionedEntries;
        }
    }
    
    return additionalEntriesArr;
}

- (NSInteger)totalPagesForPaging:(ASDKModelPaging *)paging
                     dataEntries:(NSArray *)dataEntries {
    return ceilf((float) paging.pageCount / dataEntries.count);
}
- (NSInteger)preloadCellIndexForPaging:(ASDKModelPaging *)paging
                           dataEntries:(NSArray *)dataEntries {
    // Compute the preload index that will trigger a new request
    if ([self totalPagesForPaging:paging dataEntries:dataEntries] > 1) {
        return dataEntries.count - kTaskPreloadCellThreshold;
    } else {
        return 0;
    }
}

@end
