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

#import "AFAStartProcessInstanceViewController.h"
@import ActivitiSDK;

// Constants
#import "AFALocalizationConstants.h"
#import "AFAUIConstants.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"
#import "NSDate+AFAStringTransformation.h"

// Managers
#import "AFAProcessServices.h"
#import "AFAServiceRepository.h"
#import "AFAFormServices.h"

// Views
#import "AFAActivityView.h"
#import <JGProgressHUD/JGProgressHUD.h>

// Cells
#import "AFAProcessDefinitionListStyleTableViewCell.h"

// Segues
#import "AFAPushFadeSegueUnwind.h"

// Controllers
#import "AFAProcessStartFormViewController.h"
#import "AFAProcessInstanceDetailsViewController.h"

typedef NS_OPTIONS(NSUInteger, AFAStartProcessInstanceLoadingState) {
    AFAStartProcessInstanceLoadingStateIdle                          = 1<<0,
    AFAStartProcessInstanceLoadingStatePullToRefreshInProgress       = 1<<1,
    AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress      = 1<<2
};

@interface AFAStartProcessInstanceViewController () <AFAProcessStartFormViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem                    *backBarButtonItem;
@property (weak, nonatomic) IBOutlet UITableView                        *processTableView;
@property (weak, nonatomic) IBOutlet UILabel                            *noRecordsLabel;
@property (weak, nonatomic) IBOutlet AFAActivityView                    *loadingActivityView;
@property (strong, nonatomic) UIRefreshControl                          *refreshControl;
@property (strong, nonatomic) JGProgressHUD                             *progressHUD;
@property (weak, nonatomic) IBOutlet UIView                             *formViewContainer;
@property (strong, nonatomic) AFAProcessStartFormViewController         *processStartFormController;

// Internal state properties
@property (strong, nonatomic) NSArray                                   *processDefinitionsArr;
@property (assign, nonatomic) AFAStartProcessInstanceLoadingState       controllerState;
@property (strong, nonatomic) AFAProcessDefinitionListCompletionBlock   processDefinitionCompletionBlock;

// KVO
@property (strong, nonatomic) ASDKKVOManager                             *kvoManager;

@end

@implementation AFAStartProcessInstanceViewController


#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState |= AFAStartProcessInstanceLoadingStateIdle;
        self.progressHUD = [self configureProgressHUD];
        
        // Set up state bindings
        [self handleBindingsForStartProcessInstanceViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up the task list table view to adjust it's size automatically
    self.processTableView.estimatedRowHeight = 60.0f;
    self.processTableView.rowHeight = UITableViewAutomaticDimension;
    
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
    self.navigationBarTitle = NSLocalizedString(kLocalizationProcessInstanceStartNewInstanceTitleText, @"Start process screen title");
    self.noRecordsLabel.text = NSLocalizedString(kLocalizationStartProcessInstanceScreenNoResultsText, @"No records available text");
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.processTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(onPullToRefresh)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;

    __weak typeof(self) weakSelf = self;
    self.processDefinitionCompletionBlock = ^(NSArray *processDefinitions, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            strongSelf.processDefinitionsArr = processDefinitions;
            
            // Check if we got an empty list
            strongSelf.noRecordsLabel.hidden = processDefinitions.count ? YES : NO;
            strongSelf.processTableView.hidden = processDefinitions.count ? NO : YES;
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
            
            // Reload table data
            [strongSelf.processTableView reloadData];
        } else {
            strongSelf.noRecordsLabel.hidden = NO;
            strongSelf.processTableView.hidden = YES;
            
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        strongSelf.controllerState &= ~AFAStartProcessInstanceLoadingStatePullToRefreshInProgress;
        strongSelf.controllerState &= ~AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress;
    };
    
    if (self.appID) {
        [self fetchProcessDefinitionsForAppID:self.appID
                          withCompletionBlock:self.processDefinitionCompletionBlock];
    } else {
        [self fetchProcessDefinitionsWithCompletionBlock:self.processDefinitionCompletionBlock];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    if ([kSegueIDProcessStartFormEmbedding isEqualToString:segue.identifier]) {
        self.processStartFormController = (AFAProcessStartFormViewController *)segue.destinationViewController;
        self.processStartFormController.navigationBarThemeColor = self.navigationBarThemeColor;
        self.processStartFormController.delegate = self;
    }
    
    if ([kSegueIDProcessInstanceStartForm isEqualToString:segue.identifier]) {
        AFAProcessInstanceDetailsViewController *processInstanceDetailsController = (AFAProcessInstanceDetailsViewController *)segue.destinationViewController;
        processInstanceDetailsController.processInstanceID = [(ASDKModelProcessInstance *)sender instanceID];
        processInstanceDetailsController.navigationBarThemeColor = self.navigationBarThemeColor;
        processInstanceDetailsController.unwindActionType = AFAProcessInstanceDetailsUnwindActionTypeStartForm;
    }
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDStartProcessInstanceUnwind isEqualToString:identifier]) {
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

- (IBAction)onBack:(UIBarButtonItem *)sender {
    [self performSegueWithIdentifier:kSegueIDStartProcessInstanceUnwind
                              sender:sender];
}

- (void)onPullToRefresh {
    self.controllerState |= AFAStartProcessInstanceLoadingStatePullToRefreshInProgress;
    
    if (self.appID) {
        [self fetchProcessDefinitionsForAppID:self.appID
                          withCompletionBlock:self.processDefinitionCompletionBlock];
    } else {
        [self fetchProcessDefinitionsWithCompletionBlock:self.processDefinitionCompletionBlock];
    }
}


#pragma mark -
#pragma mark AFAProcessStartFormViewControllerDelegate

- (void)didCompleteFormWithProcessInstance:(ASDKModelProcessInstance *)processInstance {
    self.formViewContainer.hidden = YES;
    [self performSegueWithIdentifier:kSegueIDProcessInstanceStartForm
                              sender:processInstance];
}


#pragma mark -
#pragma mark Service integration

- (void)fetchProcessDefinitionsWithCompletionBlock:(AFAProcessDefinitionListCompletionBlock)completionBlock {
    if (!(AFAStartProcessInstanceLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress;
    }
    
    AFAProcessServices *processService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    [processService requestProcessDefinitionListWithCompletionBlock:completionBlock];
}

- (void)fetchProcessDefinitionsForAppID:(NSString *)appID
                    withCompletionBlock:(AFAProcessDefinitionListCompletionBlock)completionBlock {
    if (!(AFAStartProcessInstanceLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress;
    }
    
    AFAProcessServices *processService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    [processService requestProcessDefinitionListForAppID:appID
                                     withCompletionBlock:completionBlock];
}

- (void)startProcessInstanceForProcessDefinition:(ASDKModelProcessDefinition *)processDefinition {
    // Update the name of the process definition so that the process instance
    // name can include the change
    processDefinition.name = [processDefinition.name stringByAppendingFormat:@" - %@", [[NSDate date] processInstanceCreationDate]];
    if (processDefinition.hasStartForm) {
        self.formViewContainer.hidden = NO;
        self.navigationBarTitle = processDefinition.name;
        [self.processStartFormController startFormForProcessDefinitionObject:processDefinition];
    } else {
        AFAProcessServices *processService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
        
        [self showStarProcessProgressHUD];
        __weak typeof(self) weakSelf = self;
        [processService requestProcessInstanceStartForProcessDefinition:processDefinition
                                                        completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                                            __strong typeof(self) strongSelf = weakSelf;
                                                            
                                                            if (!error) {
                                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                    weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationSuccessText, @"Success text");
                                                                    weakSelf.progressHUD.detailTextLabel.text = nil;
                                                                    
                                                                    weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                                                                    weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                                                                });
                                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                    [weakSelf.progressHUD dismiss];
                                                                    [self onBack:nil];
                                                                });
                                                            } else {
                                                                [strongSelf.progressHUD dismiss];
                                                                [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                                            }
                                                        }];
    }
}


#pragma mark -
#pragma mark - Progress hud setup

- (JGProgressHUD *)configureProgressHUD {
    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
    JGProgressHUDFadeZoomAnimation *zoomAnimation = [JGProgressHUDFadeZoomAnimation animation];
    hud.animation = zoomAnimation;
    hud.layoutChangeAnimationDuration = .0f;
    hud.textLabel.text = [NSString stringWithFormat:NSLocalizedString(kLocalizationProcessInstanceStartInProgressText, @"Starting process text")];
    hud.indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    
    return hud;
}

- (void)showStarProcessProgressHUD {
    [self.progressHUD showInView:self.navigationController.view];
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.processDefinitionsArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFAProcessDefinitionListStyleTableViewCell *processDefinitionCell = [tableView dequeueReusableCellWithIdentifier:kCellIDProcessDefinitionListStyle];
    [processDefinitionCell setupWithProcessDefinition:self.processDefinitionsArr[indexPath.row]];
    processDefinitionCell.applicationThemeColor = self.navigationBarThemeColor;
    
    return processDefinitionCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self startProcessInstanceForProcessDefinition:self.processDefinitionsArr[indexPath.row]];
}


#pragma mark -
#pragma mark KVO bindings

- (void)handleBindingsForStartProcessInstanceViewController {
    self.kvoManager = [ASDKKVOManager managerWithObserver:self];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:self
                        forKeyPath:NSStringFromSelector(@selector(controllerState))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     strongSelf.processTableView.hidden = (AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                                     strongSelf.loadingActivityView.hidden = (AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? NO : YES;
                                     strongSelf.loadingActivityView.animating = (AFAStartProcessInstanceLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                                 });
                             }];
}


@end
