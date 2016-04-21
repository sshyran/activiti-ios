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

#import "AFATaskFormViewController.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"

// Constants
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAFormServices.h"
@import ActivitiSDK;

// Views
#import "AFAActivityView.h"

@interface AFATaskFormViewController() <ASDKFormControllerNavigationProtocol>

// Internal state properties
@property (strong, nonatomic) ASDKModelTask                 *task;
@property (strong, nonatomic) UICollectionViewController    *formViewController;
@property (weak, nonatomic)   IBOutlet AFAActivityView      *activityView;

@end

@implementation AFATaskFormViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Actions

- (void)startTaskFormForTaskObject:(ASDKModelTask *)task {
    NSParameterAssert(task);
    
    if (task != self.task) {
        self.task = task;
        
        self.activityView.hidden = NO;
        self.activityView.animating = YES;
        
        __weak typeof(self) weakSelf = self;
        AFAFormServices *formService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFormServices];
        
        [formService requestSetupWithTaskModel:self.task
                         renderCompletionBlock:^(UICollectionViewController<ASDKFormControllerNavigationProtocol> *formController, NSError *error) {
             __strong typeof(self) strongSelf = weakSelf;
             
             if (!error) {
                 // Make sure we remove any references of old versions of the form controller
                 for (id childController in strongSelf.childViewControllers) {
                     if ([childController isKindOfClass:[UICollectionViewController class]]) {
                         [((UICollectionViewController *)childController).view removeFromSuperview];
                         [(UICollectionViewController *)childController removeFromParentViewController];
                     }
                 }
                 
                 formController.navigationDelegate = strongSelf;
                 strongSelf.formViewController = formController;
                 [strongSelf addChildViewController:formController];
                 
                 UIView *formView = formController.view;
                 formView.frame = strongSelf.view.bounds;
                 [formView setTranslatesAutoresizingMaskIntoConstraints:NO];
                 [strongSelf.view addSubview:formController.view];
                 
                 NSDictionary *views = NSDictionaryOfVariableBindings(formView);
                 
                 [strongSelf.view addConstraints:
                  [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[formView]|"
                                                          options:0
                                                          metrics:nil
                                                            views:views]];
                 [strongSelf.view addConstraints:
                  [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[formView]-%d-|", 40]
                                                          options:0
                                                          metrics:nil
                                                            views:views]];
             } else {
                 [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskFormCannotSetUpErrorText, @"Form set up error")];
             }
             
             strongSelf.activityView.animating = NO;
             strongSelf.activityView.hidden = YES;
         } formCompletionBlock:^(BOOL isFormCompleted, NSError *error) {
             __strong typeof(self) strongSelf = weakSelf;
             
             if (!isFormCompleted) {
                 [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskFormCannotSetUpErrorText, @"Form set up error")];
             } else {
                 if ([strongSelf.delegate respondsToSelector:@selector(userDidCompleteForm)]) {
                     [strongSelf.delegate userDidCompleteForm];
                 }
             }
         }];
    }
}


#pragma mark -
#pragma mark ASDKFormControllerNavigationProtocol

- (void)prepareToPresentDetailController:(UIViewController *)controller {
    if ([self.delegate respondsToSelector:@selector(presentFormDetailController:)]) {
        [self.delegate presentFormDetailController:controller];
    }
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
