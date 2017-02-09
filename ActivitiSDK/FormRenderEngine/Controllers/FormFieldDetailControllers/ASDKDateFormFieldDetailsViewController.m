/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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
#import "ASDKModelConfiguration.h"

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
        [dateFormatter setDateFormat:kASDKServerShortDateFormat];
        
        NSDate *storedDate = [dateFormatter dateFromString:self.currentFormField.metadataValue.attachedValue];
        [self.datePicker setDate:storedDate];
    } else if (self.currentFormField.values){
        //format date in saved form (2016-02-23T23:00:Z)
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        dateFormatter.dateFormat = kASDKServerLongDateFormat;
        
        NSDate *storedDate = [dateFormatter dateFromString:self.currentFormField.values.firstObject];
        
        // try other date formatter
        if (!storedDate) {
            dateFormatter.dateFormat = kASDKServerFullDateFormat;
            storedDate = [dateFormatter dateFromString:self.currentFormField.values.firstObject];
        }
        
        if (!storedDate) {
            dateFormatter.dateFormat = kBaseModelDateFormat;
            storedDate = [dateFormatter dateFromString:self.currentFormField.values.firstObject];
        }
        
        NSDateFormatter *displayDateFormatter = [[NSDateFormatter alloc] init];
        [displayDateFormatter setDateFormat:kASDKServerShortDateFormat];
        
        self.selectedDate.text = [displayDateFormatter stringFromDate:storedDate];
        [self.datePicker setDate:storedDate];
    } else {
        self.selectedDate.text = ASDKLocalizedStringFromTable(kLocalizationFormDateComponentPickDateLabelText, ASDKLocalizationTable, @"Pick a date");
    }
    
    self.datePicker.userInteractionEnabled = self.currentFormField.isReadOnly ? NO : YES;
    [self updateRightBarButtonState];
}

- (void)updateRightBarButtonState {
    if (self.currentFormField.isReadOnly) {
        return;
    }
    
    UIBarButtonItem *rightBarButtonItem = nil;
    if (self.currentFormField.metadataValue) {
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ASDKLocalizedStringFromTable(kLocalizationFormOptionClearText, ASDKLocalizationTable, @"Clear text")
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(onCleanCurrentDateOption)];
    } else {
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:ASDKLocalizedStringFromTable(kLocalizationFormDateComponentPickTodayText, ASDKLocalizationTable, @"Pick today text")
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(onPickTodayDateOption)];
    }
    
    rightBarButtonItem.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = rightBarButtonItem;
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


#pragma mark - 
#pragma mark Actions

- (void)reportDateForCurrentFormField:(NSDate *)date {
    if (!date) {
        self.selectedDate.text = ASDKLocalizedStringFromTable(kLocalizationFormDateComponentPickDateLabelText, ASDKLocalizationTable, @"Pick a date");
        self.currentFormField.metadataValue = nil;
    } else {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:kASDKServerShortDateFormat];
        
        NSString *formatedDate = [dateFormatter stringFromDate:date];
        self.selectedDate.text = formatedDate;
        
        // Propagate the change after the state of the checkbox has changed
        ASDKModelFormFieldValue *formFieldValue = [ASDKModelFormFieldValue new];
        formFieldValue.attachedValue = formatedDate;
        
        self.currentFormField.metadataValue = formFieldValue;
    }
    
    [self updateRightBarButtonState];
    
    // Notify the value transaction delegate there has been a change with the provided form field model
    if ([self.valueTransactionDelegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
        [self.valueTransactionDelegate updatedMetadataValueForFormField:self.currentFormField
                                                                 inCell:nil];
    }
}

- (IBAction)datePickerAction:(id)sender {
    [self reportDateForCurrentFormField:self.datePicker.date];
}

- (void)onPickTodayDateOption {
    NSDate *today = [NSDate date];
    [self reportDateForCurrentFormField:today];
    [self.datePicker setDate:today
                    animated:YES];
}

- (void)onCleanCurrentDateOption {
    [self reportDateForCurrentFormField:nil];
}

@end
