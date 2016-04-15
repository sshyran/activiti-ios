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

#import "ASDKFormTextFieldCollectionViewCell.h"
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "UIColor+ASDKFormViewColors.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKFormTextFieldCollectionViewCell () <UITextFieldDelegate>

@property (strong, nonatomic) ASDKModelFormField    *formField;
@property (assign, nonatomic) BOOL                  isRequired;

@end

@implementation ASDKFormTextFieldCollectionViewCell

- (void)awakeFromNib {
    self.textfield.delegate = self;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    // Adjust the cell sizing parameters by constraining with a high priority on the horizontal axis
    // and a lower priority on the vertical axis
    UICollectionViewLayoutAttributes *attributes = [super preferredLayoutAttributesFittingAttributes:layoutAttributes];
    attributes.size = CGSizeMake(layoutAttributes.size.width, attributes.size.height);
    return attributes;
}


#pragma mark -
#pragma mark ASDKFormCellProtocol

- (void)setupCellWithFormField:(ASDKModelFormField *)formField {
    self.formField = formField;
    self.descriptionLabel.text = formField.fieldName;
    
    // We reuse the text field cell so check the input type mode based on the passed
    // form field
    self.keyBoardType = [self keyBoardTypeForFormField:formField];
    
    // If dealing with a read-only representation then disable the text field and copy the
    // user-filled value
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
        self.textfield.text = formField.values.firstObject;
        self.textfield.enabled = NO;
        self.textfield.textColor = [UIColor formViewCompletedValueColor];
    } else {
        self.isRequired = formField.isRequired;
        self.textfield.placeholder = formField.placeholer;
        self.textfield.enabled = !formField.isReadOnly;
        self.textfield.keyboardType = [self keyBoardTypeForValue:self.keyBoardType];
        
        // Check for any existing metadata value that might have been attached to the form
        // field object. If present, populate the text field with it
        if (self.formField.metadataValue) {
            self.textfield.text = self.formField.metadataValue.attachedValue;
        } else if (formField.values) {
            self.textfield.text = formField.values.firstObject;
        }
        
        [self validateCellStateForText:self.textfield.text];
    }
}


#pragma mark -
#pragma mark TextField Delegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    __weak typeof(self) weakSelf = self;
    
    // Dispatch the metadata update in the next processing cycle
    // to give room for all UITextfield delegate methods to get
    // executed - the metadata update method triggers a collection
    // view reload which causes certain delegate methods calls to
    // be intrerupted
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        
        ASDKModelFormFieldValue *metadataValue = [ASDKModelFormFieldValue new];
        metadataValue.attachedValue = textField.text;
        strongSelf.formField.metadataValue = metadataValue;
        
        if ([strongSelf.delegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
            [strongSelf.delegate updatedMetadataValueForFormField:strongSelf.formField
                                                           inCell:strongSelf];
        }
    });
}

- (IBAction)onTextFieldValueChange:(UITextField *)sender {
    // If the value of this cell is required check it's state every time
    // the value of the text field changes
    [self validateCellStateForText:sender.text];
}


#pragma mark -
#pragma mark Cell states & validation

- (void)prepareForReuse {
    self.descriptionLabel.text = nil;
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
    self.textfield.text = nil;
}

- (void)markCellValueAsInvalid {
    self.descriptionLabel.textColor = [UIColor formViewInvalidValueColor];
}

- (void)markCellValueAsValid {
    self.descriptionLabel.textColor = [UIColor formViewValidValueColor];
}

- (void)cleanInvalidCellValue {
    self.textfield.text = nil;
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
    
    // Check input in relation to the type of input
    if (ASDKFormTextFieldKeyboardTypeNumerical == self.keyBoardType) {
        NSCharacterSet *alphaNums = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:text];
        BOOL isStringSetAlphaNumeric = [alphaNums isSupersetOfSet:inStringSet];
        if (!isStringSetAlphaNumeric) {
            [self cleanInvalidCellValue];
        }
    }
}

- (UIKeyboardType)keyBoardTypeForValue:(ASDKFormTextFieldKeyboardType)enumValue {
    switch (enumValue) {
        case ASDKFormTextFieldKeyboardTypeASCII: {
            return UIKeyboardTypeASCIICapable;
        }
            break;
            
        case ASDKFormTextFieldKeyboardTypeNumerical: {
            return UIKeyboardTypeNumberPad;
        }
            break;
            
        default:
            break;
    }
    
    return UIKeyboardTypeDefault;
}

- (ASDKFormTextFieldKeyboardType)keyBoardTypeForFormField:(ASDKModelFormField *)formField {
    switch (formField.representationType) {
        case ASDKModelFormFieldRepresentationTypeText: {
            return ASDKFormTextFieldKeyboardTypeASCII;
        }
            break;
        
        case ASDKModelFormFieldRepresentationTypeNumerical: {
            return ASDKFormTextFieldKeyboardTypeNumerical;
        }
            break;
            
        default:
            break;
    }
    
    // If a match can't be found use the ASCII keyboard;
    return ASDKFormTextFieldKeyboardTypeASCII;
}

@end