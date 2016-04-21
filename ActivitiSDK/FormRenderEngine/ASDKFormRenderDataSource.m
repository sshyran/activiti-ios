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

#import "ASDKFormRenderDataSource.h"

// Constants
#import "ASDKLocalizationConstants.h"
#import "ASDKFormRenderEngineConstants.h"

// Protocols
#import "ASDKFormFieldDetailsControllerProtocol.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormDescription.h"
#import "ASDKModelFormOutcome.h"
#import "ASDKModelDynamicTableFormField.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKFormRenderDataSource()

/**
 *  Property meant to hold refference to form outcomes models.
 */
@property (strong, nonatomic) NSArray *formOutcomes;
/**
 *  Property meant to hold refference to the form outcomes index path
 *  objects.
 */
@property (strong, nonatomic) NSMutableArray *formOutcomesIndexPaths;

@end

@implementation ASDKFormRenderDataSource


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithFormDescription:(ASDKModelFormDescription *)formDescription
                         dataSourceType:(ASDKFormRenderEngineDataSourceType)dataSourceType {
    self = [super init];
    
    if (self) {
        self.visibleFormFields = [self parseVisibleFormFieldsFromContainerList:formDescription.formFields];
        self.formHasUserdefinedOutcomes = formDescription.formOutcomes.count ? YES : NO;
        self.formOutcomesIndexPaths = [NSMutableArray array];
        
        if (self.formHasUserdefinedOutcomes) {
            self.formOutcomes = formDescription.formOutcomes;
        } else {
            ASDKModelFormOutcome *formOutcome = [ASDKModelFormOutcome new];
            
            if (ASDKFormRenderEngineDataSourceTypeTask == dataSourceType) {
                formOutcome.name = ASDKLocalizedStringFromTable(kLocalizationDefaultFormOutcome, ASDKLocalizationTable, @"Default outcome");
            } else {
                formOutcome.name = ASDKLocalizedStringFromTable(kLocalizationStartProcessFormOutcome, ASDKLocalizationTable, @"Start process outcome");
            }
            
            self.dataSourceType = dataSourceType;
            self.formOutcomes = @[formOutcome];
        }
    }
    
    return self;
}


#pragma mark -
#pragma mark ASDKFormRenderEngine Protocol

- (NSInteger)numberOfSectionsForCurrentFormDescription {
    return [self.visibleFormFields.allKeys count] + 1; // Where 1 is the additional section for form outcomes
}

- (NSInteger)numberOfFormFieldsForSection:(NSInteger)section {
    ASDKModelFormField *sectionFormField = self.visibleFormFields[@(section)];
    NSUInteger fieldsCount = 0;
    
    // Check if the controller requested the number of fields for the outcome section
    if (!sectionFormField) {
        fieldsCount = self.formOutcomes.count;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField
               || (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType
                   && ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        fieldsCount = 1;
    } else {
        fieldsCount = sectionFormField.formFields.count;
    }
    
    return fieldsCount;
}

- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath {
    ASDKModelFormField *sectionFormField = self.visibleFormFields[@(indexPath.section)];
    NSString *cellIdentifier = nil;
    
    // Check if the controller requested a cell identifier for the outcome section
    if (!sectionFormField) {
        cellIdentifier = kASDKCellIDFormFieldOutcomeRepresentation;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField
               || (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType
                   && ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        cellIdentifier = [self validCellIdentifierForFormField:sectionFormField];
    } else {
        ASDKModelFormField *formFieldAtIndexPath = sectionFormField.formFields[indexPath.row];
        cellIdentifier = [self validCellIdentifierForFormField:formFieldAtIndexPath];
    }
    
    return cellIdentifier;
}

- (ASDKModelBase *)modelForIndexPath:(NSIndexPath *)indexPath {
    ASDKModelFormField *sectionFormField = self.visibleFormFields[@(indexPath.section)];
    ASDKModelBase *formFieldModel = nil;
    
    if (!sectionFormField) {
        ASDKModelFormOutcome *formOutcome = self.formOutcomes[indexPath.row];
        
        if (NSNotFound == [self.formOutcomesIndexPaths indexOfObject:indexPath]) {
            [self.formOutcomesIndexPaths addObject:indexPath];
        }
        
        formFieldModel = formOutcome;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField
               || (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType
                   && ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        formFieldModel = sectionFormField;
    } else {// Set up the cell from the corresponding section
        formFieldModel = [(ASDKModelFormField *)self.visibleFormFields[@(indexPath.section)] formFields][indexPath.row];
    }
    
    return formFieldModel;
}

- (NSString *)sectionHeaderTitleForIndexPath:(NSIndexPath *)indexPath {
    NSString *sectionHeaderTitleString = nil;
    ASDKModelFormField *sectionFormField = self.visibleFormFields[@(indexPath.section)];
    
    // We're checking for header representation types, we don't care for containers of
    // form field objects without a visual representation
    if (ASDKModelFormFieldRepresentationTypeHeader == sectionFormField.representationType) {
        sectionHeaderTitleString = sectionFormField.fieldName;
    }
    
    return sectionHeaderTitleString;
}

- (NSArray *)indexPathsOfFormOutcomes {
    return self.formOutcomesIndexPaths;
}

- (UIViewController *)childControllerForFormField:(ASDKModelFormField *)formField {
    UIStoryboard *formStoryboard = [UIStoryboard storyboardWithName:kASDKFormStoryboardBundleName
                                                             bundle:[NSBundle bundleForClass:[self class]]];
    NSString *controllerIdentifier = [self controllerIdentifierForFormField:formField];
    
    if (controllerIdentifier) {
        UIViewController<ASDKFormFieldDetailsControllerProtocol> *childControllerInstance = [formStoryboard instantiateViewControllerWithIdentifier:controllerIdentifier];
        if ([childControllerInstance respondsToSelector:@selector(setupWithFormFieldModel:)]) {
            [childControllerInstance setupWithFormFieldModel:formField];
        }
        
        return childControllerInstance;
    } else {
        return nil;
    }
}


#pragma mark -
#pragma mark Form parser methods

- (NSDictionary *)parseVisibleFormFieldsFromContainerList:(NSArray *)containerList {
    NSMutableDictionary *formFieldSections = [NSMutableDictionary dictionary];
    NSInteger section = -1;
    for (ASDKModelFormField *formField in containerList) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            section++;
            formField.formFields = [self filterSupportedFormFields:formField.formFields];
            [formFieldSections setObject:formField
                                  forKey:@(section)];
        } else if (ASDKModelFormFieldTypeDynamicTableField == formField.fieldType ||            // if dynamic table or display value dynamic table
                   (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType
                    && ASDKModelFormFieldRepresentationTypeDynamicTable == formField.formFieldParams.representationType)) {
            section++;
            [formFieldSections setObject:formField
                                  forKey:@(section)];
        }
    }
    
    return formFieldSections;
}


#pragma mark -
#pragma mark Form validation methods

- (NSString *)validCellIdentifierForFormField:(ASDKModelFormField *)formField {
    NSString *cellIdentifier = nil;
    NSInteger representationType = ASDKModelFormFieldRepresentationTypeUndefined;
    
    // If dealing with read-only forms extract the representation type from the attached
    // form field params model
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
        representationType = formField.formFieldParams.representationType;
    } else {
        representationType = formField.representationType;
    }
        
    switch (representationType) {
        case ASDKModelFormFieldRepresentationTypeText:
        case ASDKModelFormFieldRepresentationTypeNumerical:{
            cellIdentifier = kASDKCellIDFormFieldTextRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeBoolean: {
            cellIdentifier = kASDKCellIDFormFieldBooleanRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeAmount: {
            cellIdentifier = kASDKCellIDFormFieldAmountRepresentation;
        }
            break;
        
        case ASDKModelFormFieldRepresentationTypeDropdown:
        case ASDKModelFormFieldRepresentationTypeRadio: {
            cellIdentifier = kASDKCellIDFormFieldRadioRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDate: {
            cellIdentifier = kASDKCellIDFormFieldDateRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeHyperlink: {
            cellIdentifier = kASDKCellIDFormFieldHyperlinkRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeMultiline: {
            cellIdentifier = kASDKCellIDFormFieldMultilineRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeAttach: {
            cellIdentifier = kASDKCellIDFormFieldAttachRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypePeople: {
            cellIdentifier = kASDKCellIDFormFieldPeopleRepresentation;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDynamicTable: {
            cellIdentifier = kASDKCellIDFormFieldDynamicTableRepresentation;
        }
            break;
            
            
        default:
            break;
    }
    
    return cellIdentifier;
}

- (NSString *)controllerIdentifierForFormField:(ASDKModelFormField *)formField {
    NSString *controllerIdentifierString = nil;
    NSInteger representationType = ASDKModelFormFieldRepresentationTypeUndefined;
    
    // completed forms; only attach fields have child view controller
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType
        && (ASDKModelFormFieldRepresentationTypeAttach == formField.formFieldParams.representationType
            || ASDKModelFormFieldRepresentationTypeMultiline == formField.formFieldParams.representationType
            || ASDKModelFormFieldRepresentationTypeDynamicTable == formField.formFieldParams.representationType)) {
        representationType = formField.formFieldParams.representationType;
    } else if (ASDKModelFormFieldRepresentationTypeReadOnly != formField.representationType) {
        representationType = formField.representationType;
    }
    
    switch (representationType) {
        case ASDKModelFormFieldRepresentationTypeDropdown:
        case ASDKModelFormFieldRepresentationTypeRadio: {
            controllerIdentifierString = kASDKStoryboardIDRadioFormFieldDetailController;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDate: {
            controllerIdentifierString = kASDKStoryboardIDDateFormFieldDetailController;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeMultiline: {
            controllerIdentifierString = kASDKStoryboardIDMultilineFormFieldDetailController;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeAttach: {
            controllerIdentifierString = kASDKStoryboardIDAttachFormFieldDetailController;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypePeople: {
            controllerIdentifierString = kASDKStoryboardIDPeopleFormFieldDetailController;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDynamicTable: {
            controllerIdentifierString = kASDKStoryboardIDDynamicTableFormFieldDetailController;
        }
            break;
            
        default:
            break;
    }
    
    return controllerIdentifierString;
}

- (NSArray *)filterSupportedFormFields:(NSArray *)formFieldsArr {
    NSMutableArray *supportedFormFields = [NSMutableArray array];
    
    for (ASDKModelFormField *formField in formFieldsArr) {
        if ([self validCellIdentifierForFormField:formField])
            [supportedFormFields addObject:formField];
    }
    
    return supportedFormFields;
}

- (BOOL)areFormFieldMetadataValuesValid {
    BOOL formFieldsAreValid = YES;
    
    // Check if mandatory form field values had been addressed
    for (NSNumber *sectionCount in self.visibleFormFields.allKeys) {
        NSArray *associatedFormFields = nil;
        
        if ([self.visibleFormFields[sectionCount] isKindOfClass:ASDKModelDynamicTableFormField.class]) { // Extract formfields from dynamic table
            NSMutableArray *dynamicTableFormFields = [NSMutableArray new];
            
            // add the dynamic table it self
            [dynamicTableFormFields addObject:self.visibleFormFields[sectionCount]];
            
            for (NSArray *dynamicTableRow in [self.visibleFormFields[sectionCount] values]) {
                [dynamicTableFormFields addObjectsFromArray:dynamicTableRow];
            }
            
            associatedFormFields = [dynamicTableFormFields copy];
        } else { // Extract the form fields for the correspondent container
            associatedFormFields = [self.visibleFormFields[sectionCount] formFields];
        }
        
        // Enumerate through the associated form fields and check if they
        // have a value or attached metadata values 
        for (ASDKModelFormField *formField in associatedFormFields) {
            if (formField.isRequired) {
                if (formField.representationType == ASDKModelFormFieldRepresentationTypeBoolean) {
                    BOOL checked = NO;
                    if (formField.metadataValue.attachedValue.length) {
                        checked = [formField.metadataValue.attachedValue isEqualToString:kASDKFormFieldTrueStringValue] ? YES : NO;
                    } else if (formField.values) {
                        checked = [formField.values.firstObject boolValue];
                    }
                
                    if (!checked) {
                        formFieldsAreValid = NO;
                        break;
                    }
                } else if (!formField.values.count && !formField.metadataValue.attachedValue.length && !formField.metadataValue.option.attachedValue.length) {
                    formFieldsAreValid = NO;
                    break;
                }
            }
        }
    }
    
    return formFieldsAreValid;
}


@end
