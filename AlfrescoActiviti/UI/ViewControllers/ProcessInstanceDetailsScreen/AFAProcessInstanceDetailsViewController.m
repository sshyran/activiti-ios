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

#import "AFAProcessInstanceDetailsViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"

// Categories
#import "NSDate+AFAStringTransformation.h"
#import "UIViewController+AFAAlertAddition.h"

// Models
#import "AFATableControllerProcessInstanceDetailsModel.h"
#import "AFATableControllerProcessInstanceTasksModel.h"
#import "AFAGenericFilterModel.h"
#import "AFATableControllerProcessInstanceContentModel.h"
#import "AFATableControllerCommentModel.h"

// Managers
#import "AFATableController.h"
#import "AFAProcessServices.h"
#import "AFAServiceRepository.h"
#import "AFAQueryServices.h"
@import ActivitiSDK;

// Cell factories
#import "AFATableControllerProcessInstanceDetailsCellFactory.h"
#import "AFATableControllerProcessInstanceTasksCellFactory.h"
#import "AFATableControllerContentCellFactory.h"
#import "AFATableControllerCommentCellFactory.h"

// Segues
#import "AFAPushFadeSegueUnwind.h"

// Controllers
#import "AFATaskDetailsViewController.h"
#import "AFAContentPickerViewController.h"
#import "AFAAddCommentsViewController.h"

// Views
#import "AFAActivityView.h"
#import "AFANoContentView.h"

typedef NS_ENUM(NSInteger, AFAProcessInstanceDetailsSectionType) {
    AFAProcessInstanceDetailsSectionTypeDetails,
    AFAProcessInstanceDetailsSectionTypeTaskStatus,
    AFAProcessInstanceDetailsSectionTypeContent,
    AFAProcessInstanceDetailsSectionTypeComments,
    AFAProcessInstanceDetailsSectionTypeEnumCount
};

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
@property (strong, nonatomic) NSMutableDictionary                           *sectionContentDict;
@property (assign, nonatomic) NSInteger                                     currentSelectedSection;
@property (strong, nonatomic) AFATableController                            *tableController;
@property (strong, nonatomic) NSMutableDictionary                           *cellFactoryDict;

// KVO
@property (strong, nonatomic) ASDKKVOManager                                 *kvoManager;

@end

@implementation AFAProcessInstanceDetailsViewController


#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateIdle;
        
        self.sectionContentDict = [NSMutableDictionary dictionary];
        self.cellFactoryDict = [NSMutableDictionary dictionary];
        
        // Set up state bindings
        [self handleBindingsForTaskListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set up table controller and cells factories
    self.tableController = [AFATableController new];
    [self setUpCellFactories];
    
    // Set the default cell factory to task details
    self.tableController.cellFactory = [self dequeueCellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
    
    // Bind table view's delegates to table controller
    self.processTableView.dataSource = self.tableController;
    self.processTableView.delegate = self.tableController;
    
    // Set up the details table view to adjust it's size automatically
    self.processTableView.estimatedRowHeight = 55.0f;
    self.processTableView.rowHeight = UITableViewAutomaticDimension;
    
    // Update UI for current localization
    [self setupLocalization];
    
    // Set up section buttons
    self.processInstanceDetailsButton.tag = AFAProcessInstanceDetailsSectionTypeDetails;
    self.processInstanceActiveTasksButton.tag = AFAProcessInstanceDetailsSectionTypeTaskStatus;
    self.processInstanceContentButton.tag = AFAProcessInstanceDetailsSectionTypeContent;
    self.processInstanceCommentsButton.tag = AFAProcessInstanceDetailsSectionTypeComments;
    self.processInstanceDetailsButton.tintColor = self.navigationBarThemeColor;
    
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([kSegueIDProcessInstanceTaskDetails isEqualToString:segue.identifier]) {
        AFATaskDetailsViewController *taskDetailsController = (AFATaskDetailsViewController *)segue.destinationViewController;
        taskDetailsController.navigationBarThemeColor = self.navigationBarThemeColor;
        taskDetailsController.taskID = [(ASDKModelTask *)sender instanceID];
        taskDetailsController.unwindActionType = AFATaskDetailsUnwindActionTypeProcessInstanceDetails;
    } else if ([kSegueIDContentPickerComponentEmbedding isEqualToString:segue.identifier]) {
        self.contentPickerViewController = (AFAContentPickerViewController *)segue.destinationViewController;
    } else if ([kSegueIDProcessInstanceDetailsAddComments isEqualToString:segue.identifier]) {
        AFAAddCommentsViewController *addComentsController = (AFAAddCommentsViewController *)segue.destinationViewController;
        addComentsController.processInstanceID = self.processInstanceID;
    }
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDProcessInstanceDetailsUnwind isEqualToString:identifier] ||
        [kSegueIDProcessInstanceStartFormUnwind isEqualToString:identifier] ||
        [kSegueIDTaskDetailsViewProcessUnwind isEqualToString:identifier]) {
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

- (IBAction)unwindFromTaskDetailsController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindAddProcessInstanceCommentsController:(UIStoryboardSegue *)segue {
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
        currentSectionButton.tintColor = self.navigationBarThemeColor;
        
        [self refreshContentForCurrentSection];
        [self.processTableView reloadData];
    }
}

- (void)refreshContentForCurrentSection {
    self.tableController.model = [self reusableTableControllerModelForSectionType:self.currentSelectedSection];
    self.tableController.cellFactory = [self dequeueCellFactoryForSectionType:self.currentSelectedSection];
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
    
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices requestProcessInstanceDetailsForID:self.processInstanceID
                                        completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            if (!error) {
                                                AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [AFATableControllerProcessInstanceDetailsModel new];
                                                processInstanceDetailsModel.currentProcessInstance = processInstance;
                                                strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeDetails)] = processInstanceDetailsModel;
                                                
                                                // Update the table controller model and change the cell factory
                                                strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeDetails)];
                                                strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
                                                
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
    
    AFAQueryServices *queryServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeQueryServices];
    
    dispatch_group_t activeAndCompletedTasksGroup = dispatch_group_create();
    
    AFAGenericFilterModel *activeTasksFilter = [AFAGenericFilterModel new];
    activeTasksFilter.processInstanceID = self.processInstanceID;
    
    AFATableControllerProcessInstanceTasksModel *processInstanceTasksModel = [AFATableControllerProcessInstanceTasksModel new];
    
    __block BOOL hadEncounteredAnError = NO;
    __weak typeof(self) weakSelf = self;
    dispatch_group_enter(activeAndCompletedTasksGroup);
    [queryServices requestTaskListWithFilter:activeTasksFilter
                             completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 hadEncounteredAnError = error ? YES : NO;
                                 if (!hadEncounteredAnError) {
                                     processInstanceTasksModel.activeTasks = taskList;
                                 } else {
                                     [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                 }
                                 
                                 dispatch_group_leave(activeAndCompletedTasksGroup);
                             }];
    
    AFAGenericFilterModel *completedTasksFilter = [AFAGenericFilterModel new];
    completedTasksFilter.processInstanceID = self.processInstanceID;
    completedTasksFilter.state = AFAGenericFilterStateTypeCompleted;
    
    dispatch_group_enter(activeAndCompletedTasksGroup);
    [queryServices requestTaskListWithFilter:completedTasksFilter
                             completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 hadEncounteredAnError = error ? YES : NO;
                                 if (!hadEncounteredAnError) {
                                     processInstanceTasksModel.completedTasks = taskList;
                                 } else {
                                     [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                 }
                                 
                                 dispatch_group_leave(activeAndCompletedTasksGroup);
                             }];
    
    dispatch_group_notify(activeAndCompletedTasksGroup, dispatch_get_main_queue(),^{
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!hadEncounteredAnError) {
            strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeTaskStatus)] = processInstanceTasksModel;
            
            // Update the table controller model and change the cell factory
            strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeTaskStatus)];
            strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
            
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
        
        strongSelf.noContentView.hidden = [strongSelf.tableController.model hasTaskListAvailable];
        strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"tasks-large-icon"];
        strongSelf.noContentView.descriptionLabel.text = NSLocalizedString(kLocalizationProcessInstanceDetailsScreenNoTasksAvailableText, @"No tasks available text");
    });
}

- (void)refreshProcessInstanceContent {
    if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices requestProcessInstanceContentForProcessInstanceID:self.processInstanceID
                                                       completionBlock:^(NSArray *contentList, NSError *error) {
           __strong typeof(self) strongSelf = weakSelf;
           
           if (!error) {
               AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [AFATableControllerProcessInstanceContentModel new];
               processInstanceContentModel.attachedContentArr = contentList;
               strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeContent)] = processInstanceContentModel;
               
               if (AFAProcessInstanceDetailsSectionTypeContent == strongSelf.currentSelectedSection) {
                   strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeContent)];
                   
                   // Change the cell factory
                   strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
                   strongSelf.tableController.isEditable = NO;
               }
               
               // Because we're displaying a loading cell we need to refresh
               // the table view even when there are no collection changes
               // to remove the loading cell
               [strongSelf.processTableView reloadData];
               
               // Display the no content view if appropiate
               strongSelf.noContentView.hidden = !contentList.count ? NO : YES;
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
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices
     requestProcessInstanceCommentsForID:self.processInstanceID
     withCompletionBlock:^(NSArray *commentList, NSError *error, ASDKModelPaging *paging) {
         __strong typeof(self) strongSelf = weakSelf;
         
         if (!error) {
             // Extract the updated result
             AFATableControllerCommentModel *processInstanceCommentModel = [AFATableControllerCommentModel new];
             
             NSSortDescriptor *newestCommentsSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(creationDate))
                                                                                            ascending:NO];
             processInstanceCommentModel.commentListArr = [commentList sortedArrayUsingDescriptors:@[newestCommentsSortDescriptor]];
             processInstanceCommentModel.paging = paging;
             
             strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeComments)] = processInstanceCommentModel;
             
             if (AFAProcessInstanceDetailsSectionTypeComments == strongSelf.currentSelectedSection) {
                 strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeComments)];
                 
                 // Change the cell factory
                 strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeComments];
             }
             
             // Because we're displaying a loading cell we need to refresh
             // the table view even when there are no collection changes
             // to remove the loading cell
             [strongSelf.processTableView reloadData];
             
             AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [self reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
             BOOL isTaskCompleted = processInstanceDetailsModel.currentProcessInstance.endDate ? YES : NO;
             
             // Display the no content view if appropiate
             strongSelf.noContentView.hidden = !commentList.count ? NO : YES;
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

    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    __weak typeof(self) weakSelf = self;
    [processServices requestDeleteProcessInstanceWithID:self.processInstanceID
                                        completionBlock:^(BOOL isProcessInstanceDeleted, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            if (!error) {
                                                [strongSelf onBack:nil];
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
            
        default: {
            return nil;
        }
            break;
    }
}

- (id)reusableTableControllerModelForSectionType:(AFAProcessInstanceDetailsSectionType)sectionType {
    id reusableObject = nil;
    
    reusableObject = self.sectionContentDict[@(sectionType)];
    if (!reusableObject) {
        switch (sectionType) {
            case AFAProcessInstanceDetailsSectionTypeDetails: {
                reusableObject = [AFATableControllerProcessInstanceDetailsModel new];
            }
                break;
            case AFAProcessInstanceDetailsSectionTypeTaskStatus: {
                reusableObject = [AFATableControllerProcessInstanceTasksModel new];
            }
                break;
                
            case AFAProcessInstanceDetailsSectionTypeContent: {
                reusableObject = [AFATableControllerProcessInstanceContentModel new];
            }
                break;
                
            case AFAProcessInstanceDetailsSectionTypeComments: {
                reusableObject = [AFATableControllerCommentModel new];
            }
                
            default:
                break;
        }
    }
    
    return reusableObject;
}


#pragma mark -
#pragma mark Cell factories and cell actions

- (void)setUpCellFactories {
    // Register process instance details cell factory
    AFATableControllerProcessInstanceDetailsCellFactory *processInstanceDetailsCellFactory = [AFATableControllerProcessInstanceDetailsCellFactory new];
    processInstanceDetailsCellFactory.appThemeColor = self.navigationBarThemeColor;

    __weak typeof(self) weakSelf = self;
    [processInstanceDetailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [strongSelf reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
        BOOL isCompletedProcessInstance = processInstanceDetailsModel.currentProcessInstance.endDate ? YES : NO;
        
        NSString *alertMessage = [NSString stringWithFormat:isCompletedProcessInstance ? NSLocalizedString(kLocalizationProcessInstanceDetailsScreenDeleteProcessConfirmationFormat, @"Delete process instance text") : NSLocalizedString(kLocalizationProcessInstanceDetailsScreenCancelProcessConfirmationFormat, @"Cancel process instance text"), processInstanceDetailsModel.currentProcessInstance.name];
        
        [strongSelf showConfirmationAlertControllerWithMessage:alertMessage
                                 confirmationBlockAction:^{
                                     [weakSelf deleteCurrentProcessInstance];
                                 }];
    } forCellType:[processInstanceDetailsCellFactory cellTypeForProcessControlCell]];
    
    // Register process instance task status cell factory
    AFATableControllerProcessInstanceTasksCellFactory *processInstanceTasksCellFactory = [AFATableControllerProcessInstanceTasksCellFactory new];
    processInstanceTasksCellFactory.appThemeColor = self.navigationBarThemeColor;
    
    [processInstanceTasksCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        NSIndexPath *taskIndexpath = changeParameters[kCellFactoryCellParameterCellIndexpath];
        AFATableControllerProcessInstanceTasksModel *processInstanceTasks = [strongSelf reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
        ASDKModelTask *currentTask = [processInstanceTasks itemAtIndexPath:taskIndexpath];
        
        [strongSelf performSegueWithIdentifier:kSegueIDProcessInstanceTaskDetails
                                        sender:currentTask];
        
    } forCellType:[processInstanceTasksCellFactory cellTypeForTaskDetails]];
    
    // Register process instance content cell factory
    AFATableControllerContentCellFactory *processInstanceContentCellFactory = [AFATableControllerContentCellFactory new];
    [processInstanceContentCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        // It is possible that at the time of the download request the content's availability status
        // is changed. We perform an additional refresh once content is requested to be downloaded
        // so it's status has the latest value
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!(AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress & strongSelf.controllerState)) {
            strongSelf.controllerState |= AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
        }
        
        AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
        [processServices requestProcessInstanceContentForProcessInstanceID:strongSelf.processInstanceID
                                                           completionBlock:^(NSArray *contentList, NSError *error) {
                                                               // Mark that the refresh operation has ended
                                                               weakSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStateGeneralRefreshInProgress;
                                                               weakSelf.controllerState &= ~AFAProcessInstanceDetailsLoadingStatePullToRefreshInProgress;
                                                               
                                                               if (!error) {
                                                                   AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [AFATableControllerProcessInstanceContentModel new];
                                                                   processInstanceContentModel.attachedContentArr = contentList;
                                                                   weakSelf.sectionContentDict[@(AFAProcessInstanceDetailsSectionTypeContent)] = processInstanceContentModel;
                                                               }
                                                               
                                                               NSIndexPath *contentToDownloadIndexPath = changeParameters[kCellFactoryCellParameterCellIndexpath];
                                                               AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [weakSelf reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
                                                               ASDKModelContent *contentToDownload = ((ASDKModelProcessInstanceContent *)processInstanceContentModel.attachedContentArr[contentToDownloadIndexPath.section]).contentList[contentToDownloadIndexPath.row];
                                                               
                                                               [strongSelf.contentPickerViewController dowloadContent:contentToDownload
                                                                                                   allowCachedContent:YES];
                                                           }];
    } forCellType:[processInstanceContentCellFactory cellTypeForDownloadContent]];
    
    processInstanceContentCellFactory.appThemeColor = self.navigationBarThemeColor;
    
    // Register process instance comments cell factory
    AFATableControllerCommentCellFactory *processInstanceDetailsCommentCellFactory = [AFATableControllerCommentCellFactory new];
    
    self.cellFactoryDict[@(AFAProcessInstanceDetailsSectionTypeDetails)] = processInstanceDetailsCellFactory;
    self.cellFactoryDict[@(AFAProcessInstanceDetailsSectionTypeTaskStatus)] = processInstanceTasksCellFactory;
    self.cellFactoryDict[@(AFAProcessInstanceDetailsSectionTypeContent)] = processInstanceContentCellFactory;
    self.cellFactoryDict[@(AFAProcessInstanceDetailsSectionTypeComments)] = processInstanceDetailsCommentCellFactory;
}

- (id)dequeueCellFactoryForSectionType:(AFAProcessInstanceDetailsSectionType)sectionType {
    return self.cellFactoryDict[@(sectionType)];
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
