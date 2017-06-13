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

// Controllers
#import "AFAListViewController.h"
#import "AFAFilterViewController.h"
#import "AFATaskDetailsViewController.h"
#import "AFAStartProcessInstanceViewController.h"
#import "AFAProcessInstanceDetailsViewController.h"
#import "AFAModalTaskDetailsViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"
#import "AFALocalizationConstants.h"

// Categories
#import "UIColor+AFATheme.h"
#import "NSDate+AFAStringTransformation.h"
#import "UIView+AFAViewAnimations.h"
#import "UIViewController+AFAAlertAddition.h"
#import "UIView+AFAImageEffects.h"

// Models
#import "AFAGenericFilterModel.h"
#import "ASDKModelTask.h"

// View models
#import "AFATaskListViewModel.h"
#import "AFAProcessListViewModel.h"

// Data sources
#import "AFATaskListViewDataSource.h"
#import "AFAProcessListViewDataSource.h"
#import "AFAProcessInstanceDetailsDataSource.h"
#import "AFATaskDetailsDataSource.h"

// Managers
#import "AFATaskServices.h"
#import "AFAProcessServices.h"
#import "AFAServiceRepository.h"
#import "AFAModalTaskDetailsCreateTaskAction.h"
@import ActivitiSDK;

// Views
#import "ASDKRoundedBorderView.h"
#import "AFAActivityView.h"

// Segues
#import "AFAPushFadeSegueUnwind.h"

typedef NS_ENUM(NSInteger, AFAListControllerState) {
    AFAListControllerStateIdle,
    AFAListControllerStateRefreshInProgress,
};

typedef NS_ENUM(NSInteger, AFAListButtonType) {
    AFAListButtonTypeUndefined          = -1,
    AFAListButtonTypeTasks              = 0,
    AFAListButtonTypeProcessInstances
};


@interface AFAListViewController () <AFAFilterViewControllerDelegate,
AFAModalTaskDetailsViewControllerDelegate,
UITextFieldDelegate,
UITableViewDelegate>

// Task list related
@property (weak, nonatomic)   IBOutlet UITableView                          *listTableView;
@property (weak, nonatomic)   IBOutlet UILabel                              *noRecordsLabel;
@property (weak, nonatomic)   IBOutlet UIView                               *refreshView;
@property (weak, nonatomic)   IBOutlet ASDKRoundedBorderView                *searchView;
@property (strong, nonatomic) UIRefreshControl                              *refreshControl;
@property (strong, nonatomic) IBOutlet UIView                               *loadingFooterView;
@property (weak, nonatomic)   IBOutlet AFAActivityView                      *preloadingActivityView;
@property (weak, nonatomic)   IBOutlet AFAActivityView                      *loadingActivityView;
@property (weak, nonatomic)   IBOutlet UITextField                          *searchTextField;
@property (weak, nonatomic)   IBOutlet UIBarButtonItem                      *backBarButtonItem;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskListButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *processListButton;
@property (weak, nonatomic)   IBOutlet UIView                               *underlineView;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *underlineTaskListButtonConstraint;

// Advanced search related
@property (weak, nonatomic)   IBOutlet UIButton                             *advancedSearchButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *refreshButton;
@property (weak, nonatomic)   IBOutlet UIView                               *advancedSearchOverlayView;
@property (weak, nonatomic)   IBOutlet UIView                               *advancedFilterContainerView;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *advancedSearchContainerTopConstraint;
@property (strong, nonatomic) AFAFilterViewController                       *filterViewController;
@property (weak, nonatomic)   IBOutlet ASDKRoundedBorderView                *advancedSearchRoundedBorderView;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *advancedSearchContainerHeightConstraint;

// Internal state properties
@property (strong, nonatomic) AFAGenericFilterModel                         *currentFilter;
@property (strong, nonatomic) AFAListHandleCompletionBlock                  listResponseCompletionBlock;
@property (assign, nonatomic) AFAListControllerState                        controllerState;
@property (assign, nonatomic) BOOL                                          isAdvancedSearchInProgress;
@property (strong, nonatomic) id<AFAListDataSourceProtocol>                 dataSource;
@property (strong, nonatomic) AFAListBaseViewModel                          *currentListViewModel;

// KVO
@property (strong, nonatomic) ASDKKVOManager                                *kvoManager;

@end

@implementation AFAListViewController


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        _controllerState = AFAListControllerStateIdle;
        
        // Set up state bindings
        [self handleBindingsForTaskListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Prepare the layout for the set content type
    self.navigationBarTitle = [self.currentListViewModel navigationBarTitle];
    self.navigationBarThemeColor = [self.currentListViewModel navigationBarThemeColor];
    
    // Register the application color with the SDK color scheme
    ASDKBootstrap *sdkBootStrap = [ASDKBootstrap sharedInstance];
    ASDKFormColorSchemeManager *colorSchemeManager = [sdkBootStrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormColorSchemeManagerProtocol)];
    colorSchemeManager.navigationBarThemeColor = self.navigationBarThemeColor;
    colorSchemeManager.navigationBarTitleAndControlsColor = [UIColor whiteColor];
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.listTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(refreshContentList)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    self.listTableView.estimatedRowHeight = 78.0f;
    self.listTableView.rowHeight = UITableViewAutomaticDimension;
    self.listTableView.tableFooterView = nil;
    
    // Set up list table view delegates and data source
    self.dataSource = [[AFATaskListViewDataSource alloc] initWithDataEntries:nil
                                                                  themeColor:self.navigationBarThemeColor];
    self.listTableView.dataSource = self.dataSource;
    self.listTableView.delegate = self;
    
    self.advancedFilterContainerView.hidden = YES;
    
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
    self.refreshButton.titleLabel.font = [UIFont glyphiconFontWithSize:15];
    [self.refreshButton setTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeRefresh]
                        forState:UIControlStateNormal];
    
    self.taskListButton.tag = AFAListButtonTypeTasks;
    self.processListButton.tag = AFAListButtonTypeProcessInstances;
    
    // Update the controller's state - Waiting for input from the filter controller
    [self updateSceneForCurrentViewModel];
    self.controllerState = AFAListControllerStateRefreshInProgress;
    
    // Define the handler for task and process requests
    __weak typeof(self) weakSelf = self;
    self.listResponseCompletionBlock = ^(id<AFAListDataSourceProtocol>dataSource, NSArray *objectList, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        strongSelf.controllerState = AFAListControllerStateIdle;
        
        // Make sure the handling is performed for the current active data source
        if ([dataSource class] != [strongSelf.dataSource class]) {
                return;
            }
        
        if (!error) {
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
            
            [strongSelf.dataSource processAdditionalEntries:objectList
                                                  forPaging:paging];
            NSArray *objectListForCurrentContentType = strongSelf.dataSource.dataEntries;
            
            // Check if we got an empty list
            strongSelf.noRecordsLabel.hidden = objectListForCurrentContentType.count;
            strongSelf.listTableView.hidden = objectListForCurrentContentType.count ? NO : YES;
            strongSelf.refreshView.hidden = objectListForCurrentContentType.count;
            
            [strongSelf.listTableView reloadData];
        } else {
            strongSelf.noRecordsLabel.hidden = NO;
            strongSelf.listTableView.hidden = YES;
            strongSelf.refreshView.hidden = NO;
            
            [strongSelf.dataSource processAdditionalEntries:nil
                                                  forPaging:nil];
            [strongSelf.listTableView reloadData];
            
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        // If an activity indicator is present in the table's footer view remove it
        if (strongSelf.listTableView.tableFooterView) {
            [UIView beginAnimations:nil
                            context:NULL];
            strongSelf.preloadingActivityView.animating = NO;
            strongSelf.listTableView.tableFooterView = nil;
            [UIView commitAnimations];
        }
    };
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self searchWithTerm:self.searchTextField.text];
}


#pragma mark -
#pragma mark Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    if ([kSegueIDAdvancedSearchMenuEmbedding isEqualToString:segue.identifier]) {
        self.filterViewController = (AFAFilterViewController *)segue.destinationViewController;
        if (!self.currentListViewModel) {
            self.currentListViewModel = self.taskListViewModel;
        }
        self.filterViewController.currentApp = self.currentListViewModel.application;
        self.filterViewController.delegate = self;
    }
    
    if ([kSegueIDTaskDetails isEqualToString:segue.identifier]) {
        AFATaskDetailsViewController *detailsViewController = (AFATaskDetailsViewController *)segue.destinationViewController;
        
        ASDKModelTask *currentSelectedTask = self.dataSource.dataEntries[[self.listTableView indexPathForCell:(UITableViewCell *)sender].row];
        AFATaskDetailsDataSource *taskDetailsDataSource = [[AFATaskDetailsDataSource alloc] initWithTaskID:currentSelectedTask.modelID
                                                                                                themeColor:self.navigationBarThemeColor];
        
        detailsViewController.dataSource = taskDetailsDataSource;
    }
    
    if ([kSegueIDStartProcessInstance isEqualToString:segue.identifier]) {
        AFAStartProcessInstanceViewController *startProcessInstanceViewController = (AFAStartProcessInstanceViewController *)segue.destinationViewController;
        startProcessInstanceViewController.appID = self.currentListViewModel.application.modelID;
        startProcessInstanceViewController.navigationBarThemeColor = self.navigationBarThemeColor;
    }
    
    if ([kSegueIDProcessInstanceDetails isEqualToString:segue.identifier]) {
        AFAProcessInstanceDetailsViewController *processInstanceDetailsController = (AFAProcessInstanceDetailsViewController *)segue.destinationViewController;
        ASDKModelProcessInstance *currentSelectedProcessInstance = self.dataSource.dataEntries[[self.listTableView indexPathForCell:(UITableViewCell *)sender].row];
        AFAProcessInstanceDetailsDataSource *processInstanceDetailsDataSource =
        [[AFAProcessInstanceDetailsDataSource alloc] initWithProcessInstanceID:currentSelectedProcessInstance.modelID
                                                                    themeColor:self.navigationBarThemeColor];
        
        processInstanceDetailsController.dataSource = processInstanceDetailsDataSource;
        processInstanceDetailsController.unwindActionType = AFAProcessInstanceDetailsUnwindActionTypeProcessList;
    }
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDListUnwind isEqualToString:identifier]) {
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

- (IBAction)unwindTaskListController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindStartProcessInstanceController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindProcessInstanceDetailsController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindStartFormProcessInstanceDetailsController:(UIStoryboardSegue *)segue {
}


#pragma mark -
#pragma mark Actions

- (IBAction)onRefresh:(id)sender {
    // Perform the refresh operation only when there is a filter available
    if (self.currentFilter) {
        self.refreshView.hidden = YES;
        self.noRecordsLabel.hidden = YES;
        
        [self searchWithTerm:self.searchTextField.text];
    }
}

- (IBAction)onAdvancedSearch:(id)sender {
    [self toggleAdvancedSearchView];
}

- (void)refreshContentList {
    // Remove any filter information so that all record entries could be
    // re-fetched any checked for updates
    self.searchTextField.text = nil;
    self.currentFilter.page = 0;
    [self fetchContentListWithCompletionBlock:self.listResponseCompletionBlock];
}

- (IBAction)onContentOverlayTap:(id)sender {
    [self handleToggleEventOnContentOnverlayView];
}

- (IBAction)onSectionChange:(UIButton *)sender {
    AFAListBaseViewModel *viewModelToLoad = nil;
    if (AFAListButtonTypeTasks == sender.tag) {
        viewModelToLoad = self.taskListViewModel;
        self.dataSource = [[AFATaskListViewDataSource alloc] initWithDataEntries:nil
                                                                      themeColor:self.navigationBarThemeColor];
    } else {
        viewModelToLoad = self.processListViewModel;
        self.dataSource = [[AFAProcessListViewDataSource alloc] initWithDataEntries:nil
                                                                         themeColor:self.navigationBarThemeColor];
    }
    
    if (viewModelToLoad != self.currentListViewModel) {
        self.controllerState = AFAListControllerStateRefreshInProgress;
        self.listTableView.contentOffset = CGPointZero;
        self.searchTextField.text = nil;
        
        self.currentListViewModel = viewModelToLoad;
        self.listTableView.dataSource = self.dataSource;
        [self updateSceneForCurrentViewModel];
        [self animateUnderlineContentSectionForType:sender.tag];
        
        // Fetch the filter list according to what section the user selected
        [self.dataSource loadFilterListForController:self.filterViewController];
    }
}

- (IBAction)onAdd:(UIBarButtonItem *)sender {
    if (self.processListViewModel == self.currentListViewModel) {
        [self performSegueWithIdentifier:kSegueIDStartProcessInstance
                                  sender:sender];
    } else {
        AFAModalTaskDetailsViewController *addTaskController = [self.storyboard instantiateViewControllerWithIdentifier:kStoryboardIDModalTaskDetailsViewController];
        addTaskController.alertTitle = NSLocalizedString(kLocalizationAddTaskScreenTitleText, @"New task title");
        addTaskController.confirmButtonTitle = NSLocalizedString(kLocalizationAddTaskScreenCreateButtonText, @"Confirm button");
        addTaskController.applicationID = self.currentListViewModel.application.modelID;
        addTaskController.appThemeColor = self.navigationBarThemeColor;
        addTaskController.delegate = self;
        
        AFAModalTaskDetailsCreateTaskAction *createTaskAction = [AFAModalTaskDetailsCreateTaskAction new];
        addTaskController.confirmAlertAction =  createTaskAction;
        
        addTaskController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        addTaskController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        [self presentViewController:addTaskController
                           animated:YES
                         completion:nil];
    }
}


#pragma mark -
#pragma mark Content handling

- (void)fetchContentListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    // Based on the chosen list content type fetch the list of tasks or the process
    // instance list with the default filter provided by the filter controller
    self.currentFilter.size = kDefaultTaskListFetchSize;
    [self.dataSource loadContentListForFilter:self.currentFilter
                          withCompletionBlock:completionBlock];
}

- (void)fetchListForSearchTerm:(NSString *)searchTerm
           withCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    // Pass the existing defined filter
    self.currentFilter.text = searchTerm;
    self.currentFilter.page = 0;
    self.currentFilter.appDefinitionID = self.currentListViewModel.application.modelID;
    
    [self fetchContentListWithCompletionBlock:completionBlock];
}

- (void)fetchNextPageForCurrentListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    self.currentFilter.page += 1;
    [self fetchContentListWithCompletionBlock:completionBlock];
}


#pragma mark -
#pragma mark AFAFilterViewController Delegate

- (void)filterModelsDidLoadWithDefaultFilter:(AFAGenericFilterModel *)filterModel
                                  filterType:(AFAFilterType)filterType {
    // If no filter information is found don't continue with further requests
    if (!filterModel) {
        self.controllerState = AFAListControllerStateIdle;
        self.noRecordsLabel.hidden = NO;
        self.listTableView.hidden = YES;
        self.refreshView.hidden = NO;
        
        [self showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
    } else {
        if ((AFAFilterTypeTask == filterType &&
             [self.dataSource isKindOfClass:[AFATaskListViewDataSource class]]) ||
            (AFAFilterTypeProcessInstance == filterType &&
             [self.dataSource isKindOfClass:[AFAProcessListViewDataSource class]])) {
                // Store the filter reference for further reuse
                self.currentFilter = filterModel;
                [self fetchContentListWithCompletionBlock:self.listResponseCompletionBlock];
            }
    }
}

- (void)searchWithFilterModel:(AFAGenericFilterModel *)filterModel {
    self.listTableView.contentOffset = CGPointZero;
    
    // Store the filter returned by the task filter controller
    // and check also for values written inside the search box
    self.currentFilter = filterModel;
    
    [self searchWithTerm:self.searchTextField.text];
    [self handleToggleEventOnContentOnverlayView];
}

- (void)searchWithTerm:(NSString *)term {
    if (self.currentFilter) {
        self.controllerState = AFAListControllerStateRefreshInProgress;
        
        [self fetchListForSearchTerm:term
                 withCompletionBlock:self.listResponseCompletionBlock];
    }
}

- (void)clearFilterInputText {
    self.searchTextField.text = nil;
}


#pragma mark -
#pragma mark AFAModalTaskDetailsViewControllerDelegate Delegate

- (void)didCreateTask:(ASDKModelTask *)task {
    [self.listTableView setContentOffset:CGPointZero
                                animated:NO];
    [self searchWithTerm:self.searchTextField.text];
}


#pragma mark -
#pragma mark Animations

- (void)handleToggleEventOnContentOnverlayView {
    // Check whether the overlay is displayed within a search context or
    // and advanced search context
    if (self.isAdvancedSearchInProgress) {
        [self toggleAdvancedSearchView];
    } else {
        [self toggleContentTransparentOverlay];
        [self.view endEditing:YES];
    }
}

- (void)toggleAdvancedSearchView {
    // Resign keyboard if transitioning from an active advanced search
    if (self.isAdvancedSearchInProgress) {
        [self.view endEditing:YES];
        [self.filterViewController rollbackFilterValuesToFilter:self.currentFilter];
    }
    
    // Switch state
    self.isAdvancedSearchInProgress = !self.isAdvancedSearchInProgress;
    self.advancedSearchRoundedBorderView.backgroundColor = self.isAdvancedSearchInProgress ? self.navigationBarThemeColor : [UIColor whiteColor];
    [self.advancedSearchButton setTitleColor:self.isAdvancedSearchInProgress ? [UIColor whiteColor] : [UIColor darkGreyTextColor]
                                    forState:UIControlStateNormal];
    
    // Make sure the advanced filter container view is visible
    // before animating
    self.advancedFilterContainerView.hidden = NO;
    
    // Compute updated constraint value
    CGFloat advancedSearchContainerTopConstraintValue = CGRectGetHeight(self.advancedFilterContainerView.frame) + CGRectGetHeight(self.searchView.frame);
    self.advancedSearchContainerTopConstraint.constant = self.isAdvancedSearchInProgress ? -30 : -advancedSearchContainerTopConstraintValue;
    
    CGFloat maximumAdmittedHeightForFilterView = CGRectGetHeight(self.view.frame) - 10;
    self.advancedSearchContainerHeightConstraint.constant = [self.filterViewController contentSizeForFilterView].height > maximumAdmittedHeightForFilterView ? maximumAdmittedHeightForFilterView : [self.filterViewController contentSizeForFilterView].height;
    
    [self toggleContentTransparentOverlay];
    
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:.0f
         usingSpringWithDamping:.7f
          initialSpringVelocity:5.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         //  If the advanced search in not active anymore then hide the containing container
                         if (!self.isAdvancedSearchInProgress) {
                             self.advancedFilterContainerView.hidden = YES;
                         }
                     }];
}

- (void)toggleContentTransparentOverlay {
    CGFloat overlayAlphaValue = self.isAdvancedSearchInProgress ? .5f : self.advancedSearchOverlayView.alpha ? .0f : .5f;
    
    [self.advancedSearchOverlayView animateAlpha:overlayAlphaValue
                                    withDuration:kOverlayAlphaChangeTime
                             withCompletionBlock:nil];
}

- (void)animateUnderlineContentSectionForType:(AFAListButtonType)buttonType {
    // The order of enabling, disabling the constraints matter so we are obliged
    // to write the longer version for these checks
    switch (buttonType) {
        case AFAListButtonTypeTasks: {
            self.underlineTaskListButtonConstraint.priority = UILayoutPriorityDefaultHigh;
        }
            break;
            
        case AFAListButtonTypeProcessInstances: {
            self.underlineTaskListButtonConstraint.priority = UILayoutPriorityFittingSizeLevel;
        }
            break;
            
        default: break;
    }
    
    self.processListButton.tintColor = (AFAListButtonTypeProcessInstances == buttonType) ? [UIColor enabledControlColor] : [UIColor disabledControlColor];
    self.taskListButton.tintColor = (AFAListButtonTypeTasks == buttonType) ? [UIColor enabledControlColor] : [UIColor disabledControlColor];
    
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:5.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:nil];
}


#pragma mark -
#pragma mark UITextField Delegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [self toggleContentTransparentOverlay];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self searchWithTerm:textField.text];
    [self handleToggleEventOnContentOnverlayView];
    
    return YES;
}


#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    if ([tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [tableView setLayoutMargins:UIEdgeInsetsZero];
    }
    
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
    
    // If we've reached the preload cell trigger a request for the new page
    if (self.dataSource.preloadCellIdx &&
        self.dataSource.preloadCellIdx == indexPath.row &&
        self.currentFilter.page < self.dataSource.totalPages) {
        // Display the activity view at the end of the table while content is fetched
        tableView.tableFooterView = self.loadingFooterView;
        self.preloadingActivityView.animating = YES;
        [self fetchNextPageForCurrentListWithCompletionBlock:self.listResponseCompletionBlock];
    }
}

// Hide cell separators after the last row with content
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return .01f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.dataSource isKindOfClass:[AFATaskListViewDataSource class]]) {
        [self performSegueWithIdentifier:kSegueIDTaskDetails
                                  sender:[tableView cellForRowAtIndexPath:indexPath]];
    } else {
        [self performSegueWithIdentifier:kSegueIDProcessInstanceDetails
                                  sender:[tableView cellForRowAtIndexPath:indexPath]];
    }
}


#pragma mark -
#pragma mark View model related

- (void)updateSceneForCurrentViewModel {
    self.noRecordsLabel.text = [self.currentListViewModel noRecordsLabelText];
    self.searchTextField.placeholder = [self.currentListViewModel searchTextFieldPlacholderText];
}


#pragma mark -
#pragma mark KVO bindings

- (void)handleBindingsForTaskListViewController {
    self.kvoManager = [ASDKKVOManager managerWithObserver:self];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:self
                        forKeyPath:NSStringFromSelector(@selector(controllerState))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 AFAListControllerState controllerState = [change[NSKeyValueChangeNewKey] boolValue];
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     if (AFAListControllerStateRefreshInProgress == controllerState) {
                                         strongSelf.listTableView.hidden = YES;
                                         strongSelf.refreshView.hidden = YES;
                                         strongSelf.noRecordsLabel.hidden = YES;
                                     } else {
                                         // Check if there are any results to show before showing the task list tableview
                                         strongSelf.listTableView.hidden = strongSelf.dataSource.dataEntries.count ? NO : YES;
                                     }
                                     strongSelf.loadingActivityView.hidden = (AFAListControllerStateRefreshInProgress == controllerState) ? NO : YES;
                                     strongSelf.loadingActivityView.animating = (AFAListControllerStateRefreshInProgress == controllerState) ? YES : NO;
                                 });
                             }];
}

@end
