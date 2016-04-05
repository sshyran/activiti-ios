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

// Models
#import "AFALoginModel.h"

// Managers
#import "AFAKVOManager.h"

// Components
#import "AFAFadingTableView.h"

// Cells
#import "AFACredentialTextFieldTableViewCell.h"
#import "AFASignInTableViewCell.h"
#import "AFARememberCredentialsTableViewCell.h"
#import "AFASecurityLayerTableViewCell.h"

@interface AFALoginCredentialsViewController () <AFACredentialTextFieldTableViewCellDelegate, AFASignInButtonDelegate>

@property (weak, nonatomic)   IBOutlet                       AFAFadingTableView *credentialsTableView;
@property (assign, nonatomic) AFALoginCredentialEditing      credentialEditing;

// KVO
@property (strong, nonatomic) AFAKVOManager                  *kvoManager;

@end

@implementation AFALoginCredentialsViewController


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.kvoManager = [AFAKVOManager managerWithObserver:self];
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return AFALoginCredentialsTypePremise == self.loginType ? AFAPremiseLoginCredentialsCellTypeEnumCount : AFACloudLoginCredentialsCellTypeEnumCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    
    // Check if we're presenting a premise or cloud screen
    if (AFALoginCredentialsTypePremise == self.loginType) {
        switch (indexPath.row) {
            case AFAPremiseLoginCredentialsCellTypeSecurityLayer: {
                cell = [self dequeueSecurityLayerCellForTableView:tableView];
            }
                break;
                
            case AFAPremiseLoginCredentialsCellTypeHostname: {
                cell = [self dequeueHostNameCellForTableView:tableView];
            }
                break;
                
            case AFAPremiseLoginCredentialsCellTypeEmail: {
                cell = [self dequeueEmailCellForTableView:tableView];
            }
                break;
                
            case AFAPremiseLoginCredentialsCellTypePassword: {
                cell = [self dequeuePasswordCellForTableView:tableView];
            }
                break;
                
            case AFAPremiseLoginCredentialsCellTypeRememberCredentials: {
                cell = [self dequeueRememberCredentialsCellForTableView:tableView];
            }
                break;
                
            case AFAPremiseLoginCredentialsCellTypeSignIn: {
                cell = [self dequeueSignInCellForTableView:tableView];
            }
                break;
                
            default:
                break;
        }
    } else {
        switch (indexPath.row) {
            case AFACloudLoginCredentialsCellTypeEmail: {
                cell = [self dequeueEmailCellForTableView:tableView];
            }
                break;
                
            case AFACloudLoginCredentialsCellTypePassword: {
                cell = [self dequeuePasswordCellForTableView:tableView];
            }
                break;
                
            case AFACloudLoginCredentialsCellTypeRememberCredentials: {
                cell = [self dequeueRememberCredentialsCellForTableView:tableView];
            }
                break;
                
            case AFACloudLoginCredentialsCellTypeSignIn: {
                cell = [self dequeueSignInCellForTableView:tableView];
            }
                break;
                
            default:
                break;
        }
    }
    
    cell.backgroundColor = [UIColor clearColor];
    
    return cell;
}


#pragma mark - 
#pragma mark Cell builders

- (AFASecurityLayerTableViewCell *)dequeueSecurityLayerCellForTableView:(UITableView *)tableView {
    AFASecurityLayerTableViewCell *hostnameCell = [tableView dequeueReusableCellWithIdentifier:kCellIDSecurityLayer];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:hostnameCell.switchViewButton
                        forKeyPath:NSStringFromSelector(@selector(isOff))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 [strongSelf.loginModel updateCommunicationOverSecureLayer:![change[NSKeyValueChangeNewKey] boolValue]];
                             }];
    
    return hostnameCell;
}

- (AFACredentialTextFieldTableViewCell *)dequeueHostNameCellForTableView:(UITableView *)tableView {
    AFACredentialTextFieldTableViewCell *hostnameCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField];
    hostnameCell.delegate = self;
    
    hostnameCell.inputTextField.attributedPlaceholder = self.loginModel.hostnameAttributedPlaceholderText;
    hostnameCell.inputTextField.text = @"";
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

- (AFACredentialTextFieldTableViewCell *)dequeueEmailCellForTableView:(UITableView *)tableView {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.usernameAttributedPlaceholderText;
    credentialCell.inputTextField.text = @"";
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

- (AFACredentialTextFieldTableViewCell *)dequeuePasswordCellForTableView:(UITableView *)tableView {
    AFACredentialTextFieldTableViewCell *credentialCell = [tableView dequeueReusableCellWithIdentifier:kCellIDCredentialTextField];
    credentialCell.delegate = self;
    
    credentialCell.inputTextField.attributedPlaceholder = self.loginModel.passwordAttributedPlaceholderText;
    credentialCell.inputTextField.text = @"";
    credentialCell.inputTextField.secureTextEntry = YES;
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

- (AFARememberCredentialsTableViewCell *)dequeueRememberCredentialsCellForTableView:(UITableView *)tableView {
    AFARememberCredentialsTableViewCell *rememberCredentialsCell = [tableView dequeueReusableCellWithIdentifier:kCellIDRememberCredentials];
    rememberCredentialsCell.checkBox.selected = NO;
    
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
