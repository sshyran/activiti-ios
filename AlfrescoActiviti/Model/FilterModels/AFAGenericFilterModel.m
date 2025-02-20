/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import "AFAGenericFilterModel.h"

@interface AFAGenericFilterModel ()

@property (strong, nonatomic) NSDictionary *sortTypeStringMapping;

@end

@implementation AFAGenericFilterModel


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.sortType = AFAGenericFilterModelSortTypeUndefined;
        self.state = AFAGenericFilterStateTypeUndefined;
        self.assignmentType = AFAGenericFilterAssignmentTypeUndefined;
        
        self.sortTypeStringMapping = @{@(AFAGenericFilterModelSortTypeCreatedAsc)  : @"created-asc",
                                       @(AFAGenericFilterModelSortTypeCreatedDesc) : @"created-desc",
                                       @(AFAGenericFilterModelSortTypeDueAsc)      : @"due-asc",
                                       @(AFAGenericFilterModelSortTypeDueDesc)     : @"due-desc"};
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (NSString *)stringValueForSortType:(AFAGenericFilterModelSortType)sortType {
    return self.sortTypeStringMapping[@(sortType)];
}

@end
