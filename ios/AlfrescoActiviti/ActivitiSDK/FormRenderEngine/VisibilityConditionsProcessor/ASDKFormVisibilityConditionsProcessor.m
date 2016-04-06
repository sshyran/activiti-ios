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

#import "ASDKFormVisibilityConditionsProcessor.h"

// Models
#import "ASDKModelFormVisibilityCondition.h"
#import "ASDKModelFormField.h"

@interface ASDKFormVisibilityConditionsProcessor ()

/**
 *  Property meant to hold a refference to all the form fields the form engine 
 *  should render
 */
@property (strong, nonatomic) NSArray *formFields;

/**
 *  Property meant to hold a refference to a dictionary structure where the key
 *  is represented by the affected field and the value is an array of fields 
 *  that affect it. This will be used to identify the affected field when another
 *  field changes and that operation could impact visibility.
 */
@property (strong, nonatomic) NSMutableDictionary *dependencyDict;

@end

@implementation ASDKFormVisibilityConditionsProcessor


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithFormFields:(NSArray *)formFieldArr {
    self = [super init];
    
    if (self) {
        self.formFields = formFieldArr;
        self.dependencyDict = [self createFormFieldDependencyDictionaryForList:formFieldArr];
    }
    
    return self;
}


#pragma mark -
#pragma mark Parser methods

- (NSMutableDictionary *)createFormFieldDependencyDictionaryForList:(NSArray *)formFields {
    NSMutableDictionary *dependencyDict = [NSMutableDictionary dictionary];
    
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"visibilityCondition != nil"];
    NSArray *formFieldsWithVisibilityConditions = [formFields filteredArrayUsingPredicate:searchPredicate];
    
    for (ASDKModelFormField *formField in formFieldsWithVisibilityConditions) {
        NSMutableArray *influentialFormFieldsForCurrentFormField = [NSMutableArray array];
        
        [self parseFormFieldIDsFromVisibilityCondition:formField.visibilityCondition
                                               toArray:&influentialFormFieldsForCurrentFormField];
    }
    
    return dependencyDict;
}

- (void)parseFormFieldIDsFromVisibilityCondition:(ASDKModelFormVisibilityCondition *)formVisibilityCondition
                                         toArray:(NSMutableArray **)influentialFormFields {
    // If left and / or right form field ID properties aren't emtpy then
    // add the coresponding form field in the influential array of form fields
    if (formVisibilityCondition.leftFormFieldID.length) {
        [*influentialFormFields addObject:[self formFieldForID:formVisibilityCondition.leftFormFieldID]];
    }
    
    if (formVisibilityCondition.rightFormFieldID.length) {
        [*influentialFormFields addObject:[self formFieldForID:formVisibilityCondition.rightFormFieldID]];
    }
    
    [self parseFormFieldIDsFromVisibilityCondition:formVisibilityCondition.nextCondition
                                           toArray:influentialFormFields];
}

- (ASDKModelFormField *)formFieldForID:(NSString *)formFieldID {
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"SELF.instanceID == %@", formFieldID];
    NSArray *formFields = [self.formFields filteredArrayUsingPredicate:searchPredicate];
    
    return formFields.firstObject;
}

@end
