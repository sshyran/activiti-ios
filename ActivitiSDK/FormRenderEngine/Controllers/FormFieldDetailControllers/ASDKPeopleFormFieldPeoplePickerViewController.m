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

#import "ASDKPeopleFormFieldPeoplePickerViewController.h"

// Categories
#import "UIFont+ASDKGlyphicons.h"
#import "NSString+ASDKFontGlyphicons.h"
#import "UIView+ASDKViewAnimations.h"
#import "UIViewController+ASDKAlertAddition.h"

// views
#import "ASDKActivityView.h"
#import <JGProgressHUD/JGProgressHUD.h>

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLocalizationConstants.h"

// Services
#import "ASDKBootstrap.h"
#import "ASDKServiceLocator.h"
#import "ASDKUserNetworkServices.h"
#import "ASDKUserNetworkServiceProtocol.h"

// Models
#import "ASDKUserFilterModel.h"
#import "ASDKUserRequestRepresentation.h"
#import "ASDKModelUser.h"
#import "ASDKModelFormField.h"

// Cells
#import "ASDKPeopleTableViewCell.h"

// Logging
#import "ASDKLogConfiguration.h"

// Segues
#import "ASDKPushFadeSegueUnwind.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

typedef NS_ENUM(NSInteger, ASDKPeoplePickerControllerState) {
    AFAPeoplePickerControllerStateIdle,
    AFAPeoplePickerControllerStateInProgress,
};


@interface ASDKPeopleFormFieldPeoplePickerViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem            *backBarButtonItem;
@property (weak, nonatomic) IBOutlet UIView                     *searchOverlayView;
@property (weak, nonatomic) IBOutlet UITableView                *contributorsTableView;
@property (weak, nonatomic) IBOutlet UILabel                    *noRecordsLabel;
@property (weak, nonatomic) IBOutlet ASDKActivityView           *loadingActivityView;
@property (weak, nonatomic) IBOutlet UILabel                    *instructionsLabel;
@property (weak, nonatomic) IBOutlet UIView                     *instructionsView;
@property (weak, nonatomic) IBOutlet UITextField                *peopleSearchField;
@property (strong, nonatomic) JGProgressHUD                     *progressHUD;

@property (assign, nonatomic) BOOL                              isSearchInProgress;
@property (strong, nonatomic) NSArray                           *usersArr;
@property (strong, nonatomic) ASDKModelUser                     *selectedUser;
@property (assign, nonatomic) ASDKPeoplePickerControllerState   controllerState;

@end


@implementation ASDKPeopleFormFieldPeoplePickerViewController

#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState = AFAPeoplePickerControllerStateIdle;
        self.progressHUD = [self configureProgressHUD];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
    self.instructionsLabel.text = ASDKLocalizedStringFromTable(kLocalizationPeoplePickerControllerInstructionText, ASDKLocalizationTable, @"Search instructions text");
    
    // pre select user
    self.selectedUser = self.currentFormField.values.firstObject;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.peopleSearchField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Navigation

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDFormFieldPeopleAddPeopleUnwind isEqualToString:identifier]) {
        ASDKPushFadeSegueUnwind *unwindSegue = [ASDKPushFadeSegueUnwind segueWithIdentifier:identifier
                                                                                     source:fromViewController
                                                                                destination:toViewController
                                                                             performHandler:^{}];
        return unwindSegue;
    }

    
    return [super segueForUnwindingToViewController:toViewController
                                 fromViewController:fromViewController
                                         identifier:identifier];
}


#pragma mark -
#pragma mark ASDKFormFieldDetailsControllerProtocol

- (void)setupWithFormFieldModel:(ASDKModelFormField *)formFieldModel {
    self.currentFormField = formFieldModel;
}

#pragma mark -
#pragma mark Actions

- (IBAction)onBack:(id)sender {
    [self performSegueWithIdentifier:kSegueIDFormFieldPeopleAddPeopleUnwind
                              sender:sender];
}

- (IBAction)onSearchOverlay:(id)sender {
    [self toggleContentTransparentOverlay];
}

#pragma mark -
#pragma mark UITextField Delegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (!self.instructionsView.hidden) {
        self.instructionsView.hidden = YES;
    }
    
    [self toggleContentTransparentOverlay];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length) {
        [self fetchUserListForSearchText:textField.text];
    }
    [self toggleContentTransparentOverlay];
    
    return YES;
}


#pragma mark -
#pragma mark Animations

- (void)toggleContentTransparentOverlay {
    self.isSearchInProgress = !self.isSearchInProgress;
    
    CGFloat overlayAlphaValue = self.isSearchInProgress ? .5f : self.searchOverlayView.alpha ? .0f : .5f;
    
    [self.searchOverlayView animateAlpha:overlayAlphaValue
                            withDuration:kOverlayAlphaChangeTime
                     withCompletionBlock:^(BOOL didFinished) {
                         if (!self.isSearchInProgress) {
                             [self.view endEditing:YES];
                         }
                     }];
}

#pragma mark -
#pragma mark Service integration

- (void)fetchUserListForSearchText:(NSString *)searchText {
    self.controllerState = AFAPeoplePickerControllerStateInProgress;
    
    ASDKUserFilterModel *userFilterModel = [ASDKUserFilterModel new];
    
    searchText = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // First check if we're dealing with a search by email
    NSString *laxString = @"^.+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*$";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", laxString];
    if ([emailTest evaluateWithObject:searchText]) {
        userFilterModel.email = searchText;
    } else {
        userFilterModel.name = searchText;
    }
    
    // Acquire and set up the user network service
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    ASDKUserNetworkServices *userNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKUserNetworkServiceProtocol)];
    
    ASDKUserRequestRepresentation *userRequestRepresentation = [ASDKUserRequestRepresentation new];
    userRequestRepresentation.filter = userFilterModel.name;
    userRequestRepresentation.email = userFilterModel.email;
    userRequestRepresentation.jsonAdapterType = ASDKModelJSONAdapterTypeExcludeNilValues;
    
    __weak typeof(self) weakSelf = self;
    [userNetworkService fetchUsersWithUserRequestRepresentation:userRequestRepresentation
                                                completionBlock:^(NSArray *users, NSError *error, ASDKModelPaging *paging) {
                                                    __strong typeof(self) strongSelf = weakSelf;
                                                    
                                                    if (!error && users) {
                                                        ASDKLogVerbose(@"Fetched %lu user entries", (unsigned long)users.count);
                                                        
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            strongSelf.usersArr = users;
                                                            
                                                            // Check if we got an empty list
                                                            strongSelf.noRecordsLabel.hidden = users.count ? YES : NO;
                                                            strongSelf.contributorsTableView.hidden = users.count ? NO : YES;
                                                            
                                                            // Reload table data
                                                            [strongSelf.contributorsTableView reloadData];
                                                        });
                                                    } else {
                                                        ASDKLogError(@"An error occured while fetching the user list. Reason:%@", error.localizedDescription);
                                                        
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            strongSelf.noRecordsLabel.hidden = NO;
                                                            strongSelf.contributorsTableView.hidden = YES;
                                                            
                                                            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:ASDKLocalizedStringFromTable(kLocalizationFormAlertDialogGenericNetworkErrorText, ASDKLocalizationTable, @"Generic network error")];
                                                        });
                                                    }
                                                }];
    
}

- (void)addUserToCurrentFormField:(ASDKModelUser *)user {
    NSMutableArray *currentUser = [NSMutableArray arrayWithObject:user];
    self.currentFormField.values = [NSArray arrayWithArray:currentUser];
}

- (void)removeUserFromCurrentFormField {
    self.currentFormField.values = [[NSArray alloc] init];
}

#pragma mark -
#pragma mark - Progress hud setup

- (JGProgressHUD *)configureProgressHUD {
    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
    JGProgressHUDFadeZoomAnimation *zoomAnimation = [JGProgressHUDFadeZoomAnimation animation];
    hud.animation = zoomAnimation;
    hud.layoutChangeAnimationDuration = .0f;
    hud.indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    
    return hud;
}

- (void)showUserInvolvementIndicatorView {
    self.progressHUD.textLabel.text = nil;
    JGProgressHUDIndeterminateIndicatorView *indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [indicatorView setColor:[UIColor whiteColor]];
    self.progressHUD.indicatorView = indicatorView;
    [self.progressHUD showInView:self.navigationController.view];
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.usersArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKPeopleTableViewCell *peopleCell = [tableView dequeueReusableCellWithIdentifier:kASDKCellIDFormFieldPeopleAddPeople];
    ASDKModelUser *selectedUser = self.usersArr[indexPath.row];
    [peopleCell setUpCellWithUser:selectedUser];
    
    if (self.selectedUser.userID == selectedUser.userID) {
        peopleCell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        peopleCell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return peopleCell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKModelUser *selectedUser = self.usersArr[indexPath.row];
    
    if (self.selectedUser.userID == selectedUser.userID) {
        self.selectedUser = nil;
        [self removeUserFromCurrentFormField];
    } else {
        self.selectedUser = selectedUser;
        [self addUserToCurrentFormField:selectedUser];
    }
    
    // Notify the value transaction delegate there has been a change with the provided form field model
    if ([self.valueTransactionDelegate respondsToSelector:@selector(updatedMetadataValueForFormField:inCell:)]) {
        [self.valueTransactionDelegate updatedMetadataValueForFormField:self.currentFormField
                                                                 inCell:nil];
    }
    
    [self performSegueWithIdentifier:kSegueIDFormFieldPeopleAddPeopleUnwind sender:self];

}

@end