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

#import "AFAProfileViewController.h"

// Constants
#import "AFALocalizationConstants.h"
#import "AFAUIConstants.h"

// Categories
#import "NSDate+AFAStringTransformation.h"
#import "UIViewController+AFAAlertAddition.h"

// Cells
#import "AFAProfileSectionTableViewCell.h"
#import "AFAProfileDetailTableViewCell.h"
#import "AFAProfileSimpleTableViewCell.h"
#import "AFAProfileActionTableViewCell.h"

// Views
#import "AFAAvatarView.h"
#import "AFAActivityView.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAProfileServices.h"
#import "AFAThumbnailManager.h"
@import ActivitiSDK;

typedef NS_ENUM(NSInteger, AFAProfileControllerState) {
    AFAProfileControllerStateIdle,
    AFAProfileControllerStateRefreshInProgress,
};

typedef NS_ENUM(NSInteger, AFAProfileControllerSectionType) {
    AFAProfileControllerSectionTypeContactInformation = 0,
    AFAProfileControllerSectionTypeGroups,
    AFAProfileControllerSectionTypeChangePassord,
    AFAProfileControllerSectionTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFAProfileControllerContactInformationType) {
    AFAProfileControllerContactInformationTypeEmail = 0,
    AFAProfileControllerContactInformationTypeCompany,
    AFAProfileControllerContactInformationTypeEnumCount
};

static const CGFloat profileControllerSectionHeight = 30.0f;

@interface AFAProfileViewController () <AFAProfileActionTableViewCellDelegate>

@property (weak, nonatomic) IBOutlet UITableView                *profileTableView;
@property (weak, nonatomic) IBOutlet AFAAvatarView              *avatarView;
@property (weak, nonatomic) IBOutlet UILabel                    *registeredDateLabel;
@property (weak, nonatomic) IBOutlet AFAActivityView            *activityView;
@property (strong, nonatomic) UIRefreshControl                  *refreshControl;
@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;

// Internal state properties
@property (strong, nonatomic) ASDKModelProfile                  *currentProfile;
@property (assign, nonatomic) AFAProfileControllerState         controllerState;
@property (strong, nonatomic) UIImage                           *profileImage;

// KVO
@property (strong, nonatomic) ASDKKVOManager                    *kvoManager;

@end

@implementation AFAProfileViewController


#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState = AFAProfileControllerStateIdle;
        
        // Set up state bindings
        [self handleBindingsForAppListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Update navigation bar title
    self.navigationBarTitle = NSLocalizedString(kLocalizationProfileScreenTitleText, @"Application title");
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.profileTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(onRefresh)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    // Set up the task list table view to adjust it's size automatically
    self.profileTableView.estimatedRowHeight = 40.0f;
    self.profileTableView.rowHeight = UITableViewAutomaticDimension;
    
    // Request the user profile
    self.controllerState = AFAProfileControllerStateRefreshInProgress;
    [self onRefresh];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


#pragma mark -
#pragma mark Actions

- (void)onRefresh {
    [self fetchProfileInformation];
    [self fetchProfileImage];
}

- (IBAction)onDismissTap:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}


#pragma mark -
#pragma mark Service integration

- (void)fetchProfileInformation {
    // Fetch information about the user creating the task
    __weak typeof(self) weakSelf = self;
    AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    [profileServices requestProfileWithCompletionBlock:^(ASDKModelProfile *profile, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        strongSelf.controllerState = AFAProfileControllerStateIdle;
        if (!error) {
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
            
            // Store the fetched profile
            strongSelf.currentProfile = profile;
            
            // Update the table header with the name and registration date
            self.firstNameTextField.text = profile.firstName;
            self.lastNameTextField.text = profile.lastName;
            self.registeredDateLabel.text = [NSString stringWithFormat:NSLocalizedString(kLocalizationProfileScreenRegisteredFormat, @"Registered since date"), [profile.creationDate listCreationDate]];
            
            // Reload table data
            [strongSelf.profileTableView reloadData];
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
    }];
}

- (void)fetchProfileImage {
    AFAProfileServices *profileService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    __weak typeof(self) weakSelf = self;
    [profileService requestProfileImageWithCompletionBlock:^(UIImage *profileImage, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!error) {
            strongSelf.profileImage = profileImage;
            
            // If we don't have loaded a thumbnail image use a placeholder instead
            // otherwise look in the cache or compute the image and set it once
            // available
            AFAThumbnailManager *thumbnailManager = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeThumbnailManager];
            strongSelf.profileImage = [thumbnailManager thumbnailForImage:self.profileImage
                                                     withIdentifier:kProfileImageThumbnailIdentifier
                                                           withSize:CGRectGetHeight(strongSelf.avatarView.frame) * [UIScreen mainScreen].scale
                                          processingCompletionBlock:^(UIImage *processedThumbnailImage) {
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  weakSelf.avatarView.profileImage = processedThumbnailImage;
                                              });
                                          }];
            
            strongSelf.avatarView.profileImage = self.profileImage;
        }
    }];
}


#pragma mark -
#pragma mark AFAProfileActionTableViewCellDelegate

- (void)profileActionChosenForCell:(UITableViewCell *)cell {
    
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return AFAProfileControllerSectionTypeEnumCount;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    NSInteger rowCount = 0;
    
    switch (section) {
        case AFAProfileControllerSectionTypeContactInformation: {
            rowCount = AFAProfileControllerContactInformationTypeEnumCount;
        }
            break;
            
        case AFAProfileControllerSectionTypeGroups: {
            rowCount = self.currentProfile.groups.count;
        }
            break;
            
        case AFAProfileControllerSectionTypeChangePassord: {
            rowCount = 1;
        }
            break;
            
        default:
            break;
    }
    
    return rowCount;
}

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = nil;
    
    if (AFAProfileControllerSectionTypeContactInformation == section ||
        AFAProfileControllerSectionTypeGroups == section) {
        AFAProfileSectionTableViewCell *sectionHeaderCell = [tableView dequeueReusableCellWithIdentifier:kCellIDProfileSectionTitle];
        
        if (AFAProfileControllerSectionTypeContactInformation == section) {
            sectionHeaderCell.sectionIconImageView.image = [UIImage imageNamed:@"contact-icon"];
            sectionHeaderCell.sectionTitleLabel.text = NSLocalizedString(kLocalizationProfileScreenContactInformationText, @"Contact information text");
        } else {
            sectionHeaderCell.sectionIconImageView.image = [UIImage imageNamed:@"group-icon"];
            sectionHeaderCell.sectionTitleLabel.text = NSLocalizedString(kLocalizationProfileScreenGroupsText, @"Groups text");
        }
        
        headerView = sectionHeaderCell;
    }
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    CGFloat headerHeight = .0f;
    
    switch (section) {
        case AFAProfileControllerSectionTypeContactInformation:
        case AFAProfileControllerSectionTypeGroups: {
            headerHeight = profileControllerSectionHeight;
        }
            break;
            
        default:
            break;
    }
    
    return headerHeight;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    
    switch (indexPath.section) {
        case AFAProfileControllerSectionTypeContactInformation: {
            AFAProfileDetailTableViewCell *contactInformationCell = [tableView dequeueReusableCellWithIdentifier:kCellIDProfileCategory
                                                                                                   forIndexPath:indexPath];
            if (AFAProfileControllerContactInformationTypeEmail == indexPath.row) {
                contactInformationCell.categoryTitleLabel.text =  NSLocalizedString(kLocalizationProfileScreenEmailText, @"Email text");
                contactInformationCell.categoryDescriptionTextField.text = self.currentProfile.email;
            } else {
                contactInformationCell.categoryTitleLabel.text = NSLocalizedString(kLocalizationProfileScreenCompanyText, @"Company text");
                contactInformationCell.categoryDescriptionTextField.text = self.currentProfile.company;
            }
            
            cell = contactInformationCell;
        }
            break;
        
        case AFAProfileControllerSectionTypeGroups: {
            AFAProfileSimpleTableViewCell *groupCell = [tableView dequeueReusableCellWithIdentifier:kCellIDProfileOption
                                                                                       forIndexPath:indexPath];
            groupCell.titleLabel.text = ((ASDKModelGroup *)self.currentProfile.groups[indexPath.row]).name;
            cell = groupCell;
        }
            break;
            
        case AFAProfileControllerSectionTypeChangePassord: {
            AFAProfileActionTableViewCell *changePasswordCell = [tableView dequeueReusableCellWithIdentifier:kCellIDProfileAction
                                                                                                forIndexPath:indexPath];
            [changePasswordCell.actionButton setTitle:NSLocalizedString(kLocalizationProfileScreenPasswordButtonText, @"Change password button")
                                             forState:UIControlStateNormal];
            
            cell = changePasswordCell;
        }
            break;
            
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
}


#pragma mark -
#pragma mark KVO bindings

- (void)handleBindingsForAppListViewController {
    self.kvoManager = [ASDKKVOManager managerWithObserver:self];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:self
                        forKeyPath:NSStringFromSelector(@selector(controllerState))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 AFAProfileControllerState controllerState = [change[NSKeyValueChangeNewKey] boolValue];
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     strongSelf.activityView.hidden = (AFAProfileControllerStateRefreshInProgress == controllerState) ? NO : YES;
                                     strongSelf.activityView.animating = (AFAProfileControllerStateRefreshInProgress == controllerState) ? YES : NO;
                                 });
                             }];
}

@end
