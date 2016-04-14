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

#import "ASDKRadioFieldCollectionViewCell.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelRestFormField.h"
#import "ASDKModelFormFieldOption.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"

@interface ASDKRadioFieldCollectionViewCell ()

@property (strong, nonatomic) ASDKModelFormField    *formField;
@property (assign, nonatomic) BOOL                  isRequired;

- (NSString *)formatSelectedOptionLabelTextWithRestFormField:(ASDKModelRestFormField *)restFormField;

@end

@implementation ASDKRadioFieldCollectionViewCell

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
    
    ASDKModelRestFormField *restFormField = (ASDKModelRestFormField *) formField;
    self.descriptionLabel.text = formField.fieldName;

    if (ASDKModelFormFieldRepresentationTypeReadOnly == restFormField.representationType) {
        self.selectedOptionLabel.text = [self formatSelectedOptionLabelTextWithRestFormField:restFormField];
        self.selectedOptionLabel.textColor = [UIColor formViewCompletedValueColor];
        self.disclosureIndicatorLabel.hidden = YES;
        self.trailingToDisclosureConstraint.priority = UILayoutPriorityFittingSizeLevel;
    } else {
        self.isRequired = formField.isRequired;

        self.selectedOptionLabel.text = [self formatSelectedOptionLabelTextWithRestFormField:restFormField];
        self.disclosureIndicatorLabel.hidden = NO;
        
        [self validateCellStateForText:self.selectedOptionLabel.text];
    }
}

- (NSString *)formatSelectedOptionLabelTextWithRestFormField:(ASDKModelRestFormField *)restFormField {
    NSString *descriptionLabelText = nil;

    // If a previously selected option is available display it
    if (restFormField.metadataValue) {
        descriptionLabelText = restFormField.metadataValue.option.attachedValue;
    } else if (restFormField.representationType == ASDKModelFormFieldRepresentationTypeRadio && restFormField.restURL) {
        // temporary handling initial value dislay for REST populated radio form fields
        // the JSON model contains an initial value which isn't correct and shouldn't be displayed
        // but the first occurence of the fetched options should be displayed
        
        if (restFormField.formFieldOptions) {
            ASDKModelFormFieldOption *firstOption = restFormField.formFieldOptions.firstObject;
            descriptionLabelText = firstOption.name;
            restFormField.values = @[firstOption.name];
        } else {
            descriptionLabelText = @"";
        }
    } else if (restFormField.representationType == ASDKModelFormFieldRepresentationTypeDropdown && restFormField.restURL) {
        // temporary handling initial value dislay for REST populated radio form fields
        // the JSON model contains an initial value which isn't correct and shouldn't be displayed
        
        descriptionLabelText = @"";
    } else if (restFormField.values) {
        // TODO: Should dynamic table fields be formatted conform regular drop down fields??
        if ([restFormField.values.firstObject isKindOfClass:NSDictionary.class]) {
            descriptionLabelText = restFormField.values.firstObject[@"name"];
        } else {
            descriptionLabelText = restFormField.values.firstObject;
        }
    } else {
        descriptionLabelText = @"";
    }
    
    return descriptionLabelText;
}

#pragma mark -
#pragma mark Cell states & validation

- (void)prepareForReuse {
    self.descriptionLabel.text = nil;
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
    self.selectedOptionLabel.text = nil;
}

- (void)markCellValueAsInvalid {
    self.descriptionLabel.textColor = [UIColor formViewInvalidValueColor];
}

- (void)markCellValueAsValid {
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
}

- (void)cleanInvalidCellValue {
    self.selectedOptionLabel.text = nil;
}

- (void)validateCellStateForText:(NSString *)text {
    // Check input in relation to the requirement of the field
    if (self.isRequired) {
        if (!text.length) {
            [self markCellValueAsInvalid];
        } else {
            [self markCellValueAsValid];
        }
    }
}

@end