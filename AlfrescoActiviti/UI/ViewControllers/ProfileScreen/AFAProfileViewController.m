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
#import <JGProgressHUD/JGProgressHUD.h>

// View controllers
#import "AFAContentPickerViewController.h"

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

@interface AFAProfileViewController () <AFAProfileActionTableViewCellDelegate,
                                        AFAProfileDetailTableViewCellDelegate,
                                        AFAContentPickerViewControllerDelegate,
                                        UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableView                *profileTableView;
@property (weak, nonatomic) IBOutlet AFAAvatarView              *avatarView;
@property (weak, nonatomic) IBOutlet UILabel                    *registeredDateLabel;
@property (weak, nonatomic) IBOutlet AFAActivityView            *activityView;
@property (strong, nonatomic) UIRefreshControl                  *refreshControl;
@property (weak, nonatomic) IBOutlet UITextField                *firstNameTextField;
@property (weak, nonatomic) IBOutlet UITextField                *lastNameTextField;
@property (strong, nonatomic) JGProgressHUD                     *progressHUD;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *contentPickerContainerBottomConstraint;
@property (strong, nonatomic) AFAContentPickerViewController    *contentPickerViewController;
@property (weak, nonatomic) IBOutlet UIView                     *contentPickerContainer;
@property (weak, nonatomic) IBOutlet UIView                     *fullScreenOverlayView;
@property (weak, nonatomic) IBOutlet UILabel                    *noInformationAvailableLabel;
@property (weak, nonatomic) IBOutlet UIView                     *refreshView;
@property (weak, nonatomic) IBOutlet UIButton                   *refreshButton;

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
        self.progressHUD = [self configureProgressHUD];
        
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
                            action:@selector(onRefresh:)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    self.refreshButton.titleLabel.font = [UIFont glyphiconFontWithSize:15];
    [self.refreshButton setTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeRefresh]
                        forState:UIControlStateNormal];
    self.noInformationAvailableLabel.text = NSLocalizedString(kLocalizationProfileScreenNoInformationAvailableText, @"No information available");
    
    // Set up the task list table view to adjust it's size automatically
    self.profileTableView.estimatedRowHeight = 40.0f;
    self.profileTableView.rowHeight = UITableViewAutomaticDimension;
    
    // Set name fields delegate
    self.firstNameTextField.delegate = self;
    self.lastNameTextField.delegate = self;
    
    // Request the user profile
    self.controllerState = AFAProfileControllerStateRefreshInProgress;
    [self onRefresh:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - 
#pragma mark Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([kSegueIDProfileContentPickerComponentEmbedding isEqualToString:segue.identifier]) {
        self.contentPickerViewController = (AFAContentPickerViewController *)segue.destinationViewController;
        self.contentPickerViewController.delegate = self;
        self.contentPickerViewController.pickerType = AFAContentPickerViewControllerTypeProfileRelated;
    }
}


#pragma mark -
#pragma mark Actions

- (IBAction)onRefresh:(id)sender {
    self.refreshView.hidden = YES;
    self.noInformationAvailableLabel.hidden = YES;
    
    [self fetchProfileInformation];
    [self fetchProfileImage];
}

- (IBAction)onDismissTap:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}

- (IBAction)onProfilePictureAdd:(id)sender {
    [self toggleFullscreenOverlayView];
    [self toggleContentPickerComponent];
}

- (void)toggleContentPickerComponent {
    NSInteger contentPickerConstant = 0;
    if (!self.contentPickerContainerBottomConstraint.constant) {
        contentPickerConstant = -(CGRectGetHeight(self.contentPickerContainer.frame));
    }
    
    // Show the content picker container
    if (!contentPickerConstant) {
        self.contentPickerContainer.hidden = NO;
    }
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:0
         usingSpringWithDamping:.95f
          initialSpringVelocity:20.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.contentPickerContainerBottomConstraint.constant = contentPickerConstant;
                         [self.view layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         if (contentPickerConstant) {
                             self.contentPickerContainer.hidden = YES;
                         }
                     }];
}

- (void)toggleFullscreenOverlayView {
    CGFloat alphaValue = !self.fullScreenOverlayView.alpha ? .4f : .0f;
    if (alphaValue) {
        self.fullScreenOverlayView.hidden = NO;
    }
    
    [UIView animateWithDuration:kDefaultAnimationTime animations:^{
        self.fullScreenOverlayView.alpha = alphaValue;
    } completion:^(BOOL finished) {
        if (!alphaValue) {
            self.fullScreenOverlayView.hidden = YES;
        }
    }];
}

- (IBAction)onFullscreenOverlayTap:(id)sender {
    [self toggleFullscreenOverlayView];
    [self toggleContentPickerComponent];
}


#pragma mark -
#pragma mark Service integration

- (void)fetchProfileInformation {
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
        
        BOOL isInformationAvailable = error ? NO : YES;
        strongSelf.noInformationAvailableLabel.hidden = isInformationAvailable;
        strongSelf.profileTableView.hidden = !isInformationAvailable;
        strongSelf.refreshView.hidden = isInformationAvailable;
        
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

- (void)updateProfileInformationForProfile:(ASDKModelProfile *)profile {
    [self showFormSaveIndicatorView];
    
    __weak typeof(self) weakSelf = self;
    AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    [profileServices requestProfileUpdateWithModel:profile
                                   completionBlock:^(ASDKModelProfile *profile, NSError *error) {
                                       __strong typeof(self) strongSelf = weakSelf;
                                       
                                       if (!error) {
                                           // Display the last update date
                                           if (strongSelf.refreshControl) {
                                               strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
                                           }
                                           
                                           dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                               weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationProfileScreenProfileInformationUpdatedText, "Profile updated text");
                                               weakSelf.progressHUD.detailTextLabel.text = nil;
                                               weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                                               weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                                           });
                                           
                                           dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                               [weakSelf.progressHUD dismiss];
                                           });
                                           
                                           // Store the fetched profile
                                           strongSelf.currentProfile = profile;
                                           
                                           // Update the table header with the name and registration date
                                           self.firstNameTextField.text = profile.firstName;
                                           self.lastNameTextField.text = profile.lastName;
                                           
                                           // Reload table data
                                           [strongSelf.profileTableView reloadData];
                                       } else {
                                           [strongSelf.progressHUD dismiss];
                                           [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                           
                                           // If an error occured, roll back to the previous valid state of the user profile
                                           // Update the table header with the name and registration date
                                           self.firstNameTextField.text = strongSelf.currentProfile.firstName;
                                           self.lastNameTextField.text = strongSelf.currentProfile.lastName;
                                           
                                           // Reload table data
                                           [strongSelf.profileTableView reloadData];
                                       }
    }];
}

- (void)updateProfilePasswordWithNewPassword:(NSString *)updatedPassword
                                 oldPassword:(NSString *)oldPassword {
    [self showFormSaveIndicatorView];
    
    __weak typeof(self) weakSelf = self;
    AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    [profileServices requestProfilePasswordUpdatedWithNewPassword:updatedPassword
                                                      oldPassword:oldPassword
                                                  completionBlock:^(BOOL isPasswordUpdated, NSError *error) {
                                                      __strong typeof(self) strongSelf = weakSelf;
                                                      
                                                      if (!error) {
                                                          // Display the last update date
                                                          if (strongSelf.refreshControl) {
                                                              strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
                                                          }
                                                          
                                                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                              weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationProfileScreenPasswordUpdatedText, "Password updated text");
                                                              weakSelf.progressHUD.detailTextLabel.text = nil;
                                                              weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                                                              weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                                                          });
                                                          
                                                          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                              [weakSelf.progressHUD dismiss];
                                                          });
                                                      } else {
                                                          [strongSelf.progressHUD dismiss];
                                                          [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                                      }
    }];
}


#pragma mark -
#pragma mark AFAProfileActionTableViewCellDelegate

- (void)profileActionChosenForCell:(UITableViewCell *)cell {
    NSIndexPath *indexPath = [self.profileTableView indexPathForCell:cell];
    
    if (AFAProfileControllerSectionTypeChangePassord == indexPath.section) {
        UIAlertController *changePasswordAlertController = [UIAlertController
                                                            alertControllerWithTitle:NSLocalizedString(kLocalizationProfileScreenPasswordButtonText, @"Change password")
                                                            message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [changePasswordAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(kLocalizationProfileScreenOriginalPasswordText, @"Original password");
            textField.secureTextEntry = YES;
        }];
        [changePasswordAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(kLocalizationProfileScreenNewPasswordText, @"New password");
            textField.secureTextEntry = YES;
        }];
        [changePasswordAlertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(kLocalizationProfileScreenRepeatPasswordText, @"Repeat password");
            textField.secureTextEntry = YES;
        }];
        
        __weak typeof(self) weakSelf = self;
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(kLocalizationAlertDialogConfirmText, @"Confirm")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            __strong typeof(self) strongSelf = weakSelf;
                                                            
                                                            UITextField *oldPasswordField = changePasswordAlertController.textFields.firstObject;
                                                            UITextField *newPasswordField = changePasswordAlertController.textFields[1];
                                                            UITextField *confirmPasswordField = changePasswordAlertController.textFields.lastObject;
                                                            
                                                            if (oldPasswordField.text.length &&
                                                                newPasswordField.text.length &&
                                                                [newPasswordField.text isEqualToString:confirmPasswordField.text]) {
                                                                [strongSelf updateProfilePasswordWithNewPassword:newPasswordField.text
                                                                                                     oldPassword:oldPasswordField.text];
                                                            } else {
                                                                [strongSelf showGenericErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationProfileScreenPasswordMismatchText, @"Password missmatch")];
                                                            }
        }];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(kLocalizationAlertDialogCancelButtonText, @"Cancel")
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        
        [changePasswordAlertController addAction:cancelAction];
        [changePasswordAlertController addAction:confirmAction];
        
        [self presentViewController:changePasswordAlertController
                           animated:YES
                         completion:nil];
    }
}


#pragma mark -
#pragma mark AFAProfileDetailTableViewCellDelegate

- (void)updatedModelPropertyWithValue:(NSString *)value
                              forCell:(UITableViewCell *)cell {
    // Check which property of the profile is affected by this cell
    NSIndexPath *indexPath = [self.profileTableView indexPathForCell:cell];
    BOOL isProfileUpdated = NO;
    
    // Deep copy the profile object so that it remains untouched by future mutations
    NSData *buffer = [NSKeyedArchiver archivedDataWithRootObject: self.currentProfile];
    ASDKModelProfile *profileCopy = [NSKeyedUnarchiver unarchiveObjectWithData: buffer];
    
    if (AFAProfileControllerSectionTypeContactInformation == indexPath.section) {
        switch (indexPath.row) {
            case AFAProfileControllerContactInformationTypeEmail: {
                if (![profileCopy.email isEqualToString:value]) {
                    isProfileUpdated = YES;
                    profileCopy.email = value;
                }
            }
                break;
            
            case AFAProfileControllerContactInformationTypeCompany: {
                if (![profileCopy.company isEqualToString:value]) {
                    isProfileUpdated = YES;
                    profileCopy.company = value;
                }
            }
                break;
                
            default:
                break;
        }
    }
    
    if (isProfileUpdated) {
        [self updateProfileInformationForProfile:profileCopy];
    }
}


#pragma mark -
#pragma mark UITextField Delegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    BOOL isProfileUpdated = NO;
    
    // Deep copy the profile object so that it remains untouched by future mutations
    NSData *buffer = [NSKeyedArchiver archivedDataWithRootObject: self.currentProfile];
    ASDKModelProfile *profileCopy = [NSKeyedUnarchiver unarchiveObjectWithData: buffer];
    
    // Check for changes made to the profile
    if (self.firstNameTextField == textField) {
        if (![profileCopy.firstName isEqualToString:textField.text]) {
            isProfileUpdated = YES;
            profileCopy.firstName = textField.text;
        }
    }
    
    if (self.lastNameTextField == textField) {
        if (![profileCopy.lastName isEqualToString:textField.text]) {
            isProfileUpdated = YES;
            profileCopy.lastName = textField.text;
        }
    }
    
    // If changes were made to the profile, update the server values
    if (isProfileUpdated) {
        [self updateProfileInformationForProfile:profileCopy];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}


#pragma mark -
#pragma mark AFAContentPickerViewController Delegate

- (void)userPickedImageAtURL:(NSURL *)imageURL {
    [self onFullscreenOverlayTap:nil];
}

- (void)userDidCancelImagePick {
    [self onFullscreenOverlayTap:nil];
}

- (void)pickedContentHasFinishedUploading {
    [self fetchProfileImage];
}

- (void)userPickedImageFromCamera {
    [self onFullscreenOverlayTap:nil];
}

- (void)pickedContentHasFinishedDownloadingAtURL:(NSURL *)downloadedFileURL {
}


#pragma mark
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

- (void)showFormSaveIndicatorView {
    self.progressHUD.textLabel.text = nil;
    JGProgressHUDIndeterminateIndicatorView *indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [indicatorView setColor:[UIColor whiteColor]];
    self.progressHUD.indicatorView = indicatorView;
    [self.progressHUD showInView:self.navigationController.view];
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
            contactInformationCell.delegate = self;
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
            changePasswordCell.delegate = self;
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
