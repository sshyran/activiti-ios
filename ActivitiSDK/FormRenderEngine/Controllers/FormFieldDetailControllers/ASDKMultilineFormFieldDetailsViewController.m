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


#import "ASDKMultilineFormFieldDetailsViewController.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"

@interface ASDKMultilineFormFieldDetailsViewController () <UITextViewDelegate>

@property (strong, nonatomic) ASDKModelFormField    *currentFormField;
@property (weak, nonatomic) IBOutlet UITextView     *multilineTextView;

@end

@implementation ASDKMultilineFormFieldDetailsViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.multilineTextView.delegate = self;
    
    // Update the navigation bar title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.currentFormField.fieldName;
    titleLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                      size:17];
    titleLabel.textColor = [UIColor whiteColor];
    [titleLabel sizeToFit];
    self.navigationItem.titleView = titleLabel;
    
    // Setup label and text area
    if (self.currentFormField.metadataValue) {
        self.multilineTextView.text = self.currentFormField.metadataValue.attachedValue;
    } else {
        self.multilineTextView.text = self.currentFormField.values.firstObject;
    }
    
    if (ASDKModelFormFieldRepresentationTypeReadOnly == self.currentFormField.representationType) {
        self.multilineTextView.editable = NO;
        self.multilineTextView.textColor = [UIColor formViewCompletedValueColor];
    } else {
        // Focus text area
        [self.multilineTextView becomeFirstResponder];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [self.multilineTextView resignFirstResponder];
    [super touchesBegan:touches withEvent:event];
}

#pragma mark -
#pragma mark ASDKFormFieldDetailsControllerProtocol

- (void)setupWithFormFieldModel:(ASDKModelFormField *)formFieldModel {
    self.currentFormField = formFieldModel;
}

#pragma mark -
#pragma mark TextView Delegate methods

- (void)textViewDidEndEditing:(UITextView *)textView {
    ASDKModelFormFieldValue *formFieldValue = [ASDKModelFormFieldValue new];
    formFieldValue.attachedValue = textView.text;

    self.currentFormField.metadataValue = formFieldValue;
}

@end
