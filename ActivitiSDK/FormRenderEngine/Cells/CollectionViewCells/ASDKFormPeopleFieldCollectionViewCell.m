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

#import "ASDKFormPeopleFieldCollectionViewCell.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelPeopleFormField.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLocalizationConstants.h"

@interface ASDKFormPeopleFieldCollectionViewCell ()

@property (strong, nonatomic) ASDKModelFormField    *formField;
@property (assign, nonatomic) BOOL                  isRequired;

- (NSString *)formatDescriptionLabelTextWithFormFieldValues:(NSArray *)formfieldValues;

@end

@implementation ASDKFormPeopleFieldCollectionViewCell

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    // Adjust the cell sizing parameters by constraining with a high priority on the horizontal axis
    // and a lower priority on the vertical axis
    UICollectionViewLayoutAttributes *attributes = [super preferredLayoutAttributesFittingAttributes:layoutAttributes];
    attributes.size = CGSizeMake(layoutAttributes.size.width, attributes.size.height);
    
    return attributes;
}

- (void)setSelected:(BOOL)selected {
    if (ASDKModelFormFieldRepresentationTypeReadOnly != self.formField.representationType) {
        [UIView animateWithDuration:kASDKSetSelectedAnimationTime animations:^{
            self.backgroundColor = selected ? [UIColor formFieldCellHighlightColor] : [UIColor whiteColor];
        }];
    }
}


#pragma mark -
#pragma mark ASDKFormCellProtocol

- (void)setupCellWithFormField:(ASDKModelFormField *)formField {
    self.formField = formField;
    self.descriptionLabel.text = formField.fieldName;
    
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
        
        self.selectedPeopleLabel.text = [self formatDescriptionLabelTextWithFormFieldValues:formField.values];
        self.selectedPeopleLabel.textColor = [UIColor formViewCompletedValueColor];
        self.selectedPeopleLabel.enabled = NO;
        self.disclosureIndicatorLabel.hidden = YES;
        self.labelTrailingToDisclosureIndicatorConstraint.priority = UILayoutPriorityFittingSizeLevel;
    } else {
        self.isRequired = formField.isRequired;
    
        // If a previously selected option is available display it
        if (formField.metadataValue) {
            self.selectedPeopleLabel.text = formField.metadataValue.attachedValue;
        } else if (formField.values) {
            self.selectedPeopleLabel.text = [self formatDescriptionLabelTextWithFormFieldValues:formField.values];

        } else {
            self.selectedPeopleLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormPeopleNoSelectedText, ASDKLocalizationTable, @"No people selected");
        }
        self.disclosureIndicatorLabel.hidden = NO;

        [self validateCellStateForFormFieldValues:formField.values];
        
        if ([self.delegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
            [self.delegate updatedMetadataValueForFormField:self.formField
                                                     inCell:self];
        }
    }
}

- (NSString *)formatDescriptionLabelTextWithFormFieldValues:(NSArray *)formfieldValues {
    NSString *descriptionLabelText = nil;
    
    if ([formfieldValues count] > 0) {
        ASDKModelUser *selectedPeople = (ASDKModelUser *) formfieldValues.firstObject;
        descriptionLabelText = selectedPeople.normalisedName;
    } else {
        descriptionLabelText = ASDKLocalizedStringFromTable(kLocalizationFormPeopleNoSelectedText, ASDKLocalizationTable, @"No people selected");
    }
    
    return descriptionLabelText;
}

#pragma mark -
#pragma mark Cell states & validation

- (void)prepareForReuse {
    self.descriptionLabel.text = nil;
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
    self.selectedPeopleLabel.text = nil;
}

- (void)markCellValueAsInvalid {
    self.descriptionLabel.textColor = [UIColor formViewInvalidValueColor];
}

- (void)markCellValueAsValid {
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
}

- (void)cleanInvalidCellValue {
    self.selectedPeopleLabel.text = nil;
}

- (void)validateCellStateForFormFieldValues:(NSArray *)formFieldValues {
    // Check input in relation to the requirement of the field
    if (self.isRequired) {
        if (!formFieldValues.count) {
            [self markCellValueAsInvalid];
        } else {
            [self markCellValueAsValid];
        }
    }
}

@end