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

#import "AFALoginCredentialsViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"
#import "AFALocalizationConstants.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"

// Models
#import "AFALoginModel.h"

// Components
#import "AFAFadingTableView.h"

// Cells
#import "AFACredentialTextFieldTableViewCell.h"
#import "AFASignInTableViewCell.h"
#import "AFARememberCredentialsTableViewCell.h"
#import "AFASecurityLayerTableViewCell.h"
#import "AFACredentialSectionTableViewCell.h"

@interface AFALoginCredentialsViewController () <AFACredentialTextFieldTableViewCellDelegate, AFASignInButtonDelegate>

@property (weak, nonatomic)   IBOutlet                       AFAFadingTableView *credentialsTableView;
@property (assign, nonatomic) AFALoginCredentialEditing      credentialEditing;

// KVO
@property (strong, nonatomic) ASDKKVOManager                 *kvoManager;

@end

@implementation AFALoginCredentialsViewController


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.kvoManager = [ASDKKVOManager managerWithObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.credentialsTableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    // Adjust the table content inset to avoid a positioning inconsistency
    // when presenting the controller in a page controller with an animation
    CGFloat edgeInset = self.credentialsTableView.frame.origin.y;
    if (edgeInset) {
        self.credentialsTableView.contentInset = UIEdgeInsetsMake(edgeInset, 0, 0, 0);
    }
    
    // Unlock if previously unlocked as a result from poping the controller
    [self lockInterface:NO];
    
    // Reset the auth state
    self.loginModel.authState = AFALoginViewModelAuthentificationStatePreparing;
    self.loginModel.authentificationType =
    (AFALoginCredentialsTypeCloud == self.loginType) ? AFALoginViewModelAuthentificationTypeCloud : AFALoginViewModelAuthentificationTypePremise;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Actions

- (IBAction)onDismissTap:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}


#pragma mark -
#pragma mark AFACredentialTextFieldTableViewCell Delegate

- (void)inputTextFieldWillBeginEditting:(UITextField *)inputTextField
                                 inCell:(UITableViewCell *)cell{
    // First field is already being edited
    if (self.credentialEditing & AFALoginCredentialEditingFirstField) {
        self.credentialEditing |= AFALoginCredentialEditingSecondField;
    } else if (self.credentialEditing & AFALoginCredentialEditingSecondField) { // Second field is already being edited
        self.credentialEditing |= AFALoginCredentialEditingFirstField;
    } else {
        self.credentialEditing |= AFALoginCredentialEditingFirstField;
    }
    
    self.loginModel.isCredentialInputInProgress = YES;
}

- (void)inputTextFieldWillEndEditting:(UITextField *)inputTextField
                               inCell:(UITableViewCell *)cell{
    // Stop editing first field
    if (self.credentialEditing & AFALoginCredentialEditingFirstField) {
        self.credentialEditing &= ~AFALoginCredentialEditingFirstField;
    } else if (self.credentialEditing & AFALoginCredentialEditingSecondField) { // Stop editing the second field
        self.credentialEditing &= ~AFALoginCredentialEditingSecondField;
    }
    
    // Check and update final state - no other fields being edited
    if (!(self.credentialEditing & AFALoginCredentialEditingFirstField) &&
        !(self.credentialEditing & AFALoginCredentialEditingSecondField)) {
        self.loginModel.isCredentialInputInProgress = NO;
    }
}


#pragma mark -
#pragma mark AFASignInButton Delegate

- (void)onSignIn:(id)sender
        fromCell:(UITableViewCell *)cell {
    // Resign the first responder for all active keyboards
    [self.view endEditing:YES];
    
    // If the login type is of cloud type then update the model with
    // the default host name and security layer
    if (AFALoginCredentialsTypeCloud == self.loginType) {
        [self.loginModel updateHostNameEntry:kActivitiCloudHostName];
        [self.loginModel updateCommunicationOverSecureLayer:YES];
        [self.loginModel updatePortEntry:nil];
    }
    
    // Do all mandatory fields have informations needed in order to login
    if ([self.loginModel canUserSignIn]) {
        [self lockInterface:YES];
        
        __weak typeof(self) weakSelf = self;
        [self.loginModel requestLoginWithCompletionBlock:^(BOOL isLoggedIn, NSError *error) {
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf lockInterface:NO];
            
            // Notify the user about the error
            if (error) {
                NSError *underlayingError = error.userInfo[NSUnderlyingErrorKey];
                NSInteger responseCode = [[underlayingError.userInfo objectForKey:AFNetworkingOperationFailingURLResponseErrorKey] statusCode];
                if (!responseCode) {
                    responseCode = underlayingError.code;
                }
                
                NSString *networkErrorMessage = nil;
                
                switch (responseCode) {
                    case ASDKHTTPCode401Unauthorised:
                    case ASDKHTTPCode403Forbidden: {
                        networkErrorMessage = NSLocalizedString(kLocalizationLoginInvalidCredentialsText, @"Invalid credentials text");
                    }
                        break;
                        
                    case NSURLErrorCannotConnectToHost: {
                        networkErrorMessage = NSLocalizedString(kLocalizationLoginUnreachableHostText, @"Unreachable host text");
                    }
                        break;
                        
                    case NSURLErrorTimedOut: {
                        networkErrorMessage = NSLocalizedString(kLocalizationLoginTimedOutText, @"Login timed out text");
                    }
                        break;
                        
                    default:
                        break;
                }
                
                [self showGenericNetworkErrorAlertControllerWithMessage:networkErrorMessage];
                [(AFASignInTableViewCell *)cell shakeSignInButton];
            }
        }];
    } else {
        // Notify the user that something is wrong
        [(AFASignInTableViewCell *)cell shakeSignInButton];
    }
}


#pragma mark -
#pragma mark Utilities

- (void)lockInterface:(BOOL)lockInterface {
    self.view.userInteractionEnabled = !lockInterface;
    self.loginModel.isCredentialInputInProgress = NO;
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // For the cloud login we just have 2 sections, a simple username / password pair of fields
    // and the sign in section
    return (AFALoginCredentialsTypePremise == self.loginType) ? AFAPremiseLoginSectionTypeEnumCount : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rowCount = 0;
    
    switch (self.loginType) {
        case AFALoginCredentialsTypeCloud: {
            if (AFACloudLoginSectionTypeAccountDetails == section) {
                rowCount = AFACloudLoginCredentialsCellTypeEnumCount;
            } else {
                rowCount = AFASignInSectionCellTypeEnumCount;
            }
        }
            break;
            
        case AFALoginCredentialsTypePremise: {
            if (AFAPremiseLoginSectionTypeAccountDetails == section) {
                rowCount = AFAPremiseLoginCredentialsCellTypeEnumCount;
            } else if (AFAPremiseLoginSectionTypeAdvanced == section) {
                rowCount = AFAPremiseLoginAdvancedCredentialsCellTypeEnumCount;
            } else {
                rowCount = AFASignInSectionCellTypeEnumCount;
            }
        }
            break;
            
        default:
            break;
    }
    
    return rowCount;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {
    CGFloat sectionHeight = 0;
    if (AFALoginCredentialsTypePremise == self.loginType) {
        if (AFAPremiseLoginSectionTypeAdvanced == section) {
            sectionHeight = 60.0f;
        }
    }
    
    return sectionHeight;
}

-(UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    AFACredentialSectionTableViewCell *sectionHeaderViewCell = [tableView dequeueReusableCellWithIdentifier:kCellIDLoginSection];
    sectionHeaderViewCell.sectionTitleLabel.text = [NSLocalizedString(kLocalizationLoginAdvancedSectionHeaderText, @"Advanced section text") uppercaseString];
    return sectionHeaderViewCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    
    // Check if we're presenting a premise or cloud screen
    if (AFALoginCredentialsTypePremise == self.loginType) {
        
        // Handle the dequeuing of each section that make up the premise login
        if (AFAPremiseLoginSectionTypeAccountDetails == indexPath.section) {
            switch (indexPath.row) {
                case AFAPremiseLoginCredentialsCellTypeHostname: {
                    cell = [self dequeueHostNameCellForTableView:tableView
                                                       indexPath:indexPath];
                }
                    break;
                    
                case AFAPremiseLoginCredentialsCellTypeEmail: {
                    cell = [self dequeueEmailCellForTableView:tableView
                                                    indexPath:indexPath];
                }
                    break;
                    
                case AFAPremiseLoginCredentialsCellTypePassword: {
                    cell = [self dequeuePasswordCellForTableView:tableView
                                                       indexPath:indexPath];
                }
                    break;
                    
                default:
                    break;
            }
        } else if (AFAPremiseLoginSectionTypeAdvanced == indexPath.section) {
            switch (indexPath.row) {
                case AFAPremiseLoginAdvancedCredentialsCellTypeSecurityLayer: {
                    cell = [self dequeueSecurityLayerCellForTableView:tableView
                                                            indexPath:indexPath];
                }
                    break;
                    
                case AFAPremiseLoginAdvancedCredentialsCellTypePort: {
                    cell = [self dequeuePortCellForTableView:tableView
                                                   indexPath:indexPath];
                }
                    break;
                    
                case AFAPremiseLoginAdvancedCredentialsCellTypeServiceDocument: {
                    cell = [self dequeueServiceDocumentCellForTableView:tableView
                                                              indexPath:indexPath];
                }
                    break;
                    
                default:
                    break;
            }
        } else {
            switch (indexPath.row) {
                case AFASignInSectionCellTypeRememberCredentials: {
                    cell = [self dequeueRememberCredentialsCellForTableView:tableView
                                                                  indexPath:indexPath];
                }
                    break;
                    
                case AFASignInSectionCellTypeSignIn: {
                    cell = [self dequeueSignInCellForTableView:tableView];
                }
                    break;
                    
                default:
                    break;
            }
        }
    } else {
        // Handle the dequeuing of each section that make up the cloud login
        if (AFACloudLoginSectionTypeAccountDetails == indexPath.section) {
            switch (indexPath.row) {
                case AFACloudLoginCredentialsCellTypeEmail: {
                    cell = [self dequeueEmailCellForTableView:tableView
                                                    indexPath:indexPath];
                }
                    break;
                    
                case AFACloudLoginCredentialsCellTypePassword: {
                    cell = [self dequeuePasswordCellForTableView:tableView
                                                       indexPath:indexPath];
                }
                    break;
                    
                default:
                    break;
            }
        } else {
            switch (indexPath.row) {
                case AFASignInSectionCellTypeRememberCredentials: {
                    cell = [self dequeueRememberCredentialsCellForTableView:tableView
                                                                  indexPath:indexPath];
                }
                    break;
                    
                case AFASignInSectionCellTypeSignIn: {
                    cell = [self dequeueSignInCellForTableView:tableView];
                }
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    cell.backgroundColor = [UIColor clearColor];
    
    return cell;
}


#pragma mark - 
#pragma mark Cell builders

- (AFASecurityLayerTableViewCell *)dequeueSecurityLayerCellForTableView:(UITableView *)tableView
                                                              indexPath:(NSIndexPath *)indexPath {
    AFASecurityLayerTableViewCell *securityLayerCell = [tableView dequeueReusableCellWithIdentifier:kCellIDSecurityLayer
                                                                                       forIndexPath:indexPath];
    
    securityLayerCell.switchViewButton.isOn = self.loginModel.isSecureLayer;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:securityLayerCell.switchViewButton
                        forKeyPath:NSStringFromSelector(@selector(isOn))
                           options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 // Avoid updating the login model for the same key values
                                 if ([change[NSKeyValueChangeNewKey] boolValue] != [change[NSKeyValueChangeOldKey] boolValue]) {
                                     BOOL isHTTPS = [change[NSKeyValueChangeNewKey] boolValue];
                                     
                                     [strongSelf.loginModel updateCommunicationOverSecureLayer:isHTTPS];
                                     [strongSelf.loginModel updatePortEntry:isHTTPS ? [@(kDefaultLoginSecuredPort) stringValue] : [@(kDefaultLoginUnsecuredPort) stringValue]];
                                     
                                     [strongSelf.credentialsTableView reloadRowsAtIndexPaths:
                                      @[[NSIndexPath indexPathForRow:AFAPremiseLoginAdvancedCredentialsCellTypePort
                                                           inSection:AFAPremiseLoginSectionTypeAdvanced]]
                                                                            withRowAnimation:UITableViewRowAnimationFade];
                                 }
                             }];
    
    return securityLayerCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeueHostNameCellForTableView:(UITableView *)tableView
                                                               indexPath:(NSIndexPath *)indexPath {
    AFACredentialTextFieldTableViewCell *hostnameCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField
                                                                                        forIndexPath:indexPath];
    hostnameCell.delegate = self;
    
    hostnameCell.inputTextField.attributedPlaceholder = self.loginModel.hostnameAttributedPlaceholderText;
    hostnameCell.inputTextField.text = self.loginModel.hostName;
    hostnameCell.inputTextField.secureTextEntry = NO;
    hostnameCell.inputTextField.keyboardType = UIKeyboardTypeDefault;
    hostnameCell.cellType = AFACredentialTextFieldCellTypeUnsecured;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:hostnameCell
                        forKeyPath:NSStringFromSelector(@selector(inputText))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updateHostNameEntry:change[NSKeyValueChangeNewKey]];
                             }];
    
    return hostnameCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeueEmailCellForTableView:(UITableView *)tableView
                                                            indexPath:(NSIndexPath *)indexPath {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField
                                                                                          forIndexPath:indexPath];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.usernameAttributedPlaceholderText;
    credentialCell.inputTextField.text = self.loginModel.username;
    credentialCell.inputTextField.secureTextEntry = NO;
    credentialCell.inputTextField.keyboardType = UIKeyboardTypeEmailAddress;
    credentialCell.cellType = AFACredentialTextFieldCellTypeUnsecured;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:credentialCell
                        forKeyPath:NSStringFromSelector(@selector(inputText))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updateUserNameEntry:change[NSKeyValueChangeNewKey]];
                             }];
    
    return credentialCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeuePasswordCellForTableView:(UITableView *)tableView
                                                               indexPath:(NSIndexPath *)indexPath {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField
                                                                                          forIndexPath:indexPath];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.passwordAttributedPlaceholderText;
    credentialCell.inputTextField.text = self.loginModel.password;
    credentialCell.inputTextField.secureTextEntry = YES;
    credentialCell.inputTextField.keyboardType = UIKeyboardTypeDefault;
    credentialCell.cellType = AFACredentialTextFieldCellTypeSecured;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:credentialCell
                        forKeyPath:NSStringFromSelector(@selector(inputText))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updatePasswordEntry:change[NSKeyValueChangeNewKey]];
                             }];
    
    return credentialCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeuePortCellForTableView:(UITableView *)tableView
                                                           indexPath:(NSIndexPath *)indexPath {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField
                                                                                          forIndexPath:indexPath];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.portAttributedPlaceholderText;
    credentialCell.inputTextField.text = self.loginModel.port;
    credentialCell.inputTextField.secureTextEntry = NO;
    credentialCell.inputTextField.keyboardType = UIKeyboardTypeNumberPad;
    credentialCell.cellType = AFACredentialTextFieldCellTypeUnsecured;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:credentialCell
                        forKeyPath:NSStringFromSelector(@selector(inputText))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updatePortEntry:change[NSKeyValueChangeNewKey]];
                             }];
    
    return credentialCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeueServiceDocumentCellForTableView:(UITableView *)tableView
                                                                      indexPath:(NSIndexPath *)indexPath {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField
                                                                                          forIndexPath:indexPath];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.serviceDocumentAttributedPlaceholderText;
    credentialCell.inputTextField.text = self.loginModel.serviceDocument;
    credentialCell.inputTextField.secureTextEntry = NO;
    credentialCell.inputTextField.keyboardType = UIKeyboardTypeDefault;
    credentialCell.cellType = AFACredentialTextFieldCellTypeUnsecured;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:credentialCell
                        forKeyPath:NSStringFromSelector(@selector(inputText))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updateServiceDocument:change[NSKeyValueChangeNewKey]];
                             }];
    
    return credentialCell;
}

- (AFARememberCredentialsTableViewCell *)dequeueRememberCredentialsCellForTableView:(UITableView *)tableView
                                                                          indexPath:(NSIndexPath *)indexPath {
    AFARememberCredentialsTableViewCell *rememberCredentialsCell = [tableView dequeueReusableCellWithIdentifier:kCellIDRememberCredentials
                                                                                                   forIndexPath:indexPath];
    rememberCredentialsCell.checkBox.selected = self.loginModel.rememberCredentials;
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:rememberCredentialsCell.checkBox
                        forKeyPath:@"selected"
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 [strongSelf.loginModel updateRememberCredentials:[change[NSKeyValueChangeNewKey] boolValue]];
                             }];
    
    return rememberCredentialsCell;
}

- (AFASignInTableViewCell *)dequeueSignInCellForTableView:(UITableView *)tableView {
    AFASignInTableViewCell *signInCell = [tableView dequeueReusableCellWithIdentifier:kCellIDSignInButton];
    signInCell.delegate = self;
    
    return signInCell;
}

@end
