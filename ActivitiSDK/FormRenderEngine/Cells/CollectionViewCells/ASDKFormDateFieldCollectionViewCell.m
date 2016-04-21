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

#import "ASDKFormDateFieldCollectionViewCell.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"

@interface ASDKFormDateFieldCollectionViewCell ()

@property (strong, nonatomic) ASDKModelFormField    *formField;
@property (assign, nonatomic) BOOL                  isRequired;

- (NSString *)formatLabelTextWithFormFieldValues:(NSArray *)formfieldValues;

@end

@implementation ASDKFormDateFieldCollectionViewCell

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
        self.selectedDateLabel.text = [self formatLabelTextWithFormFieldValues:formField.values];
        self.selectedDateLabel.textColor = [UIColor formViewCompletedValueColor];
        self.disclosureIndicatorLabel.hidden = YES;
        self.trailingToDisclosureConstraint.priority = UILayoutPriorityFittingSizeLevel;
    } else {
        self.isRequired = formField.isRequired;

        // If a previously selected option is available display it
        if (formField.metadataValue) {
            self.selectedDateLabel.text = formField.metadataValue.attachedValue;
        } else  {
            self.selectedDateLabel.text = [self formatLabelTextWithFormFieldValues:formField.values];
        }
        self.disclosureIndicatorLabel.hidden = NO;
        
        [self validateCellStateForText:self.selectedDateLabel.text];
        
        __weak typeof(self) weakSelf = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if ([self.delegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
                [self.delegate updatedMetadataValueForFormField:strongSelf.formField
                                                         inCell:strongSelf];
            }
        });
    }
}

- (NSString *)formatLabelTextWithFormFieldValues:(NSArray *)formfieldValues {
    NSString *labelText = nil;
    
    if (formfieldValues) {
        //format date in saved form (2016-02-23T23:00:Z)
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z";
        
        NSDate *storedDate = [dateFormatter dateFromString:formfieldValues.firstObject];
        
        // try other date formatter
        if (storedDate == nil) {
            //format date in saved form (2016-02-23T23:00:000Z)
            dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";
            storedDate = [dateFormatter dateFromString:formfieldValues.firstObject];
        }
        
        NSDateFormatter *displayDateFormatter = [[NSDateFormatter alloc] init];
        [displayDateFormatter setDateFormat:@"dd-MM-yyyy"];
        
        labelText = [displayDateFormatter stringFromDate:storedDate];
    } else {
        labelText = @"";
    }
    
    return labelText;
}

#pragma mark -
#pragma mark Cell states & validation

- (void)prepareForReuse {
    self.descriptionLabel.text = nil;
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
    self.selectedDateLabel.text = nil;
}

- (void)markCellValueAsInvalid {
    self.descriptionLabel.textColor = [UIColor formViewInvalidValueColor];
}

- (void)markCellValueAsValid {
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
}

- (void)cleanInvalidCellValue {
    self.selectedDateLabel.text = nil;
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