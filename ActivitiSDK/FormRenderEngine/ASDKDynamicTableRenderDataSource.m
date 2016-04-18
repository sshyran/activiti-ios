/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
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

#import "ASDKDynamicTableRenderDataSource.h"
#import "ASDKFormRenderDataSource.h"

// Constants
#import "ASDKLocalizationConstants.h"
#import "ASDKFormRenderEngineConstants.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormOutcome.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKDynamicTableRenderDataSource()

@end

@implementation ASDKDynamicTableRenderDataSource

#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithFormFields:(NSArray *)formFields
                    dataSourceType:(ASDKFormRenderEngineDataSourceType)dataSourceType {
    self = [super init];
    
    if (self) {
        self.visibleFormFields = [NSDictionary dictionaryWithObject:formFields
                                                             forKey:@(0)];
        self.formHasUserdefinedOutcomes = NO;
        self.dataSourceType = dataSourceType;
    }
    
    return self;
}

#pragma mark -
#pragma mark ASDKFormRenderEngine Protocol

- (NSInteger)numberOfSectionsForCurrentFormDescription {
    return [self.visibleFormFields.allKeys count];
}

- (NSInteger)numberOfFormFieldsForSection:(NSInteger)section {
    NSArray *sectionFormFields = self.visibleFormFields[@(section)];
    
    return sectionFormFields.count;
}

- (NSString *)sectionHeaderTitleForIndexPath:(NSIndexPath *)indexPath {
    NSString *sectionHeaderTitleString = nil;
    return sectionHeaderTitleString;
}

- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath {
    NSArray *sectionFormFields = self.visibleFormFields[@(indexPath.section)];
    NSString *cellIdentifier = nil;
    
    // Check if the controller requested a cell identifier for the outcome section
    if (sectionFormFields.count) {
        
        ASDKModelFormField *formFieldAtIndexPath = sectionFormFields[indexPath.row];
        cellIdentifier = [self validCellIdentifierForFormField:formFieldAtIndexPath];
    }
    
    return cellIdentifier;
}

- (ASDKModelBase *)modelForIndexPath:(NSIndexPath *)indexPath {
    NSArray *sectionFormFields = self.visibleFormFields[@(indexPath.section)];
    ASDKModelBase *formFieldModel = nil;
    
    if (sectionFormFields.count) {
        formFieldModel = sectionFormFields[indexPath.row];
    }
    
    return formFieldModel;
}

@end