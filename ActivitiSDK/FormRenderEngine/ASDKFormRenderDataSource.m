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
        
        self.visibleFormFields = self.renderableFormFields;
        
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
    return self.visibleFormFields.count + 1; // Where 1 is the additional section for form outcomes
}

- (NSInteger)numberOfFormFieldsForSection:(NSInteger)section {
    ASDKModelFormField *sectionFormField = section < self.visibleFormFields.count ? self.visibleFormFields[section] : nil;
    NSUInteger fieldsCount = 0;
    
    // Check if the controller requested the number of fields for the outcome section
    if (!sectionFormField) {
        fieldsCount = self.formOutcomes.count;
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
    } else {
        ASDKModelFormField *formFieldAtIndexPath = sectionFormField.formFields[indexPath.row];
        cellIdentifier = [self validCellIdentifierForFormField:formFieldAtIndexPath];
    }
    
    return cellIdentifier;
}

- (ASDKModelBase *)modelForIndexPath:(NSIndexPath *)indexPath {
    ASDKModelFormField *sectionFormField = indexPath.section < self.visibleFormFields.count ? self.visibleFormFields[indexPath.section] : nil;
    
    if (!sectionFormField) {
        ASDKModelFormOutcome *formOutcome = self.formOutcomes[indexPath.row];
        
        if (NSNotFound == [self.formOutcomesIndexPaths indexOfObject:indexPath]) {
            [self.formOutcomesIndexPaths addObject:indexPath];
        }
        
        return formOutcome;
    } else {// Set up the cell from the corresponding section
        ASDKModelFormField *formFieldAtIndexPath = [(ASDKModelFormField *)self.visibleFormFields[indexPath.section] formFields][indexPath.row];
        return formFieldAtIndexPath;
    }
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
        
        // If a section has no more attached form fields remove it, otherwise set the
        // modified form field collection
        if (!formFieldsInSection.count) {
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
            
        default:
            break;
    }
    
    return cellIdentifier;
}

- (NSString *)controllerIdentifierForFormField:(ASDKModelFormField *)formField {
    NSString *controllerIdentifierString = nil;
    NSInteger representationType = ASDKModelFormFieldRepresentationTypeUndefined;
    
    // completed forms; only attach fields have child view controller
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType && (ASDKModelFormFieldRepresentationTypeAttach == formField.formFieldParams.representationType || ASDKModelFormFieldRepresentationTypeMultiline == formField.formFieldParams.representationType)) {
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
                } else if (!formField.values.count && !formField.metadataValue.attachedValue.length) {
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
        
        // TODO: Check if more keypaths are required i.e. see how user-filled data is passed in all form fields
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
    
    // Check if fields should be added
    NSArray *fieldsToBeAdded = visibilityActionsDict[@(ASDKFormVisibilityConditionActionTypeShowElement)];
    NSMutableIndexSet *sectionIndexSet = [NSMutableIndexSet indexSet];
    NSMutableArray *insertionIndexPaths = [NSMutableArray array];
    
    if (fieldsToBeAdded) {
        // Change data source then notify the delegate controller that it needs to update it's layout
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
                
                [sectionIndexSet addIndex:insertIndex];
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
                        [sectionIndexSet addIndex:insertIndex];
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
                            }
                        }
                        
                        ASDKModelFormField *sectionFormField = (ASDKModelFormField *)visibleFormFields[insertSection];
                        NSMutableArray *currentFormFields = [NSMutableArray arrayWithArray:sectionFormField.formFields];
                        [currentFormFields insertObject:formField
                                                atIndex:insertIndex];
                        sectionFormField.formFields = currentFormFields;
                        [insertionIndexPaths addObject:[NSIndexPath indexPathForRow:insertIndex
                                                                          inSection:insertSection]];
                    }
                } else {
                    ASDKLogError(@"Cannot find form field that needs to become visibile in the renderable form field collection");
                }
            }
        }
    }

    [indexPathOperations setObject:sectionIndexSet
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeInsertSection)];
    
    [indexPathOperations setObject:insertionIndexPaths
                            forKey:@(ASDKFormRenderEngineControllerOperationTypeInsertRow)];
    
    // Persist the mutated visible form fields version
    self.visibleFormFields = visibleFormFields;
    
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
