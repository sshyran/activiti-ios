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

#import "AFAAddTaskViewController.h"
#import <QuartzCore/QuartzCore.h>

// Constants
#import "AFALocalizationConstants.h"

// Categories
#import "UIColor+AFATheme.h"

// Managers
#import "AFATaskServices.h"
#import "AFAProfileServices.h"
#import "AFAServiceRepository.h"
@import ActivitiSDK;

// Controllers
#import "UIViewController+AFAAlertAddition.h"

// Models
#import "AFATaskCreateModel.h"

// Views
#import <JGProgressHUD/JGProgressHUD.h>

@interface AFAAddTaskViewController ()

@property (weak, nonatomic) IBOutlet UIView             *alertContainerView;
@property (weak, nonatomic) IBOutlet UILabel            *alertTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel            *nameLabel;
@property (weak, nonatomic) IBOutlet UITextField        *nameTextField;
@property (weak, nonatomic) IBOutlet UILabel            *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextView         *descriptionTextView;
@property (weak, nonatomic) IBOutlet UIButton           *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton           *confirmButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *alertContainerViewVerticalConstraint;
@property (strong, nonatomic) JGProgressHUD             *progressHUD;

@end

@implementation AFAAddTaskViewController

- (void)dealloc {
    [self.alertContainerView removeObserver:self
                                 forKeyPath:@"bounds"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillChange:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up localization
    self.alertTitleLabel.text = (AFAAddTaskControllerTypePlainTask == self.controllerType) ? NSLocalizedString(kLocalizationAddTaskScreenTitleText, @"New task title") : NSLocalizedString(kLocalizationAddTaskScreenChecklistTitleText, @"New checklist title");
    self.nameLabel.text = NSLocalizedString(kLocalizationAddTaskScreenNameLabelText, @"Name label");
    self.descriptionLabel.text = NSLocalizedString(kLocalizationAddTaskScreenDescriptionLabelText, @"Description label");
    [self.cancelButton setTitle:NSLocalizedString(kLocalizationAlertDialogCancelButtonText, @"Cancel button")
                       forState:UIControlStateNormal];
    self.confirmButton.backgroundColor = self.appThemeColor;
    [self.confirmButton setTitle:NSLocalizedString(kLocalizationAddTaskScreenCreateButtonText, @"Confirm button")
                        forState:UIControlStateNormal];
    [self validateTaskNameFieldForString:self.nameTextField.text];
    
    self.progressHUD = [self configureProgressHUD];
    
    [self.alertContainerView addObserver:self
                              forKeyPath:@"bounds"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.alertContainerView.alpha = .0f;
    self.alertContainerView.transform = CGAffineTransformMakeScale(1.3f, 1.3f);
    
    // Apply a fade-in animation
    [UIView animateWithDuration:kOverlayAlphaChangeTime
                          delay:.0f
         usingSpringWithDamping:.5f
          initialSpringVelocity:5.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.alertContainerView.alpha = 1.0f;
                         self.alertContainerView.transform = CGAffineTransformMakeScale(1.0, 1.0);
                     } completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)keyboardWillChange:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.alertContainerViewVerticalConstraint.constant = (keyboardFrame.origin.y == self.view.frame.size.height) ? .0f : - CGRectGetHeight(keyboardFrame) / 2.0f;
    [self.view layoutIfNeeded];
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
#pragma mark Action

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (IBAction)onConfirm:(id)sender {
    [self.view endEditing:YES];
    [self.progressHUD showInView:self.view];
    
    // First fetch information about the user creating the task
    __weak typeof(self) weakSelf = self;
    AFATaskServicesTaskDetailsCompletionBlock taskDetailsCompletionBlock = ^(ASDKModelTask *task, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationSuccessText, @"Success text");
                weakSelf.progressHUD.detailTextLabel.text = nil;
                
                weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([weakSelf.delegate respondsToSelector:@selector(didCreateTask:)]) {
                    [weakSelf.delegate didCreateTask:task];
                }
                
                [weakSelf.progressHUD dismiss];
                [weakSelf dismissViewControllerAnimated:YES
                                             completion:nil];
            });
        } else {
            [strongSelf.progressHUD dismiss];
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
    };
    
    AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    [profileServices requestProfileWithCompletionBlock:^(ASDKModelProfile *profile, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!error) {
            AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
            AFATaskCreateModel *taskCreateModel = [AFATaskCreateModel new];
            taskCreateModel.taskName = self.nameTextField.text;
            taskCreateModel.taskDescription = self.descriptionTextView.text;
            taskCreateModel.applicationID = self.applicationID;
            taskCreateModel.assigneeID = profile.modelID;
            
            if (AFAAddTaskControllerTypeChecklist == self.controllerType) {
                [taskServices requestChecklistCreateWithRepresentation:taskCreateModel
                                                                taskID:strongSelf.parentTaskID
                                                       completionBlock:taskDetailsCompletionBlock];
            } else {
                [taskServices requestCreateTaskWithRepresentation:taskCreateModel
                                                  completionBlock:taskDetailsCompletionBlock];
            }
        } else {
            [strongSelf.progressHUD dismiss];
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
    }];
}

- (IBAction)onKeyboardDismiss:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}

- (IBAction)onTaskNameTextFieldChange:(UITextField *)sender {
    [self validateTaskNameFieldForString:sender.text];  
}


#pragma mark -
#pragma mark Progress hud setup

- (JGProgressHUD *)configureProgressHUD {
    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
    JGProgressHUDFadeZoomAnimation *zoomAnimation = [JGProgressHUDFadeZoomAnimation animation];
    hud.animation = zoomAnimation;
    hud.layoutChangeAnimationDuration = .0f;
    hud.textLabel.text = (AFAAddTaskControllerTypePlainTask == self.controllerType) ? NSLocalizedString(kLocalizationAddTaskScreenCreatingTaskText, @"Creating task text") : NSLocalizedString(kLocalizationAddTaskScreenCreatingChecklistText, @"Creating checklist text");
    hud.indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    
    return hud;
}


#pragma mark -
#pragma mark Convenience methods

- (void)validateTaskNameFieldForString:(NSString *)taskName {
    BOOL enableCreateButton = [taskName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length ? YES : NO;
    
    self.confirmButton.enabled = enableCreateButton;
    [self.confirmButton setBackgroundColor:enableCreateButton ? self.appThemeColor : [UIColor disabledControlColor]];
}


#pragma mark -
#pragma mark KVO handling 

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (object == self.alertContainerView) {
        UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:self.alertContainerView.bounds];
        self.alertContainerView.layer.masksToBounds = NO;
        self.alertContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.alertContainerView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
        self.alertContainerView.layer.shadowOpacity = 0.5f;
        self.alertContainerView.layer.shadowPath = shadowPath.CGPath;
    }
}


@end
