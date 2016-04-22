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

#import "ASDKDateFormFieldDetailsViewController.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLocalizationConstants.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldOption.h"
#import "ASDKModelFormFieldValue.h"

@interface ASDKDateFormFieldDetailsViewController ()

- (IBAction)datePickerAction:(id)sender;
@property (strong, nonatomic) ASDKModelFormField    *currentFormField;
@property (weak, nonatomic) IBOutlet UILabel        *selectedDate;
@property (weak, nonatomic) IBOutlet UIDatePicker   *datePicker;

@end


@implementation ASDKDateFormFieldDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Update the navigation bar title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.currentFormField.fieldName;
    titleLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                      size:17];
    titleLabel.textColor = [UIColor whiteColor];
    [titleLabel sizeToFit];
    self.navigationItem.titleView = titleLabel;
    
    // Setup label and date picker
    if (self.currentFormField.metadataValue) {
        self.selectedDate.text = self.currentFormField.metadataValue.attachedValue;
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        [dateFormatter setDateFormat:@"dd-MM-yyyy"];
        
        NSDate *storedDate = [dateFormatter dateFromString:self.currentFormField.metadataValue.attachedValue];
        [self.datePicker setDate:storedDate];
    } else if (self.currentFormField.values){
        //format date in saved form (2016-02-23T23:00:Z)
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z";
        
        NSDate *storedDate = [dateFormatter dateFromString:self.currentFormField.values.firstObject];
        
        // try other date formatter
        if (storedDate == nil) {
            //format date in saved form (2016-02-23T23:00:000Z)
            dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";
            storedDate = [dateFormatter dateFromString:self.currentFormField.values.firstObject];
        }
        
        NSDateFormatter *displayDateFormatter = [[NSDateFormatter alloc] init];
        [displayDateFormatter setDateFormat:@"dd-MM-yyyy"];
        
        self.selectedDate.text = [displayDateFormatter stringFromDate:storedDate];
        [self.datePicker setDate:storedDate];
    } else {
        self.selectedDate.text = ASDKLocalizedStringFromTable(kLocalizationFormDateComponentPickDateLabelText, ASDKLocalizationTable, @"Pick a date");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark ASDKFormFieldDetailsControllerProtocol

- (void)setupWithFormFieldModel:(ASDKModelFormField *)formFieldModel {
    self.currentFormField = formFieldModel;
}

- (IBAction)datePickerAction:(id)sender {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MM-yyyy"];

    NSString *formatedDate = [dateFormatter stringFromDate:self.datePicker.date];
    self.selectedDate.text = formatedDate;
    
    // Propagate the change after the state of the checkbox has changed
    ASDKModelFormFieldValue *formFieldValue = [ASDKModelFormFieldValue new];
    formFieldValue.attachedValue = formatedDate;
    
    self.currentFormField.metadataValue = formFieldValue;
    
    // Notify the value transaction delegate there has been a change with the provided form field model
    if ([self.valueTransactionDelegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
        [self.valueTransactionDelegate updatedMetadataValueForFormField:self.currentFormField
                                                                 inCell:nil];
    }
}
@end
