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

#import "AFAProcessStartFormViewController.h"
@import ActivitiSDK;

// Categories
#import "UIViewController+AFAAlertAddition.h"

// Constants
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"
#import "AFAUIConstants.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAFormServices.h"

// Views
#import "AFAActivityView.h"

@interface AFAProcessStartFormViewController () <ASDKFormControllerNavigationProtocol>

@property (weak, nonatomic)   IBOutlet AFAActivityView      *activityView;

// Internal state properties
@property (strong, nonatomic) ASDKModelProcessDefinition    *processDefinition;
@property (strong, nonatomic) UICollectionViewController    *formViewController;

@end

@implementation AFAProcessStartFormViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Actions

- (void)startFormForProcessDefinitionObject:(ASDKModelProcessDefinition *)processDefinition {
    NSParameterAssert(processDefinition);
    
    if (processDefinition != self.processDefinition) {
        self.processDefinition = processDefinition;
        
        self.activityView.hidden = NO;
        self.activityView.animating = YES;
        
        __weak typeof(self) weakSelf = self;
        AFAFormServices *formService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFormServices];
        [formService requestSetupWithProcessDefinition:processDefinition
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
                 [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[formView]-%d-|", 0]
                                                         options:0
                                                         metrics:nil
                                                           views:views]];
            } else {
                [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskFormCannotSetUpErrorText, @"Form set up error")];
            }
            
            strongSelf.activityView.animating = NO;
            strongSelf.activityView.hidden = YES;
        } formCompletionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
            __strong typeof(self) strongSelf = weakSelf;
            
            if (error) {
                [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskFormCannotSetUpErrorText, @"Form set up error")];
            } else {
                if ([self.delegate respondsToSelector:@selector(didCompleteFormWithProcessInstance:)]) {
                    [self.delegate didCompleteFormWithProcessInstance:processInstance];
                }
            }
        }];
    }
}

#pragma mark -
#pragma mark ASDKFormControllerNavigationProtocol

- (void)prepareToPresentDetailController:(UIViewController *)controller {
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft]
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(popFormDetailController)];
    [backButton setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                         NSForegroundColorAttributeName: [UIColor whiteColor]}
                              forState:UIControlStateNormal];
    [self.navigationItem setBackBarButtonItem:backButton];
    
    controller.navigationItem.leftBarButtonItem = backButton;
    [self.navigationController pushViewController:controller
                                         animated:YES];
}

- (void)popFormDetailController {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
