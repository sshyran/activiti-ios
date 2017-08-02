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

#import "AFAProcessInstanceDetailsViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"

// Categories
#import "NSDate+AFAStringTransformation.h"
#import "UIViewController+AFAAlertAddition.h"

// Data source
#import "AFAProcessInstanceDetailsDataSource.h"
#import "AFATaskDetailsDataSource.h"

// Models
#import "AFATableControllerProcessInstanceDetailsModel.h"
#import "AFATableControllerProcessInstanceTasksModel.h"
#import "AFAGenericFilterModel.h"
#import "AFATableControllerProcessInstanceContentModel.h"
#import "AFATableControllerCommentModel.h"

// Managers
#import "AFATableController.h"
@import ActivitiSDK;

// Cell factories
#import "AFATableControllerProcessInstanceDetailsCellFactory.h"
#import "AFATableControllerProcessInstanceTasksCellFactory.h"
#import "AFATableControllerContentCellFactory.h"
#import "AFATableControllerCommentCellFactory.h"

// Controllers
#import "AFATaskDetailsViewController.h"
#import "AFAContentPickerViewController.h"
#import "AFAAddCommentsViewController.h"
#import "AFAProcessStartFormViewController.h"
#import "AFAListViewController.h"

// Views
#import "AFAActivityView.h"
#import "AFANoContentView.h"

typedef NS_OPTIONS(NSUInteger, AFAProcessInstanceDetailsLoadingState) {
    AFAProcessInstanceDetailsLoadingStateIdle                          = 1<<0,
    AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress       = 1<<1,
    AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress      = 1<<2
};


@interface AFAProcessInstanceDetailsViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem                        *backBarButtonItem;
@property (weak, nonatomic) IBOutlet UITableView                            *processTableView;
@property (weak, nonatomic) IBOutlet AFAActivityView                        *loadingActivityView;
@property (strong, nonatomic) UIRefreshControl                              *refreshControl;
@property (weak, nonatomic) IBOutlet UIButton                               *processInstanceDetailsButton;
@property (weak, nonatomic) IBOutlet UIButton                               *processInstanceActiveTasksButton;
@property (weak, nonatomic) IBOutlet UIButton                               *processInstanceContentButton;
@property (weak, nonatomic) IBOutlet UIButton                               *processInstanceCommentsButton;
@property (weak, nonatomic) IBOutlet AFANoContentView                       *noContentView;
@property (strong, nonatomic) AFAContentPickerViewController                *contentPickerViewController;
@property (strong, nonatomic) IBOutlet UIBarButtonItem                      *addBarButtonItem;

// Internal state properties
@property (assign, nonatomic) AFAProcessInstanceDetailsLoadingState         controllerState;
@property (assign, nonatomic) NSInteger                                     currentSelectedSection;

// KVO
@property (strong, nonatomic) ASDKKVOManager                                 *kvoManager;

@end

@implementation AFAProcessInstanceDetailsViewController


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateIdle;
        [self handleBindingsForTaskListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Bind table view's delegates to table controller
    self.processTableView.dataSource = self.dataSource.tableController;
    self.processTableView.delegate = self.dataSource.tableController;
    self.navigationBarThemeColor = self.dataSource.themeColor;
    
    // Set up the details table view to adjust it's size automatically
    self.processTableView.estimatedRowHeight = 60.0f;
    self.processTableView.rowHeight = UITableViewAutomaticDimension;
    
    // Update UI for current localization
    [self setupLocalization];
    
    // Set up section buttons
    self.processInstanceDetailsButton.tag = AFAProcessInstanceDetailsSectionTypeDetails;
    self.processInstanceActiveTasksButton.tag = AFAProcessInstanceDetailsSectionTypeTaskStatus;
    self.processInstanceContentButton.tag = AFAProcessInstanceDetailsSectionTypeContent;
    self.processInstanceCommentsButton.tag = AFAProcessInstanceDetailsSectionTypeComments;
    self.processInstanceDetailsButton.tintColor = [self.navigationBarThemeColor colorWithAlphaComponent:.7f];
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.processTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(onPullToRefresh)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshContentForCurrentSection];
}


#pragma mark -
#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([kSegueIDProcessInstanceTaskDetails isEqualToString:segue.identifier]) {
        AFATaskDetailsViewController *taskDetailsController = (AFATaskDetailsViewController *)segue.destinationViewController;
        AFATaskDetailsDataSource *taskDetailsDataSource = [[AFATaskDetailsDataSource alloc] initWithTaskID:[(ASDKModelTask *)sender modelID]
                                                                                                themeColor:self.navigationBarThemeColor];
        taskDetailsController.dataSource = taskDetailsDataSource;
        taskDetailsController.unwindActionType = AFATaskDetailsUnwindActionTypeProcessInstanceDetails;
    } else if ([kSegueIDContentPickerComponentEmbedding isEqualToString:segue.identifier]) {
        self.contentPickerViewController = (AFAContentPickerViewController *)segue.destinationViewController;
    } else if ([kSegueIDProcessInstanceDetailsAddComments isEqualToString:segue.identifier]) {
        AFAAddCommentsViewController *addComentsController = (AFAAddCommentsViewController *)segue.destinationViewController;
        addComentsController.processInstanceID = self.dataSource.processInstanceID;
    } else if ([kSegueIDProcessInstanceViewCompletedStartForm isEqualToString:segue.identifier]) {
        AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [self.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
        AFAProcessStartFormViewController *startFormViewController = (AFAProcessStartFormViewController *)segue.destinationViewController;
        [startFormViewController setupStartFormForProcessInstanceObject:processInstanceDetailsModel.currentProcessInstance];
    }
}

- (IBAction)unwindFromTaskDetailsController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindAddProcessInstanceCommentsController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindProcessInstanceViewStartForm:(UIStoryboardSegue *)segue {
}


#pragma mark -
#pragma mark Actions

- (IBAction)onBack:(id)sender {
    switch (self.unwindActionType) {
        case AFAProcessInstanceDetailsUnwindActionTypeProcessList: {
            [self performSegueWithIdentifier:kSegueIDProcessInstanceDetailsUnwind
                                      sender:sender];
        }
            break;
            
        case AFAProcessInstanceDetailsUnwindActionTypeStartForm: {
            [self performSegueWithIdentifier:kSegueIDProcessInstanceStartFormUnwind
                                      sender:sender];
        }
            break;
            
        case AFAProcessInstanceDetailsUnwindActionTypeTaskDetails: {
            [self performSegueWithIdentifier:kSegueIDTaskDetailsViewProcessUnwind
                                      sender:sender];
        }
            break;
            
        default:
            break;
    }
}

- (void)onPullToRefresh {
    self.controllerState |= AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
    [self refreshContentForCurrentSection];
}

- (IBAction)onSectionSwitch:(UIButton *)sender {
    UIButton *sectionButton = (UIButton *)sender;
    
    // Check whether the user is tapping the same section
    if (self.currentSelectedSection != sectionButton.tag) {
        // Un-select the former selected button
        UIButton *lastSelectedSectionButton = [self buttonForSection:self.currentSelectedSection];
        lastSelectedSectionButton.tintColor = [UIColor blackColor];
        
        // Highlight the current selection
        self.currentSelectedSection = sectionButton.tag;
        UIButton *currentSectionButton = [self buttonForSection:self.currentSelectedSection];
        currentSectionButton.tintColor = [self.navigationBarThemeColor colorWithAlphaComponent:.7f];
        
        [self refreshContentForCurrentSection];
        [self.processTableView reloadData];
    }
}

- (void)refreshContentForCurrentSection {
    [self.dataSource updateTableControllerForSectionType:self.currentSelectedSection];
    self.noContentView.hidden = YES;
    self.navigationItem.rightBarButtonItem = nil;
    switch (self.currentSelectedSection) {
        case AFAProcessInstanceDetailsSectionTypeDetails: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationProcessInstanceDetailsScreenTitleText, @"Process instance details screen title");
            [self refreshProcessInstanceDetails];
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeTaskStatus: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationProcessInstanceDetailsScreenActiveAndCompletedText, @"Active and completed tasks screen title");
            [self refreshProcessInstanceActiveAndCompletedTasks];
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeContent: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenContentTitleText, @"Attached content screen title");
            [self refreshProcessInstanceContent];
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeComments: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenCommentsTitleText, @"Comments screen title");
            [self refreshProcessInstanceComments];
            
            self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
        }
            break;
            
        default:
            break;
    }
    
}

- (void)refreshProcessInstanceDetails {
    if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.dataSource processInstanceDetailsWithCompletionBlock:^(NSError *error, BOOL registerCellActions) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!error) {
            if (registerCellActions) {
                [strongSelf registerCellActions];
            }
            [strongSelf.processTableView reloadData];
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        // Mark that the refresh operation has ended
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
    }];
}

- (void)refreshProcessInstanceActiveAndCompletedTasks {
    if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.dataSource processInstanceActiveAndCompletedTasksWithCompletionBlock:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (error) {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
        } else {
            [strongSelf.processTableView reloadData];
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        // Mark that the refresh operation has ended
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
        
        AFATableControllerProcessInstanceTasksModel *processInstanceTaskModel = [self.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
        strongSelf.noContentView.hidden = ([processInstanceTaskModel hasTaskListAvailable] || processInstanceTaskModel.isStartFormDefined);
        strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"tasks-large-icon"];
        strongSelf.noContentView.descriptionLabel.text = NSLocalizedString(kLocalizationProcessInstanceDetailsScreenNoTasksAvailableText, @"No tasks available text");
    }];
}

- (void)refreshProcessInstanceContent {
    if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.dataSource processInstanceContentWithCompletionBlock:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            [strongSelf.processTableView reloadData];
            
            // Display the no content view if appropiate
            AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [self.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
            
            strongSelf.noContentView.hidden = !processInstanceContentModel.attachedContentArr.count ? NO : YES;
            strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"documents-large-icon"];
            strongSelf.noContentView.descriptionLabel.text = NSLocalizedString(kLocalizationNoContentScreenFilesNotEditableText, @"No files available not editable");
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentFetchErrorText, @"Content fetching error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        // Mark that the refresh operation has ended
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
    }];
}

- (void)refreshProcessInstanceComments {
    if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    __weak typeof(self) weakSelf = self;
    [self.dataSource processInstanceCommentsWithCompletionBlock:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            [strongSelf.processTableView reloadData];
            
            AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [self.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
            AFATableControllerCommentModel *processInstanceCommentModel = [self.dataSource reusableTableControllerModelForSectionType:
                                                                           AFAProcessInstanceDetailsSectionTypeComments];
            
            BOOL isTaskCompleted = processInstanceDetailsModel.currentProcessInstance.endDate ? YES : NO;
            
            // Display the no content view if appropiate
            strongSelf.noContentView.hidden = !processInstanceCommentModel.commentListArr.count ? NO : YES;
            strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"comments-large-icon"];
            strongSelf.noContentView.descriptionLabel.text = isTaskCompleted ? NSLocalizedString(kLocalizationNoContentScreenCommentsNotEditableText, @"No comments available not editable text") : NSLocalizedString(kLocalizationNoContentScreenCommentsText, @"No comments available text") ;
            
            // Display the last update date
            if (strongSelf.refreshControl) {
                strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
            }
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentFetchErrorText, @"Content fetching error")];
        }
        
        [[NSOperationQueue currentQueue] addOperationWithBlock:^{
            [weakSelf.refreshControl endRefreshing];
        }];
        
        // Mark that the refresh operation has ended
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
    }];
}

- (IBAction)onAdd:(UIBarButtonItem *)sender {
    if (AFAProcessInstanceDetailsSectionTypeComments == self.currentSelectedSection) {
        [self performSegueWithIdentifier:kSegueIDProcessInstanceDetailsAddComments
                                  sender:sender];
    }
}

- (void)deleteCurrentProcessInstance {
    self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    
    __weak typeof(self) weakSelf = self;
    [self.dataSource deleteCurrentProcessInstanceWithCompletionBlock:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            [self performSegueWithIdentifier:kSegueIDProcessInstanceDetailsUnwind
                                      sender:nil];
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentFetchErrorText, @"Content fetching error")];
        }
        // Mark that the delete operation has ended
        strongSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }];
}


#pragma mark -
#pragma mark Convenience methods

- (void)setupLocalization {
    self.navigationBarTitle = NSLocalizedString(kLocalizationProcessInstanceDetailsScreenTitleText, @"Process instance details title");
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
}


- (UIButton *)buttonForSection:(AFAProcessInstanceDetailsSectionType)sectionType {
    switch (sectionType) {
        case AFAProcessInstanceDetailsSectionTypeDetails: {
            return self.processInstanceDetailsButton;
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeTaskStatus: {
            return self.processInstanceActiveTasksButton;
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeContent: {
            return self.processInstanceContentButton;
        }
            break;
            
        case AFAProcessInstanceDetailsSectionTypeComments: {
            return self.processInstanceCommentsButton;
        }
            break;
            
        default: return nil;
            break;
    }
}


#pragma mark -
#pragma mark Cell actions

- (void)registerCellActions {
    AFATableControllerProcessInstanceDetailsCellFactory *processInstanceDetailsCellFactory = [self.dataSource cellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
    AFATableControllerProcessInstanceTasksCellFactory *processInstanceTasksCellFactory = [self.dataSource cellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
    AFATableControllerContentCellFactory *processInstanceContentCellFactory = [self.dataSource cellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
    
    __weak typeof(self) weakSelf = self;
    [processInstanceDetailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [strongSelf.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
        BOOL isCompletedProcessInstance = processInstanceDetailsModel.currentProcessInstance.endDate ? YES : NO;
        
        NSString *alertMessage = nil;
        NSString *processInstanceName = processInstanceDetailsModel.currentProcessInstance.name;
        if (isCompletedProcessInstance) {
            alertMessage = [NSString stringWithFormat:NSLocalizedString(kLocalizationProcessInstanceDetailsScreenDeleteProcessConfirmationFormat, @"Delete process instance text"), processInstanceName ? processInstanceName : @""];
        } else {
            alertMessage = [NSString stringWithFormat:NSLocalizedString(kLocalizationProcessInstanceDetailsScreenCancelProcessConfirmationFormat, @"Cancel process instance text"), processInstanceName ? processInstanceName : @""];
        }
        
        [strongSelf showConfirmationAlertControllerWithMessage:alertMessage
                                       confirmationBlockAction:^{
                                           [weakSelf deleteCurrentProcessInstance];
                                       }];
    } forCellType:[processInstanceDetailsCellFactory cellTypeForProcessControlCell]];
    
    [processInstanceTasksCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        NSIndexPath *taskIndexpath = changeParameters[kCellFactoryCellParameterCellIndexpath];
        AFATableControllerProcessInstanceTasksModel *processInstanceTasks = [strongSelf.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
        ASDKModelTask *currentTask = [processInstanceTasks itemAtIndexPath:taskIndexpath];
        
        if (currentTask) {
            [strongSelf performSegueWithIdentifier:kSegueIDProcessInstanceTaskDetails
                                            sender:currentTask];
        } else if (processInstanceTasks.isStartFormDefined) {
            [strongSelf performSegueWithIdentifier:kSegueIDProcessInstanceViewCompletedStartForm
                                            sender:nil];
        }
    } forCellType:[processInstanceTasksCellFactory cellTypeForTaskDetails]];
    
    [processInstanceContentCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        // It is possible that at the time of the download request the content's availability status
        // is changed. We perform an additional refresh once content is requested to be downloaded
        // so it's status has the latest value
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & strongSelf.controllerState)) {
            strongSelf.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        }
        
        [self.dataSource processInstanceContentWithCompletionBlock:^(NSError *error) {
            NSIndexPath *contentToDownloadIndexPath = changeParameters[kCellFactoryCellParameterCellIndexpath];
            AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [weakSelf.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
            ASDKModelContent *contentToDownload = ((ASDKModelProcessInstanceContent *)processInstanceContentModel.attachedContentArr[contentToDownloadIndexPath.section]).contentArr[contentToDownloadIndexPath.row];
            
            [weakSelf.contentPickerViewController dowloadContent:contentToDownload
                                              allowCachedContent:YES];
        }];
    } forCellType:[processInstanceContentCellFactory cellTypeForDownloadContent]];
    
    // Certain actions are performed for completed or ongoing process instances so there is
    // no reason to register all of them at all times
    AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [self.dataSource reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
    
    if ([processInstanceDetailsModel isCompletedProcessInstance]) {
        [processInstanceDetailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
            __strong typeof(self) strongSelf = weakSelf;
            
            [strongSelf.contentPickerViewController downloadAuditLogForProcessInstanceWithID:strongSelf.dataSource.processInstanceID
                                                                          allowCachedResults:YES];
        } forCellType:[processInstanceDetailsCellFactory cellTypeForAuditLogCell]];
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
                                 
                                 strongSelf.processTableView.hidden = (AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                                 strongSelf.loadingActivityView.hidden = (AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? NO : YES;
                                 strongSelf.loadingActivityView.animating = (AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                             }];
}


@end
