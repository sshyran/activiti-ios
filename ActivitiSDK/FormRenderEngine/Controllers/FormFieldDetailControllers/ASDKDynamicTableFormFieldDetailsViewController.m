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

#import "ASDKDynamicTableFormFieldDetailsViewController.h"
#import "ASDKBootstrap.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"

// Categories
#import "UIColor+ASDKFormViewColors.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelDynamicTableColumnDefinitionFormField.h"
#import "ASDKModelDynamicTableColumnDefinitionRestFormField.h"
#import "ASDKModelDynamicTableColumnDefinitionAmountFormField.h"
#import "ASDKModelDynamicTableFormField.h"

// Cells
#import "ASDKDynamicTableRowHeaderTableViewCell.h"
#import "ASDKDynamicTableColumnTableViewCell.h"

// Protocols
#import "ASDKFormCellProtocol.h"

@interface ASDKDynamicTableFormFieldDetailsViewController ()

@property (strong, nonatomic) ASDKModelFormField    *currentFormField;
@property (strong, nonatomic) NSArray               *visibleRowColumns;
@property (strong, nonatomic) NSDictionary          *columnDefinitions;
@property (weak, nonatomic)   IBOutlet UITableView  *rowsWithVisibleColumnsTableView;
- (IBAction)addDynamicTableRow:(id)sender;

@end

@implementation ASDKDynamicTableFormFieldDetailsViewController

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
    
    // Configure table view
    self.rowsWithVisibleColumnsTableView.estimatedRowHeight = 44.0f;
    self.rowsWithVisibleColumnsTableView.rowHeight = UITableViewAutomaticDimension;
    
    [self determineVisibleRowColumnsWithFormFieldValues:self.currentFormField.values];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [self.rowsWithVisibleColumnsTableView reloadData];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)addDynamicTableRow:(id)sender {
    ASDKModelDynamicTableFormField *dynamicTableFormField = (ASDKModelDynamicTableFormField *) self.currentFormField;
    
    NSMutableArray *newDynamicTableRows = [NSMutableArray new];
    if (self.currentFormField.values) {
        [newDynamicTableRows addObjectsFromArray:dynamicTableFormField.values];
    }
    if (dynamicTableFormField.columnDefinitions) {
        [newDynamicTableRows addObject:dynamicTableFormField.columnDefinitions];
    }
    self.currentFormField.values = [newDynamicTableRows copy];
    [self determineVisibleRowColumnsWithFormFieldValues:self.currentFormField.values];

    [self.rowsWithVisibleColumnsTableView reloadData];
}

- (void)determineVisibleRowColumnsWithFormFieldValues:(NSArray *)values {
    NSMutableArray *visibleColumnsInRows = [[NSMutableArray alloc] init];
    
    for (NSArray *row in values) {
        NSMutableArray *visibleColumns = [[NSMutableArray alloc] init];
        
        for (id column in row) {
            if ([column respondsToSelector:@selector(visible)]) {
                if ([column performSelector:@selector(visible)]) {
                    [visibleColumns addObject:column];
                }
            }
        }
        [visibleColumnsInRows addObject:visibleColumns];
    }
    
    self.visibleRowColumns = [NSArray arrayWithArray:visibleColumnsInRows];
}

#pragma mark -
#pragma mark ASDKFormFieldDetailsControllerProtocol

- (void)setupWithFormFieldModel:(ASDKModelFormField *)formFieldModel {
    self.currentFormField = formFieldModel;
}

#pragma mark -
#pragma mark UITableView Delegate & Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.visibleRowColumns.count;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    NSArray *rowsInSection = [self.visibleRowColumns objectAtIndex:section];
    return rowsInSection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKDynamicTableColumnTableViewCell *visibleColumnCell = [tableView dequeueReusableCellWithIdentifier:kASDKCellIDFormFieldDynamicTableRowRepresentation];
    
    ASDKModelFormField *rowFormField = self.visibleRowColumns[indexPath.section][indexPath.row];
    
    [self formatNameLabel:visibleColumnCell.columnNameLabel
            andValueLabel:visibleColumnCell.columnValueLabel
withColumnDefinitionFormField:rowFormField];
    
//    
//    visibleColumnCell.columnNameLabel.text = rowFormField.fieldName;
//    visibleColumnCell.columnValueLabel.text = [NSString stringWithFormat:@"value %@", rowFormField.values.firstObject];
    
//    visibleColumnCell.columnNameLabel.text = [(ASDKModelFormFieldOption *)self.currentFormField.formFieldOptions[indexPath.row] name];
//    radioCell.checkMarkIconImageView.hidden = !(self.currentOptionSelection == indexPath.row);
//    
//    if (ASDKModelFormFieldRepresentationTypeReadOnly == self.currentFormField.representationType) {
//        radioCell.userInteractionEnabled = NO;
//        radioCell.radioOptionLabel.enabled = NO;
//        radioCell.checkMarkIconImageView.tintColor = [UIColor lightGrayColor];
//    }
    
    return visibleColumnCell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    ASDKFormRenderEngine *formRenderEngine = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormRenderEngineProtocol)];
    
    [formRenderEngine setupWithDynamicTableRowFormFields:self.currentFormField.values[indexPath.section]
                                               taskModel:formRenderEngine.task
                                 dynamicTableFormFieldID:self.currentFormField.instanceID
                                   renderCompletionBlock:^(UICollectionViewController<ASDKFormControllerNavigationProtocol> *formController, NSError *error) {
                                       if (formController && !error) {
                                           // If there is controller assigned to the selected form field notify the delegate
                                           // that it can begin preparing for presentation
                                           formController.navigationDelegate = self.navigationDelegate;
                                           [self.navigationDelegate prepareToPresentDetailController:formController];
                                       } else {

//                                           
//                                           dispatch_async(dispatch_get_main_queue(), ^{
//                                               renderCompletionBlock(nil, error);
//                                           });
                                       }
                                   } formCompletionBlock:^(BOOL isFormCompleted, NSError *error) {
                                       if (!error) {
//                                           
//                                           dispatch_async(dispatch_get_main_queue(), ^{
//                                               formCompletionBlock(isFormCompleted, error);
//                                           });
                                       } else {

//                                           dispatch_async(dispatch_get_main_queue(), ^{
//                                               formCompletionBlock(NO, error);
//                                           });
                                       }
                                   }];
    

    
//    self.currentOptionSelection = indexPath.row;
//    
//    // Propagate the change after the state of the checkbox has changed
//    ASDKModelFormFieldValue *formFieldValue = [ASDKModelFormFieldValue new];
//    
//    ASDKModelFormFieldValue *optionFormFieldValue = [ASDKModelFormFieldValue new];
//    optionFormFieldValue.attachedValue = [(ASDKModelFormFieldOption *)self.currentFormField.formFieldOptions[indexPath.row] name];
//    formFieldValue.option = optionFormFieldValue;
//    
//    self.currentFormField.metadataValue = formFieldValue;
//    
//    [tableView reloadData];
}

-  (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    CGFloat headerHeight = 45.0f;
    return headerHeight;
}

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    ASDKDynamicTableRowHeaderTableViewCell *sectionHeaderView = [tableView dequeueReusableCellWithIdentifier:kASDKCellIDFormFieldDynamicTableHeaderRepresentation];
    sectionHeaderView.rowHeaderLabel.text = [NSString stringWithFormat:@"row %ld", (long) section + 1];
    return sectionHeaderView;
}



#pragma mark -
#pragma mark Convenience methods

- (void)formatNameLabel:(UILabel *)nameLabel
            andValueLabel:(UILabel *)valueLabel
withColumnDefinitionFormField:(ASDKModelFormField *) columnDefinitionformField {
    NSInteger representationType = ASDKModelFormFieldRepresentationTypeUndefined;
    nameLabel.text = columnDefinitionformField.fieldName;

    // If dealing with read-only forms extract the representation type from the attached
    // form field params model
    if (ASDKModelFormFieldRepresentationTypeReadOnly == columnDefinitionformField.representationType) {
        representationType = columnDefinitionformField.formFieldParams.representationType;
    } else {
        representationType = columnDefinitionformField.representationType;
    }
    
    switch (representationType) {
        case ASDKModelFormFieldRepresentationTypeBoolean: {
            BOOL formFieldValue;
            if (columnDefinitionformField.metadataValue) {
                formFieldValue = columnDefinitionformField.metadataValue.attachedValue;
            } else {
                formFieldValue = columnDefinitionformField.values.firstObject;
            }
            valueLabel.text = formFieldValue ? @"Yes" : @"No";
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeAmount: {
            ASDKModelDynamicTableColumnDefinitionAmountFormField *amountColumnDefinitionFormField = (ASDKModelDynamicTableColumnDefinitionAmountFormField *) columnDefinitionformField;
            NSString *currencySymbol = (amountColumnDefinitionFormField.currency.length != 0) ? amountColumnDefinitionFormField.currency : @"$";
            NSMutableAttributedString *labelText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@)", amountColumnDefinitionFormField.fieldName, currencySymbol]];
            [labelText addAttribute:NSForegroundColorAttributeName value:[UIColor formViewAmountFieldSymbolColor] range:NSMakeRange((labelText.length) - 3,3)];
            nameLabel.attributedText = labelText;
            
            if (columnDefinitionformField.metadataValue) {
                valueLabel.text = columnDefinitionformField.metadataValue.attachedValue;
            } else if (columnDefinitionformField.values) {
                valueLabel.text = [NSString stringWithFormat:@"%@", amountColumnDefinitionFormField.values.firstObject];
            } else {
                valueLabel.text = @"";
            }
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDropdown:
        case ASDKModelFormFieldRepresentationTypeRadio: {
            if (columnDefinitionformField.metadataValue) {
                valueLabel.text = columnDefinitionformField.metadataValue.option.attachedValue;
            } else if (columnDefinitionformField.values) {
                if ([columnDefinitionformField.values.firstObject isKindOfClass:NSDictionary.class]) {
                    valueLabel.text = columnDefinitionformField.values.firstObject[@"name"];
                } else {
                    valueLabel.text = columnDefinitionformField.values.firstObject;
                }
            } else {
                valueLabel.text = @"";
            }
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDate: {
            //format date in saved form (2016-02-23T23:00:00Z)
            if (columnDefinitionformField.metadataValue) {
                valueLabel.text = columnDefinitionformField.metadataValue.attachedValue;
            } else {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
                dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";
                
                NSDate *storedDate = [dateFormatter dateFromString:columnDefinitionformField.values.firstObject];
                
                NSDateFormatter *displayDateFormatter = [[NSDateFormatter alloc] init];
                [displayDateFormatter setDateFormat:@"dd-MM-yyyy"];
                
                valueLabel.text = [displayDateFormatter stringFromDate:storedDate];
            }
        }
            break;
            
        default: {
            valueLabel.text = columnDefinitionformField.values.firstObject;
        }
            break;
    }
}
@end