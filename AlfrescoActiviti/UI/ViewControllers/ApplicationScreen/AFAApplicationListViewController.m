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

#import "AFAApplicationListViewController.h"

// Constants
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"
#import "AFAUIConstants.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"
#import "NSDate+AFAStringTransformation.h"
#import "UIColor+AFATheme.h"

// Views
#import "AFAActivityView.h"

// Cells
#import "AFAApplicationListStyleCell.h"

// Managers
#import "AFAAppServices.h"
#import "AFAServiceRepository.h"

// Controllers
#import "AFAListViewController.h"


typedef NS_ENUM(NSInteger, AFAApplicationListControllerState) {
    AFAApplicationListControllerStateIdle,
    AFAApplicationListControllerStateRefreshInProgress,
};

@interface AFAApplicationListViewController ()

@property (weak, nonatomic) IBOutlet UITableView                            *applicationListTableView;
@property (weak, nonatomic) IBOutlet AFAActivityView                        *activityView;
@property (weak, nonatomic) IBOutlet UILabel                                *noApplicationsLabel;
@property (weak, nonatomic) IBOutlet UIView                                 *refreshView;
@property (strong, nonatomic) UIRefreshControl                              *refreshControl;
@property (weak, nonatomic) IBOutlet UIButton *refreshButton;

// Internal state properties
@property (strong, nonatomic) NSArray                                       *applicationListArr;
@property (assign, nonatomic) AFAApplicationListControllerState             controllerState;
@property (assign, nonatomic) BOOL                                          queueRefreshOperation;

// KVO
@property (strong, nonatomic) ASDKKVOManager                                 *kvoManager;

@end

@implementation AFAApplicationListViewController


#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.applicationListArr = [NSMutableArray array];
        self.controllerState = AFAApplicationListControllerStateIdle;
        
        // Set up state bindings
        [self handleBindingsForAppListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Update navigation bar title
    self.navigationBarTitle = NSLocalizedString(kLocalizationAppScreenTitleText, @"Application title");
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.applicationListTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(fetchRuntimeApplicationList)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    self.refreshButton.titleLabel.font = [UIFont glyphiconFontWithSize:15];
    [self.refreshButton setTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeRefresh]
                        forState:UIControlStateNormal];
    
    // Request the application list
    [self onRefresh:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    // Update the navigation bar theme color
    self.navigationBarThemeColor = [UIColor applicationThemeDefaultColor];
    
    if (self.queueRefreshOperation) {
        if (AFAApplicationListControllerStateRefreshInProgress != self.controllerState) {
            // Just show the activity view when a full screen reload is in progress
            // Use the pull-to-refresh mechanism otherwise
            self.controllerState = AFAApplicationListControllerStateRefreshInProgress;
            
            // Fetch runtime application list
            [self fetchRuntimeApplicationList];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - 
#pragma mark Actions

- (IBAction)onRefresh:(id)sender {
    self.refreshView.hidden = YES;
    self.noApplicationsLabel.hidden = YES;
    
    // Just show the activity view when a full screen reload is in progress
    // Use the pull-to-refresh mechanism otherwise
    self.controllerState = AFAApplicationListControllerStateRefreshInProgress;
    
    // Fetch runtime application list
    [self fetchRuntimeApplicationList];
}

- (IBAction)onMenu:(id)sender {
    [self toggleMenu:sender];
}


#pragma mark - 
#pragma mark Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    if ([kSegueIDList isEqualToString:segue.identifier]) {
        AFAListViewController *taskListViewController = (AFAListViewController *)segue.destinationViewController;
        taskListViewController.currentApp = self.applicationListArr[[self.applicationListTableView indexPathForCell:(UITableViewCell *)sender].row];
    }
}

- (IBAction)unwindApplicationListController:(UIStoryboardSegue *)segue {
    self.queueRefreshOperation = YES;
}


#pragma mark -
#pragma mark Service integration

- (void)fetchRuntimeApplicationList {
    __weak typeof(self) weakSelf = self;
    AFAAppServices *appServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeAppServices];
    [appServices requestRuntimeAppDefinitionsWithCompletionBlock:^(NSArray *appDefinitionsList, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        strongSelf.controllerState = AFAApplicationListControllerStateIdle;
        if (!error) {
            // Store application list
            strongSelf.applicationListArr =  appDefinitionsList;
            
            // Check if we got an empty list
            strongSelf.noApplicationsLabel.hidden = strongSelf.applicationListArr.count;
            strongSelf.applicationListTableView.hidden = strongSelf.applicationListArr.count ? NO : YES;
            strongSelf.refreshView.hidden = strongSelf.applicationListArr.count;
            
            // Reload table data
            [strongSelf.applicationListTableView reloadData];
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
        } else {
            strongSelf.noApplicationsLabel.hidden = NO;
            strongSelf.applicationListTableView.hidden = YES;
            strongSelf.refreshView.hidden = NO;
            
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
        
        if (strongSelf.refreshControl.isRefreshing) {
            [strongSelf.refreshControl endRefreshing];
        }
        
        strongSelf.queueRefreshOperation = NO;
    }];
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.applicationListArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFAApplicationListStyleCell *applicationCell = [tableView dequeueReusableCellWithIdentifier:kCellIDApplicationListStyle];
    // Set up the cell with task details
    [applicationCell setupWithApplication:self.applicationListArr[indexPath.row]];
    
    return applicationCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    [self performSegueWithIdentifier:kSegueIDList
                              sender:[tableView cellForRowAtIndexPath:indexPath]];
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
                                 
                                 AFAApplicationListControllerState controllerState = [change[NSKeyValueChangeNewKey] boolValue];
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     if (AFAApplicationListControllerStateRefreshInProgress == controllerState) {
                                         strongSelf.applicationListTableView.hidden = YES;
                                     } else {
                                         // Check if there are any results to show before showing the task list tableview
                                         strongSelf.applicationListTableView.hidden = strongSelf.applicationListArr.count ? NO : YES;
                                     }
                                     strongSelf.activityView.hidden = (AFAApplicationListControllerStateRefreshInProgress == controllerState) ? NO : YES;
                                     strongSelf.activityView.animating = (AFAApplicationListControllerStateRefreshInProgress == controllerState) ? YES : NO;
                                 });
                             }];
}


@end
