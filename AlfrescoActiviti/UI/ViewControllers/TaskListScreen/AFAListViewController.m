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

// Controllers
#import "AFAListViewController.h"
#import "AFAFilterViewController.h"
#import "AFATaskDetailsViewController.h"
#import "AFAStartProcessInstanceViewController.h"
#import "AFAProcessInstanceDetailsViewController.h"
#import "AFAAddTaskViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"
#import "AFALocalizationConstants.h"

// Cells
#import "AFATaskListStyleCell.h"

// Models
#import "AFAGenericFilterModel.h"
#import "ASDKModelTask.h"

// Managers
#import "AFATaskServices.h"
#import "AFAProcessServices.h"
#import "AFAServiceRepository.h"
@import ActivitiSDK;

// Categories
#import "UIColor+AFATheme.h"
#import "NSDate+AFAStringTransformation.h"
#import "UIView+AFAViewAnimations.h"
#import "UIViewController+AFAAlertAddition.h"
#import "UIView+AFAImageEffects.h"

// Views
#import "ASDKRoundedBorderView.h"
#import "AFAActivityView.h"

// Segues
#import "AFAPushFadeSegueUnwind.h"


typedef NS_ENUM(NSInteger, AFAListControllerState) {
    AFAListControllerStateIdle,
    AFAListControllerStateRefreshInProgress,
};

typedef void (^AFAListHandleCompletionBlock) (NSArray *objectList, NSError *error, ASDKModelPaging *paging);

@interface AFAListViewController () <AFAFilterViewControllerDelegate, UITextFieldDelegate, AFAAddTaskViewControllerDelegate>

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
@property (strong, nonatomic) NSArray                                       *taskListArr;
@property (strong, nonatomic) NSArray                                       *processListArr;
@property (assign, nonatomic) NSInteger                                     preloadCellIdx;
@property (assign, nonatomic) NSInteger                                     totalTaskPages;
@property (strong, nonatomic) AFAGenericFilterModel                         *currentFilter;
@property (strong, nonatomic) AFAListHandleCompletionBlock                  listResponseCompletionBlock;
@property (assign, nonatomic) AFAListControllerState                        controllerState;
@property (assign, nonatomic) BOOL                                          isAdvancedSearchInProgress;
@property (assign, nonatomic) AFAListContentType                            listContentType;

// KVO
@property (strong, nonatomic) ASDKKVOManager                                 *kvoManager;

@end

@implementation AFAListViewController


#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.taskListArr = [NSMutableArray array];
        self.processListArr = [NSMutableArray array];
        self.controllerState = AFAListControllerStateIdle;
        
        // Set up state bindings
        [self handleBindingsForTaskListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // The default view is showing the task list
    self.listContentType = AFAListContentTypeTasks;

    // Prepare the layout for the set content type
    [self prepareViewLayoutForListContentType:self.listContentType];
    [self updateSceneForListContentType:self.listContentType];
    
    // Update the controller's state - Waiting for input from the filter controller
    self.controllerState = AFAListControllerStateRefreshInProgress;
    
    // Define the handler for task and process requests
    __weak typeof(self) weakSelf = self;
    self.listResponseCompletionBlock = ^(NSArray *objectList, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        strongSelf.controllerState = AFAListControllerStateIdle;
        
        if (!error) {
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
            
            [strongSelf updateCurrentObjectListWithObjectList:objectList
                                           forListContentType:strongSelf.listContentType
                                                       paging:paging];
            
            
            NSArray *objectListForCurrentContentType = [strongSelf objectListForListContentType:strongSelf.listContentType];
            
            // Extract the total number task pages expected to be displayed
            strongSelf.totalTaskPages = ceilf((float) (paging).pageCount / objectListForCurrentContentType.count);
            
            // Compute the preload index that will trigger a new request
            if (strongSelf.totalTaskPages > 1) {
                strongSelf.preloadCellIdx = objectListForCurrentContentType.count - kTaskPreloadCellThreshold;
            } else {
                strongSelf.preloadCellIdx = 0;
            }
            
            // Check if we got an empty list
            strongSelf.noRecordsLabel.hidden = objectListForCurrentContentType.count;
            strongSelf.listTableView.hidden = objectListForCurrentContentType.count ? NO : YES;
            strongSelf.refreshView.hidden = objectListForCurrentContentType.count;
            
            // Reload table data
            [strongSelf.listTableView reloadData];
        } else {
            strongSelf.noRecordsLabel.hidden = NO;
            strongSelf.listTableView.hidden = YES;
            strongSelf.refreshView.hidden = NO;
            
            [strongSelf updateCurrentObjectListWithObjectList:nil
                                           forListContentType:strongSelf.listContentType
                                                       paging:nil];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark -
#pragma mark Controller wiring and setup methods

- (void)prepareViewLayoutForListContentType:(AFAListContentType)contentType {
    // Update navigation bar title and theme color according to the description of the app
    // if there's a defined one, otherwise this means we're displaying adhoc tasks
    if (!self.currentApp) {
        self.navigationBarTitle = NSLocalizedString(kLocalizationListScreenTaskAppText, @"Adhoc tasks title");
        self.navigationBarThemeColor = [UIColor applicationThemeDefaultColor];
    } else {
        self.navigationBarTitle = self.currentApp.name;
        self.navigationBarThemeColor = [UIColor applicationColorForTheme:self.currentApp.theme];
    }
    
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
    
    // Hide the filter view when not visible
    self.advancedFilterContainerView.hidden = YES;
    
    // Remove existing activiti footer view
    self.listTableView.tableFooterView = nil;
    
    // Set up the task list table view to adjust it's size automatically
    self.listTableView.estimatedRowHeight = 78.0f;
    self.listTableView.rowHeight = UITableViewAutomaticDimension;
    
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
    self.refreshButton.titleLabel.font = [UIFont glyphiconFontWithSize:15];
    [self.refreshButton setTitle:[NSString iconStringForIconType:ASDKGlyphIconTypeRefresh]
                        forState:UIControlStateNormal];
    
    self.taskListButton.tag = AFAListContentTypeTasks;
    self.processListButton.tag = AFAListContentTypeProcessInstances;
}

- (void)updateSceneForListContentType:(AFAListContentType)contentType {
    // Set up localization support
    self.noRecordsLabel.text = (AFAListContentTypeTasks == contentType) ? NSLocalizedString(kLocalizationListScreenNoTasksAvailableText, @"No tasks available text") : NSLocalizedString(kLocalizationProcessInstanceScreenNoProcessInstancesText, @"No process instances text");
    NSString *sectionName = (AFAListContentTypeTasks == contentType) ? NSLocalizedString(kLocalizationListScreenTasksText, @"tasks text") : NSLocalizedString(kLocalizationListScreenProcessInstancesText, @"process instances text");
    self.searchTextField.placeholder = [NSString stringWithFormat:NSLocalizedString(kLocalizationListScreenSearchFieldPlaceholderFormat, @"Search bar format"), sectionName];
}


#pragma mark -
#pragma mark Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    if ([kSegueIDAdvancedSearchMenuEmbedding isEqualToString:segue.identifier]) {
        self.filterViewController = (AFAFilterViewController *)segue.destinationViewController;
        self.filterViewController.currentApp = self.currentApp;
        self.filterViewController.delegate = self;
    }
    
    if ([kSegueIDTaskDetails isEqualToString:segue.identifier]) {
        AFATaskDetailsViewController *detailsViewController = (AFATaskDetailsViewController *)segue.destinationViewController;
        detailsViewController.navigationBarThemeColor = self.navigationBarThemeColor;
        
        ASDKModelTask *currentSelectedTask = self.taskListArr[[self.listTableView indexPathForCell:(UITableViewCell *)sender].row];
        detailsViewController.taskID = currentSelectedTask.modelID;
    }
    
    if ([kSegueIDStartProcessInstance isEqualToString:segue.identifier]) {
        AFAStartProcessInstanceViewController *startProcessInstanceViewController = (AFAStartProcessInstanceViewController *)segue.destinationViewController;
        startProcessInstanceViewController.appID = self.currentApp.modelID;
        startProcessInstanceViewController.navigationBarThemeColor = self.navigationBarThemeColor;
    }
    
    if ([kSegueIDProcessInstanceDetails isEqualToString:segue.identifier]) {
        AFAProcessInstanceDetailsViewController *processInstanceDetailsController = (AFAProcessInstanceDetailsViewController *)segue.destinationViewController;
        ASDKModelProcessInstance *currentSelectedProcessInstance = self.processListArr[[self.listTableView indexPathForCell:(UITableViewCell *)sender].row];
        processInstanceDetailsController.processInstanceID = currentSelectedProcessInstance.modelID;
        processInstanceDetailsController.navigationBarThemeColor = self.navigationBarThemeColor;
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
    if (sender.tag != self.listContentType) {
        self.listTableView.contentOffset = CGPointZero;
        // Perform the underline section animation before setting the new list content type
        // as the layout of subviews triggered by the animation will call the table view
        // delegate methods with the correct index but for the wrong collection of elements
        [self animateUnderlineContentSectionForType:sender.tag];
        
        // Remove any pre-filled search text when switching the category
        self.searchTextField.text = nil;
        
        // Fetch the filter list according to what section the user selected
        self.controllerState = AFAListControllerStateRefreshInProgress;
        self.listContentType = sender.tag;
        
        (AFAListContentTypeTasks == self.listContentType) ? [self.filterViewController loadTaskFilterList] : [self.filterViewController loadProcessInstanceFilterList];
        [self updateSceneForListContentType:self.listContentType];
    }
}

- (IBAction)onAdd:(UIBarButtonItem *)sender {
    if (AFAListContentTypeProcessInstances == self.listContentType) {
        [self performSegueWithIdentifier:kSegueIDStartProcessInstance
                                  sender:sender];
    } else if(AFAListContentTypeTasks == self.listContentType) {
        AFAAddTaskViewController *addTaskController = [self.storyboard instantiateViewControllerWithIdentifier:kStoryboardIDAddTaskViewController];
        addTaskController.applicationID = self.currentApp.modelID;
        addTaskController.appThemeColor = self.navigationBarThemeColor;
        addTaskController.delegate = self;
        addTaskController.controllerType = AFAAddTaskControllerTypePlainTask;
        
        addTaskController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
        addTaskController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        [self presentViewController:addTaskController
                           animated:YES
                         completion:nil];
    }
}


#pragma mark -
#pragma mark Service integration

- (void)fetchContentListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    // Based on the chosen list content type fetch the list of tasks or the process
    // instance list with the default filter provided by the filter controller
    switch (self.listContentType) {
        case AFAListContentTypeTasks: {
            [self fetchTaskListWithCompletionBlock:completionBlock];
        }
            break;
            
        case AFAListContentTypeProcessInstances: {
            [self fetchProcessInstanceListWithCompletionBlock:completionBlock];
        }
            break;
            
        default:
            break;
    }
}

- (void)fetchTaskListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    self.currentFilter.size = kDefaultTaskListFetchSize;
    
    __weak typeof(self) weakSelf = self;
    [taskService requestTaskListWithFilter:self.currentFilter
                       withCompletionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                           __strong typeof(self) strongSelf = weakSelf;
                           
                           if (AFAListContentTypeTasks == strongSelf.listContentType) {
                               completionBlock (taskList, error, paging);
                           }
    }];
}

- (void)fetchProcessInstanceListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    self.currentFilter.size = kDefaultTaskListFetchSize;
    
    __weak typeof(self) weakSelf = self;
    [processServices requestProcessInstanceListWithFilter:self.currentFilter
                                      withCompletionBlock:^(NSArray *processInstanceList, NSError *error, ASDKModelPaging *paging) {
                                          __strong typeof(self) strongSelf = weakSelf;
                                          
                                          if (AFAListContentTypeProcessInstances == strongSelf.listContentType) {
                                              completionBlock(processInstanceList, error, paging);
                                          }
    }];
}

- (void)fetchListForSearchTerm:(NSString *)searchTerm
           withCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    // Pass the existing defined filter
    self.currentFilter.text = searchTerm;
    self.currentFilter.page = 0;
    self.currentFilter.appDefinitionID = self.currentApp.modelID;
    
    [self fetchContentListWithCompletionBlock:completionBlock];
}

- (void)fetchNextPageForCurrentListWithCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    self.currentFilter.page += 1;
    [self fetchContentListWithCompletionBlock:completionBlock];
}

- (NSArray *)objectListForListContentType:(AFAListContentType)contentType {
    if (AFAListContentTypeTasks == self.listContentType) {
        return self.taskListArr;
    } else {
        return self.processListArr;
    }
}

- (void)updateCurrentObjectListWithObjectList:(NSArray *)objectList
                           forListContentType:(AFAListContentType)contentType
                                       paging:(ASDKModelPaging *)paging {
    if (paging.start) {
        NSArray *existingEntriesArr = (AFAListContentTypeTasks == self.listContentType) ? self.taskListArr : self.processListArr;
        NSSet *existingEntriesSet = [[NSSet alloc] initWithArray:existingEntriesArr];
        NSSet *serverEntriesSet = [[NSSet alloc] initWithArray:objectList];
        
        // Make sure that the incoming data is not a subset of the existing collection
        if (![serverEntriesSet isSubsetOfSet:existingEntriesSet]) {
            NSMutableArray *serverEntriesArr = [NSMutableArray arrayWithArray:objectList];
            [serverEntriesArr removeObjectsInArray:existingEntriesArr];
            
            // If so, add it to the already existing content and return the updated collection
            NSMutableArray *additionedEntries = [NSMutableArray arrayWithArray:existingEntriesArr];
            [additionedEntries addObjectsFromArray:serverEntriesArr];
            
            objectList = additionedEntries;
        }
    }
    
    if (AFAListContentTypeTasks == self.listContentType) {
        self.taskListArr = objectList;
    } else {
        self.processListArr = objectList;
    }
}


#pragma mark -
#pragma mark AFAFilterViewController Delegate

- (void)filterModelsDidLoadWithDefaultFilter:(AFAGenericFilterModel *)filterModel
                                  filterType:(AFAFilterType)filterType{
    // If no filter information is found don't continue with further requests
    if (!filterModel) {
        self.noRecordsLabel.hidden = NO;
        self.listTableView.hidden = YES;
        self.refreshView.hidden = NO;
        self.controllerState = AFAListControllerStateIdle;
        
        [self showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
    } else {
        if ((AFAFilterTypeTask == filterType &&
            AFAListContentTypeTasks == self.listContentType) ||
            (AFAFilterTypeProcessInstance == filterType &&
             AFAListContentTypeProcessInstances == self.listContentType)) {
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
#pragma mark AFAAddTaskViewController Delegate

- (void)didCreateTask:(ASDKModelTask *)task {
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
    
    [self.advancedFilterContainerView layoutIfNeeded];
    
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

- (void)animateUnderlineContentSectionForType:(AFAListContentType)contentType {
    // The order of enabling, disabling the constraints matter so we are obliged
    // to write the longer version for these checks
    switch (contentType) {
        case AFAListContentTypeTasks: {
            self.underlineTaskListButtonConstraint.priority = UILayoutPriorityDefaultHigh;
        }
            break;
            
        case AFAListContentTypeProcessInstances: {
            self.underlineTaskListButtonConstraint.priority = UILayoutPriorityFittingSizeLevel;
        }
            break;
            
        default:
            break;
    }
    
    self.processListButton.tintColor = (AFAListContentTypeProcessInstances == contentType) ? [UIColor enabledControlColor] : [UIColor disabledControlColor];
    self.taskListButton.tintColor = (AFAListContentTypeTasks == contentType) ? [UIColor enabledControlColor] : [UIColor disabledControlColor];
    
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
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    if (AFAListContentTypeTasks == self.listContentType) {
        return self.taskListArr.count;
    } else {
        return self.processListArr.count;
    }
}

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
    if (self.preloadCellIdx &&
        self.preloadCellIdx == indexPath.row &&
        self.currentFilter.page < self.totalTaskPages) {
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
    return [UIView new];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFATaskListStyleCell *listCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskListStyle];
    // Set up the cell with task details or process isntance details
    if (AFAListContentTypeTasks == self.listContentType) {
        [listCell setupWithTask:self.taskListArr[indexPath.row]];
    } else {
        [listCell setupWithProcessInstance:self.processListArr[indexPath.row]];
    }
    listCell.applicationThemeColor = self.navigationBarThemeColor;
    
    return listCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (AFAListContentTypeTasks == self.listContentType) {
        [self performSegueWithIdentifier:kSegueIDTaskDetails
                                  sender:[tableView cellForRowAtIndexPath:indexPath]];
    } else {
        [self performSegueWithIdentifier:kSegueIDProcessInstanceDetails
                                  sender:[tableView cellForRowAtIndexPath:indexPath]];
    }
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
                                         strongSelf.listTableView.hidden = [strongSelf objectListForListContentType:strongSelf.listContentType].count ? NO : YES;
                                     }
                                     strongSelf.loadingActivityView.hidden = (AFAListControllerStateRefreshInProgress == controllerState) ? NO : YES;
                                     strongSelf.loadingActivityView.animating = (AFAListControllerStateRefreshInProgress == controllerState) ? YES : NO;
                                 });
                             }];
}

@end
