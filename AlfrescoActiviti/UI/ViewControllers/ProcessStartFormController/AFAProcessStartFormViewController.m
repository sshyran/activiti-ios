/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

// Segues
#import "AFAPushFadeSegueUnwind.h"

// Views
#import "AFAActivityView.h"

typedef NS_ENUM(NSInteger, AFAProcessStartFormQueueOperationType) {
    AFAProcessStartFormQueueOperationTypeUndefined         = -1,
    AFAProcessStartFormQueueOperationTypeNone              = 0,
    AFAProcessStartFormQueueOperationTypeProcessDefinition,
    AFAProcessStartFormQueueOperationTypeProcessInstance
};

@interface AFAProcessStartFormViewController () <ASDKFormControllerNavigationProtocol>

@property (weak, nonatomic) IBOutlet AFAActivityView                    *activityView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem                    *backBarButtonItem;

// Internal state properties
@property (strong, nonatomic) ASDKModelProcessDefinition                *processDefinition;
@property (strong, nonatomic) ASDKModelProcessInstance                  *processInstance;
@property (strong, nonatomic) UICollectionViewController                *formViewController;
@property (strong, nonatomic) AFAFormServicesEngineSetupCompletionBlock renderCompletionBlock;
@property (strong, nonatomic) AFAStartFormServicesEngineCompletionBlock formCompletionBlock;
@property (assign, nonatomic) AFAProcessStartFormQueueOperationType     queuedOperationType;

@end

@implementation AFAProcessStartFormViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.queuedOperationType = AFAProcessStartFormQueueOperationTypeUndefined;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
    
    __weak typeof(self) weakSelf = self;
    self.renderCompletionBlock =
    ^(UICollectionViewController<ASDKFormControllerNavigationProtocol> *formController, NSError *error) {
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
    };
    
    self.formCompletionBlock =
    ^(ASDKModelProcessInstance *processInstance, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (error) {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskFormCannotSetUpErrorText, @"Form set up error")];
        } else {
            if ([strongSelf.delegate respondsToSelector:@selector(didCompleteFormWithProcessInstance:)]) {
                [strongSelf.delegate didCompleteFormWithProcessInstance:processInstance];
            }
        }
    };
    
    switch (self.queuedOperationType) {
        case AFAProcessStartFormQueueOperationTypeProcessDefinition: {
            self.navigationBarTitle = self.processDefinition.name;
            [self setupStartFormForProcessDefinitionObject:self.processDefinition];
        }
            break;
            
        case AFAProcessStartFormQueueOperationTypeProcessInstance: {
            self.navigationBarTitle = self.processInstance.name;
            [self setupStartFormForProcessInstanceObject:self.processInstance];
        }
            break;
            
        default:
            break;
    }
    
    self.queuedOperationType = AFAProcessStartFormQueueOperationTypeNone;
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
    if ([kSegueIDProcessInstanceViewCompletedStartFormUnwind isEqualToString:identifier]) {
        AFAPushFadeSegueUnwind *unwindSegue = [AFAPushFadeSegueUnwind segueWithIdentifier:identifier
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
#pragma mark Actions

- (IBAction)onBack:(id)sender {
    [self performSegueWithIdentifier:kSegueIDProcessInstanceViewCompletedStartFormUnwind
                              sender:sender];
}

- (void)setupStartFormForProcessDefinitionObject:(ASDKModelProcessDefinition *)processDefinition {
    NSParameterAssert(processDefinition);
    
    if (self.queuedOperationType == AFAProcessStartFormQueueOperationTypeUndefined) {
        self.queuedOperationType = AFAProcessStartFormQueueOperationTypeProcessDefinition;
        self.processDefinition = processDefinition;
    } else {
        if (processDefinition != self.processDefinition ||
            self.queuedOperationType != AFAProcessStartFormQueueOperationTypeUndefined) {
            self.processDefinition = processDefinition;
            
            self.activityView.hidden = NO;
            self.activityView.animating = YES;
            
            AFAFormServices *formService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFormServices];
            [formService requestSetupWithProcessDefinition:processDefinition
                                     renderCompletionBlock:self.renderCompletionBlock
                                       formCompletionBlock:self.formCompletionBlock];
        }
    }
}

- (void)setupStartFormForProcessInstanceObject:(ASDKModelProcessInstance *)processInstance {
    NSParameterAssert(processInstance);
    
    if (self.queuedOperationType == AFAProcessStartFormQueueOperationTypeUndefined) {
        self.queuedOperationType = AFAProcessStartFormQueueOperationTypeProcessInstance;
        self.processInstance = processInstance;
    } else {
        if (processInstance != self.processInstance ||
            self.queuedOperationType != AFAProcessStartFormQueueOperationTypeUndefined) {
            self.processInstance = processInstance;
            
            self.activityView.hidden = NO;
            self.activityView.animating = YES;
            
            AFAFormServices *formService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFormServices];
            [formService requestSetupWithProcessInstance:processInstance
                                   renderCompletionBlock:self.renderCompletionBlock];
        }
    }
}


#pragma mark -
#pragma mark ASDKFormControllerNavigationProtocol

- (void)prepareToPresentDetailController:(UIViewController *)controller {
    // If no back button is provided by the sdk for the controller to be presented
    // then add a default one with a simple pop action
    if (!controller.navigationItem.leftBarButtonItem) {
        UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(popFormDetailController)];
        [backButton setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                             NSForegroundColorAttributeName: [UIColor whiteColor]}
                                  forState:UIControlStateNormal];
        controller.navigationItem.leftBarButtonItem = backButton;
    }
    
    [self.navigationController pushViewController:controller
                                         animated:YES];
}

- (UINavigationController *)formNavigationController {
    return self.navigationController;
}

- (void)popFormDetailController {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
