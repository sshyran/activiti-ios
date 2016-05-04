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
#import "ASDKLogConfiguration.h"

// Protocols
#import "ASDKFormFieldDetailsControllerProtocol.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormDescription.h"
#import "ASDKModelFormOutcome.h"
#import "ASDKModelDynamicTableFormField.h"

// Managers
#import "ASDKFormVisibilityConditionsProcessor.h"
#import "ASDKKVOManager.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKFormRenderDataSource()

/**
 *  Property meant to hold reference to form outcomes models.
 */
@property (strong, nonatomic) NSArray *formOutcomes;
/**
 *  Property meant to hold reference to the form outcomes index path
 *  objects.
 */
@property (strong, nonatomic) NSMutableArray *formOutcomesIndexPaths;

/**
 *  Property meant to hold a reference to a KVO manager that will be monitoring 
 *  the state of form field objects
 */
@property (strong, nonatomic) ASDKKVOManager *kvoManager;

@end

@implementation ASDKFormRenderDataSource


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithFormDescription:(ASDKModelFormDescription *)formDescription
                         dataSourceType:(ASDKFormRenderEngineDataSourceType)dataSourceType {
    self = [super init];
    
    if (self) {
        // Prepare the KVO manager to handle visibility conditions re-evaluations
        self.kvoManager = [ASDKKVOManager managerWithObserver:self];
        
        // Parse the renderable form fields from the form description to a section disposed dictionary
        self.renderableFormFields = [self parseRenderableFormFieldsFromContainerList:formDescription.formFields];
        
        // Deep copy all renderable objects so that the initial collection remains
        // untouched by future mutations of sections and sub-section elements
        NSData *buffer = [NSKeyedArchiver archivedDataWithRootObject: self.renderableFormFields];
        NSArray *renderableFormFieldsCopy = [NSKeyedUnarchiver unarchiveObjectWithData: buffer];
        
        // Initialize the visibility condition processor with a plain array of form fields and form variables
        self.visibilityConditionsProcessor = [[ASDKFormVisibilityConditionsProcessor alloc] initWithFormFields:renderableFormFieldsCopy
                                                                                                 formVariables:formDescription.formVariables];
        
        // Run a pre-process operation to evaluate visibility conditions and provide the first set of visible form
        // fields
        self.visibleFormFields = [self filterRenderableFormFields:renderableFormFieldsCopy
                                             forVisibleFormFields:[self.visibilityConditionsProcessor parseVisibleFormFields]];
        
        // Handle value changes for form fields that have a direct impact over visibility conditions
        [self registerVisibilityHandlersForInfluencialFormFields:[self.visibilityConditionsProcessor visibilityInfluentialFormFields]];
        
        // Handle form outcomes
        self.formHasUserdefinedOutcomes = formDescription.formOutcomes.count ? YES : NO;
        self.formOutcomesIndexPaths = [NSMutableArray array];

        // Add the save form button. This will be filtered out if the isReadOnlyForm is
        // marked as being true
        ASDKModelFormOutcome *saveFormOutcome = [ASDKModelFormOutcome new];
        saveFormOutcome.name =  ASDKLocalizedStringFromTable(kLocalizationSaveFormOutcome, ASDKLocalizationTable, @"Save outcome");
        saveFormOutcome.formOutcomeType = ASDKModelFormOutcomeTypeSave;
        
        if (self.formHasUserdefinedOutcomes) {
            self.formOutcomes = [formDescription.formOutcomes arrayByAddingObject:saveFormOutcome];
        } else {
            ASDKModelFormOutcome *formOutcome = [ASDKModelFormOutcome new];
            
            if (ASDKFormRenderEngineDataSourceTypeTask == dataSourceType) {
                formOutcome.name = ASDKLocalizedStringFromTable(kLocalizationDefaultFormOutcome, ASDKLocalizationTable, @"Default outcome");
                self.formOutcomes = @[formOutcome, saveFormOutcome];
            } else {
                formOutcome.name = ASDKLocalizedStringFromTable(kLocalizationStartProcessFormOutcome, ASDKLocalizationTable, @"Start process outcome");
                self.formOutcomes = @[formOutcome];
            }
            
            self.dataSourceType = dataSourceType;
        }
    }
    
    return self;
}

- (void)setIsReadOnlyForm:(BOOL)isReadOnlyForm {
    if (isReadOnlyForm != _isReadOnlyForm) {
        _isReadOnlyForm = isReadOnlyForm;
        
        // If we're dealing with a read-only form remove the save form outcome
        if (_isReadOnlyForm) {
            NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"formOutcomeType == %d", ASDKModelFormOutcomeTypeComplete];
            _formOutcomes = [_formOutcomes filteredArrayUsingPredicate:searchPredicate];
        }
    }
}


#pragma mark -
#pragma mark ASDKFormRenderEngine Protocol

- (NSInteger)numberOfSectionsForCurrentFormDescription {
    return self.visibleFormFields.count + 1; // Where 1 is the additional section for form outcomes
}

- (NSInteger)numberOfFormFieldsForSection:(NSInteger)section {
    ASDKModelFormField *sectionFormField = section < self.visibleFormFields.count ? self.visibleFormFields[section] : nil;
    NSUInteger fieldsCount = 0;
    
    // Check if the controller requested the number of fields for the outcome section
    if (!sectionFormField) {
        fieldsCount = self.formOutcomes.count;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField ||
               (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType &&
                ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        fieldsCount = 1;
    } else {
        fieldsCount = sectionFormField.formFields.count;
    }
    
    return fieldsCount;
}

- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath {
    ASDKModelFormField *sectionFormField = indexPath.section < self.visibleFormFields.count ? self.visibleFormFields[indexPath.section] : nil;
    NSString *cellIdentifier = nil;
    
    // Check if the controller requested a cell identifier for the outcome section
    if (!sectionFormField) {
        cellIdentifier = kASDKCellIDFormFieldOutcomeRepresentation;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField ||
               (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType &&
                ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        cellIdentifier = [self validCellIdentifierForFormField:sectionFormField];
    } else {
        ASDKModelFormField *formFieldAtIndexPath = sectionFormField.formFields[indexPath.row];
        cellIdentifier = [self validCellIdentifierForFormField:formFieldAtIndexPath];
    }
    
    return cellIdentifier;
}

- (ASDKModelBase *)modelForIndexPath:(NSIndexPath *)indexPath {
    ASDKModelFormField *sectionFormField = indexPath.section < self.visibleFormFields.count ? self.visibleFormFields[indexPath.section] : nil;
    ASDKModelBase *formFieldModel = nil;
    
    if (!sectionFormField) {
        ASDKModelFormOutcome *formOutcome = self.formOutcomes[indexPath.row];
        
        if (NSNotFound == [self.formOutcomesIndexPaths indexOfObject:indexPath]) {
            [self.formOutcomesIndexPaths addObject:indexPath];
        }
        
        formFieldModel = formOutcome;
    } else if (sectionFormField.fieldType == ASDKModelFormFieldTypeDynamicTableField ||
               (ASDKModelFormFieldRepresentationTypeReadOnly == sectionFormField.representationType &&
                ASDKModelFormFieldRepresentationTypeDynamicTable == sectionFormField.formFieldParams.representationType)) {
        formFieldModel = sectionFormField;
    } else {// Set up the cell from the corresponding section
        formFieldModel = [(ASDKModelFormField *)self.visibleFormFields[indexPath.section] formFields][indexPath.row];
    }
    
    return formFieldModel;
}

- (NSString *)sectionHeaderTitleForIndexPath:(NSIndexPath *)indexPath {
    NSString *sectionHeaderTitleString = nil;
    ASDKModelFormField *sectionFormField = indexPath.section < self.visibleFormFields.count ? self.visibleFormFields[indexPath.section] : nil;
    
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

- (NSArray *)parseRenderableFormFieldsFromContainerList:(NSArray *)containerList {
    NSMutableArray *formFieldSections = [NSMutableArray array];
    for (ASDKModelFormField *formField in containerList) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            formField.formFields = [self filterSupportedFormFields:formField.formFields];
            [formFieldSections addObject:formField];
        } else if (ASDKModelFormFieldTypeDynamicTableField == formField.fieldType ||
                   // if dynamic table or display value dynamic table
                   (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType &&
                    ASDKModelFormFieldRepresentationTypeDynamicTable == formField.formFieldParams.representationType)) {
                       [formFieldSections addObject:formField];
                   }
    }
    
    return formFieldSections;
}

- (NSArray *)filterRenderableFormFields:(NSArray *)renderableFormFields
                   forVisibleFormFields:(NSArray *)visibleFormFields {
    NSMutableArray *filteredArr = [NSMutableArray arrayWithArray:renderableFormFields];
    NSMutableIndexSet *sectionsToBeRemoved = [NSMutableIndexSet indexSet];
    
    for (int section = 0; section < filteredArr.count; section++) {
        ASDKModelFormField *containerFormField = (ASDKModelFormField *)filteredArr[section];
        
        // Check first if the section altogether is visible
        if (![visibleFormFields containsObject:containerFormField]) {
            [sectionsToBeRemoved addIndex:section];
            continue;
        }
        
        NSMutableArray *formFieldsInSection = [NSMutableArray arrayWithArray:containerFormField.formFields];
        NSMutableArray *fieldsToBeRemoved = [NSMutableArray array];
        
        // Iterate over the list of form fields and remove the ones that are not inside
        // the visible form fields array
        for (ASDKModelFormField *formField in formFieldsInSection) {
            if (![visibleFormFields containsObject:formField]) {
                [fieldsToBeRemoved addObject:formField];
            }
        }
        [formFieldsInSection removeObjectsInArray:fieldsToBeRemoved];
        
        // If a section has no more attached form fields and it's not a dynamic table remove it,
        // otherwise set the modified form field collection
        
        BOOL isReadOnlyDynamicTable = (ASDKModelFormFieldRepresentationTypeReadOnly == containerFormField.representationType &&
                                       ASDKModelFormFieldRepresentationTypeDynamicTable == containerFormField.formFieldParams.representationType);
        if (!formFieldsInSection.count &&
            (ASDKModelFormFieldTypeDynamicTableField != containerFormField.fieldType &&
             !isReadOnlyDynamicTable)) {
            [sectionsToBeRemoved addIndex:section];
        } else {
            containerFormField.formFields = formFieldsInSection;
        }
    }
    
    [filteredArr removeObjectsAtIndexes:sectionsToBeRemoved];
    
    return filteredArr;
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
            
        case ASDKModelFormFieldRepresentationTypeMultiline:
        case ASDKModelFormFieldRepresentationTypeReadonlyText: {
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
    
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType &&
        (ASDKModelFormFieldRepresentationTypeAttach == formField.formFieldParams.representationType ||
         ASDKModelFormFieldRepresentationTypeMultiline == formField.formFieldParams.representationType ||
         ASDKModelFormFieldRepresentationTypeDynamicTable == formField.formFieldParams.representationType)) {
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
            
        case ASDKModelFormFieldRepresentationTypeMultiline:
        case ASDKModelFormFieldRepresentationTypeReadonlyText: {
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
    for (ASDKModelFormField *sectionFormField in self.visibleFormFields) {
        NSArray *associatedFormFields = nil;
        
        if ([sectionFormField isKindOfClass:ASDKModelDynamicTableFormField.class]) { // Extract formfields from dynamic table
            NSMutableArray *dynamicTableFormFields = [NSMutableArray new];
            
            // Add the dynamic table itself
            [dynamicTableFormFields addObject:sectionFormField];
            
            for (NSArray *dynamicTableRow in sectionFormField.values) {
                [dynamicTableFormFields addObjectsFromArray:dynamicTableRow];
            }
            
            associatedFormFields = [dynamicTableFormFields copy];
        } else { // Extract the form fields for the correspondent container
            associatedFormFields = sectionFormField.formFields;
        }
        
        // Enumerate through the associated form fields and check if they
        // have a value or attached metadata values 
        for (ASDKModelFormField *formField in sectionFormField.formFields) {
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


#pragma mark -
#pragma mark Visibility handler methods

- (void)registerVisibilityHandlersForInfluencialFormFields:(NSSet *)influencialFormFields {
    for (ASDKModelFormField *influencialFormField in influencialFormFields) {
        __weak typeof(self) weakSelf = self;
        
        [self.kvoManager observeObject:influencialFormField
                            forKeyPath:NSStringFromSelector(@selector(metadataValue))
                               options:NSKeyValueObservingOptionNew
                                 block:^(id observer, id object, NSDictionary *change) {
                                     __strong typeof(self) strongSelf = weakSelf;
                                     [strongSelf handleVisibilityChangeForFormField:(ASDKModelFormField *)object];
                                 }];
    }
}

- (void)handleVisibilityChangeForFormField:(ASDKModelFormField *)formField {
    // Reevaluate visibility conditions
    NSDictionary *visibilityActionsDict = [self.visibilityConditionsProcessor reevaluateVisibilityConditionsAffectedByFormField:formField];
    
    NSMutableDictionary *indexPathOperations = [NSMutableDictionary dictionary];
    NSMutableArray *visibleFormFields = [NSMutableArray arrayWithArray:self.visibleFormFields];
    
    // Change data source then notify the delegate controller that it needs to update it's layout
    
    // Check if fields should be added
    NSArray *fieldsToBeAdded = visibilityActionsDict[@(ASDKFormVisibilityConditionActionTypeShowElement)];
    NSMutableIndexSet *insertSectionIndexSet = [NSMutableIndexSet indexSet];
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    
    if (fieldsToBeAdded) {
        for (ASDKModelFormField *formField in fieldsToBeAdded) {
            BOOL isSectionInsert = (ASDKModelFormFieldTypeContainer == formField.fieldType);

            // To compute the insert index for the current form field we first look at it's position in the
            // renderable array (which holds all the form fields). We then take the previous item and check
            // if it's in the visible form fields collection and if so, that means the insert position is
            // after it. If not, we go back till the first element and repeat the process.
            
            if (isSectionInsert) {
                NSUInteger originalSectionIndex = [self sectionForFormField:formField
                                                               inCollection:self.renderableFormFields];
                NSUInteger insertIndex = [self insertIndexInFormFieldCollection:visibleFormFields
                                                                forSectionIndex:originalSectionIndex];
                [visibleFormFields insertObject:formField
                                        atIndex:insertIndex];
                
                [insertSectionIndexSet addIndex:insertIndex];
            } else {
                // Check where the field was inside the renderable fields collection
                NSUInteger originalSectionIndex = [self sectionForFormField:formField
                                                               inCollection:self.renderableFormFields];
                if (NSNotFound != originalSectionIndex) {
                    // Check if the section which contains the form field to be added is visible
                    if (![self doesCollection:visibleFormFields
                             containFormField:self.renderableFormFields[originalSectionIndex]]) {
                        // If it doesn't then extract it from the renderable collection and only set
                        // the element to be added as a child
                        ASDKModelFormField *sectionToBecomeVisible = self.renderableFormFields[originalSectionIndex];
                        sectionToBecomeVisible.formFields = @[formField];
                        
                        NSUInteger insertIndex = [self insertIndexInFormFieldCollection:visibleFormFields
                                                                        forSectionIndex:originalSectionIndex];
                        
                        [visibleFormFields insertObject:sectionToBecomeVisible
                                                atIndex:insertIndex];
                        [insertSectionIndexSet addIndex:insertIndex];
                    } else {
                        ASDKModelFormField *originalFormFieldSection = self.renderableFormFields[originalSectionIndex];
                        NSInteger originalFormFieldIndex = [self indexOfFormField:formField
                                                                     inCollection:originalFormFieldSection.formFields];
                        NSUInteger insertIndex = 0;
                        NSUInteger insertSection = [self sectionForFormField:self.renderableFormFields[originalSectionIndex]
                                                                inCollection:visibleFormFields];
                        
                        for (NSInteger fieldIndex = originalFormFieldIndex - 1; fieldIndex >= 0; fieldIndex--) {
                            ASDKModelFormField *currentFormField = originalFormFieldSection.formFields[fieldIndex];
                            if ([self isFormFieldVisible:currentFormField]) {
                                insertSection = [self sectionForFormField:currentFormField
                                                             inCollection:visibleFormFields];
                                ASDKModelFormField *visibleFormFieldSection = visibleFormFields[insertSection];
                                insertIndex = [self indexOfFormField:currentFormField
                                                        inCollection:visibleFormFieldSection.formFields] + 1;
                                break;
                            }
                        }
                        
                        ASDKModelFormField *sectionFormField = (ASDKModelFormField *)visibleFormFields[insertSection];
                        NSMutableArray *currentFormFields = [NSMutableArray arrayWithArray:sectionFormField.formFields];
                        [currentFormFields insertObject:formField
                                                atIndex:insertIndex];
                        sectionFormField.formFields = currentFormFields;
                        [insertIndexPaths addObject:[NSIndexPath indexPathForItem:insertIndex
                                                                        inSection:insertSection]];
                    }
                } else {
                    ASDKLogError(@"Cannot find form field that needs to become visibile in the renderable form field collection");
                }
            }
        }
    }

    [indexPathOperations setObject:insertSectionIndexSet
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeInsertSection)];
    
    [indexPathOperations setObject:insertIndexPaths
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeInsertRow)];
    
    // Check if fields should be removed
    NSArray *fieldsToBeRemoved = visibilityActionsDict[@(ASDKFormVisibilityConditionActionTypeHideElement)];
    NSMutableIndexSet *deleteSectionIndexSet = [NSMutableIndexSet indexSet];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    
    if (fieldsToBeRemoved) {
        for (ASDKModelFormField *formField in fieldsToBeRemoved) {
            BOOL isSectionRemoval = (ASDKModelFormFieldTypeContainer == formField.fieldType);
            
            NSUInteger sectionIndexToDelete = [self sectionForFormField:formField
                                                           inCollection:visibleFormFields];
            
            // If the element to delete is present in the visible forms
            if (NSNotFound != sectionIndexToDelete) {
                if (isSectionRemoval) {
                    [deleteSectionIndexSet addIndex:sectionIndexToDelete];
                } else {
                    ASDKModelFormField *sectionFieldToRemoveFrom = visibleFormFields[sectionIndexToDelete];
                    NSMutableArray *sectionFormFieldsToRemoveFrom = [NSMutableArray arrayWithArray:sectionFieldToRemoveFrom.formFields];
                    NSUInteger itemIndexToDelete = [self indexOfFormField:formField
                                                             inCollection:sectionFormFieldsToRemoveFrom];
                    
                    // If there are no more form fields inside the section then remove the section altogether
                    if (!(sectionFormFieldsToRemoveFrom.count - 1)) {
                        [deleteSectionIndexSet addIndex:sectionIndexToDelete];
                    } else {
                        [deleteIndexPaths addObject:[NSIndexPath indexPathForItem:itemIndexToDelete
                                                                        inSection:sectionIndexToDelete]];
                    }
                }
            }
        }
    }
    
    // Items will be removed after the indexes are computed to avoid
    // reporting of mutated indexes by multiple operations to the delegate
    [visibleFormFields removeObjectsAtIndexes:deleteSectionIndexSet];
    for (NSIndexPath *deleteIndexPath in deleteIndexPaths) {
        ASDKModelFormField *sectionFieldToRemoveFrom = visibleFormFields[deleteIndexPath.section];
        NSMutableArray *sectionFormFieldsToRemoveFrom = [NSMutableArray arrayWithArray:sectionFieldToRemoveFrom.formFields];
        [sectionFormFieldsToRemoveFrom removeObjectAtIndex:deleteIndexPath.row];
        sectionFieldToRemoveFrom.formFields = sectionFormFieldsToRemoveFrom;
    }
    
    [indexPathOperations setObject:deleteSectionIndexSet
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeRemoveSection)];
    [indexPathOperations setObject:deleteIndexPaths
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeRemoveRow)];
    
    // Persist the mutated visible form fields version
    self.visibleFormFields = visibleFormFields;
    
    // The form outcome indexes will have to be rebuilt
    [self.formOutcomesIndexPaths removeAllObjects];
    
    // Report index update operations to delegate
    if ([self.delegate respondsToSelector:@selector(requestControllerUpdateWithBatchOfOperations:)]) {
        [self.delegate requestControllerUpdateWithBatchOfOperations:indexPathOperations];
    }
}

- (NSUInteger)sectionForFormField:(ASDKModelFormField *)formField
                     inCollection:(NSArray *)collection {
    for (NSUInteger sectionCount = 0; sectionCount < collection.count; sectionCount++) {
        ASDKModelFormField *sectionField = collection[sectionCount];
        
        if ([formField.instanceID isEqualToString:sectionField.instanceID]) {
            return sectionCount;
        }
        
        for (ASDKModelFormField *childField in sectionField.formFields) {
            if ([formField.instanceID isEqualToString:childField.instanceID]) {
                return sectionCount;
            }
        }
    }
    
    return NSNotFound;
}

- (BOOL)isFormFieldVisible:(ASDKModelFormField *)formField {
    for (ASDKModelFormField *sectionField in self.visibleFormFields) {
        for (ASDKModelFormField *childField in sectionField.formFields) {
            if ([formField.instanceID isEqualToString:childField.instanceID]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)doesCollection:(NSArray *)collection
      containFormField:(ASDKModelFormField *)sectionFormField {
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"instanceID == %@", sectionFormField.instanceID];
    NSArray *results = [collection filteredArrayUsingPredicate:searchPredicate];
    
    return results.count ? YES : NO;
}

- (NSUInteger)indexOfFormField:(ASDKModelFormField *)formField inCollection:(NSArray *)collection {
    __block NSUInteger formFieldIdx = NSNotFound;
    
    [collection enumerateObjectsUsingBlock:^(ASDKModelFormField *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj.instanceID isEqualToString:formField.instanceID]) {
            formFieldIdx = idx;
            *stop = YES;
        }
    }];
    
    return formFieldIdx;
}

- (NSUInteger)insertIndexInFormFieldCollection:(NSArray *)formFieldCollection
                               forSectionIndex:(NSUInteger)sectionIndex  {
    NSUInteger insertIndex = 0;
    
    for (NSInteger sectionCount = sectionIndex - 1; sectionCount >= 0; sectionCount--) {
        ASDKModelFormField *previousSectionFormField = (ASDKModelFormField *)self.renderableFormFields[sectionCount];
        
        if ([self doesCollection:formFieldCollection
                containFormField:previousSectionFormField]) {
            insertIndex = [self indexOfFormField:previousSectionFormField
                                    inCollection:formFieldCollection] + 1;
            break;
        }
    }
    
    return insertIndex;
}

@end
