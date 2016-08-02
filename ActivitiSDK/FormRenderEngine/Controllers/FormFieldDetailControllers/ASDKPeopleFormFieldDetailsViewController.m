/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile iOS App.
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

#import "ASDKPeopleFormFieldDetailsViewController.h"

// Categories
#import "UIFont+ASDKGlyphicons.h"
#import "NSString+ASDKFontGlyphicons.h"
#import "UIView+ASDKViewAnimations.h"
#import "UIViewController+ASDKAlertAddition.h"
#import "UIColor+ASDKFormViewColors.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLocalizationConstants.h"

// Controllers
#import "ASDKPeopleFormFieldPeoplePickerViewController.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelUser.h"

// Cells
#import "ASDKPeopleTableViewCell.h"

// Views
#import "ASDKNoContentView.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

typedef NS_ENUM(NSInteger, ASDKPeoplePickerControllerState) {
    AFAPeoplePickerControllerStateIdle,
    AFAPeoplePickerControllerStateInProgress,
};


@interface ASDKPeopleFormFieldDetailsViewController ()

@property (strong, nonatomic) ASDKModelFormField                                    *currentFormField;
@property (strong, nonatomic) ASDKPeopleFormFieldPeoplePickerViewController         *peoplePickerViewController;
@property (weak, nonatomic) IBOutlet UITableView                                    *peopleTableView;
@property (weak, nonatomic) IBOutlet ASDKNoContentView                              *noContentView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem                              *addBarButtonItem;

@end

@implementation ASDKPeopleFormFieldDetailsViewController

#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    return self;
}

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
    
    [self setRightBarButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self refreshContent];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshContent {
    // Display the no content view if appropiate
    self.noContentView.hidden = (self.currentFormField.values.count > 0) ? YES : NO;
    self.noContentView.iconImageView.image = [UIImage imageNamed:@"contributors-large-icon"
                                                        inBundle:[NSBundle bundleForClass:self.class]
                                   compatibleWithTraitCollection:nil];
    [self setRightBarButton];
    [self.peopleTableView reloadData];
}

- (IBAction)unwindFormFieldPeoplePickerController:(UIStoryboardSegue *)segue {
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([kSegueIDFormPeoplePicker isEqualToString:segue.identifier]) {
        self.peoplePickerViewController = (ASDKPeopleFormFieldPeoplePickerViewController *)segue.destinationViewController;
        self.peoplePickerViewController.currentFormField = self.currentFormField;
    }
}


#pragma mark -
#pragma mark ASDKFormFieldDetailsControllerProtocol

- (void)setupWithFormFieldModel:(ASDKModelFormField *)formFieldModel {
    self.currentFormField = formFieldModel;
}

- (IBAction)onAdd:(UIBarButtonItem *)sender {
    [self performSegueWithIdentifier:kSegueIDFormPeoplePicker
                              sender:sender];
}

- (void)setRightBarButton {
    if (ASDKModelFormFieldRepresentationTypeReadOnly == self.currentFormField.representationType) {
        [self.addBarButtonItem setEnabled:NO];
        [self.addBarButtonItem setTitle:nil];
    } else {
        UIBarButtonItem *rightBarButtonItem = nil;
        if (self.currentFormField.values.count > 0) {
            rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(onAdd:)];
        } else {
            rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(onAdd:)];
        }
        rightBarButtonItem.tintColor = [UIColor whiteColor];
        self.navigationItem.rightBarButtonItem = rightBarButtonItem;
    }
}

#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.currentFormField.values.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKPeopleTableViewCell *peopleCell = [tableView dequeueReusableCellWithIdentifier:kASDKCellIDFormFieldPeopleAddPeople];
    ASDKModelUser *selectedUser = self.currentFormField.values[indexPath.row];
    [peopleCell setUpCellWithUser:selectedUser];
    
    if (ASDKModelFormFieldRepresentationTypeReadOnly == self.currentFormField.representationType) {
        peopleCell.userInteractionEnabled = NO;
    }
    
    return peopleCell;
}

- (NSArray *)tableView:(UITableView *)tableView
editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    UITableViewRowAction *deleteButton =
    [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
                                       title:[@"" stringByPaddingToLength:2
                                                               withString:@"\u3000"
                                                          startingAtIndex:0]
                                     handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                                         __strong typeof(self) strongSelf = weakSelf;
                                         
                                         NSMutableArray *tmpArray = [NSMutableArray arrayWithArray:self.currentFormField.values];
                                         [tmpArray removeObjectAtIndex:indexPath.row];
                                         strongSelf.currentFormField.values = [tmpArray copy];
                                         
                                         // Notify the value transaction delegate there has been a change with the provided form field model
                                         if ([strongSelf.valueTransactionDelegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
                                             [strongSelf.valueTransactionDelegate updatedMetadataValueForFormField:strongSelf.currentFormField
                                                                                                      inCell:nil];
                                         }
                                         
                                         [tableView reloadData];
                                         [strongSelf refreshContent];
                                     }];
    
    // Tint the image with white
    UIImage *trashIcon = [UIImage imageNamed:@"trash-icon"
                                    inBundle:[NSBundle bundleForClass:self.class]
               compatibleWithTraitCollection:nil];
    UIGraphicsBeginImageContextWithOptions(trashIcon.size, NO, trashIcon.scale);
    [[UIColor whiteColor] set];
    [trashIcon drawInRect:CGRectMake(0, 0, trashIcon.size.width, trashIcon.size.height)];
    trashIcon = UIGraphicsGetImageFromCurrentImageContext();
    
    // Draw the image and background
    CGSize rowActionSize = CGSizeMake([tableView rectForRowAtIndexPath:indexPath].size.width, [tableView rectForRowAtIndexPath:indexPath].size.height);
    UIGraphicsBeginImageContextWithOptions(rowActionSize, YES, [[UIScreen mainScreen] scale]);
    CGContextRef context=UIGraphicsGetCurrentContext();
    [[UIColor distructiveOperationBackgroundColor] set];
    CGContextFillRect(context, CGRectMake(0, 0, rowActionSize.width, rowActionSize.height));
    
    [trashIcon drawAtPoint:CGPointMake(trashIcon.size.width + trashIcon.size.width / 4.0f, rowActionSize.height / 2.0f - trashIcon.size.height / 2.0f)];
    [deleteButton setBackgroundColor:[UIColor colorWithPatternImage:UIGraphicsGetImageFromCurrentImageContext()]];
    UIGraphicsEndImageContext();
    
    return @[deleteButton];
}

@end