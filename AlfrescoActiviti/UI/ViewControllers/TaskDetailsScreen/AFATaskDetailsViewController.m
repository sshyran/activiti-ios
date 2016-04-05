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

#import "AFATaskDetailsViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"
#import "AFALocalizationConstants.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"
#import "NSDate+AFAStringTransformation.h"
#import "NSDate+AFADateAdditions.h"
#import "UIColor+AFATheme.h"

// Segues
#import "AFAPushFadeSegueUnwind.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAKVOManager.h"
#import "AFATableController.h"
#import "AFATableControllerTaskDetailsCellFactory.h"
#import "AFATableControllerTaskContributorsCellFactory.h"
#import "AFATableControllerContentCellFactory.h"
#import "AFATableControllerCommentCellFactory.h"
#import "AFATaskServices.h"
#import "AFAFormServices.h"
#import "AFAProfileServices.h"
@import ActivitiSDK;

// Models
#import "AFATableControllerTaskDetailsModel.h"
#import "AFATableControllerTaskContributorsModel.h"
#import "AFATableControllerContentModel.h"
#import "AFATableControllerCommentModel.h"
#import "AFATaskUpdateModel.h"

// Views
#import "AFAActivityView.h"
#import "AFANoContentView.h"

// Controllers
#import "AFAContentPickerViewController.h"
#import "AFATaskFormViewController.h"
#import "AFAPeoplePickerViewController.h"
#import "AFAProcessInstanceDetailsViewController.h"
#import "AFAAddCommentsViewController.h"

typedef NS_ENUM(NSInteger, AFATaskDetailsSectionType) {
    AFATaskDetailsSectionTypeTaskDetails = 0,
    AFATaskDetailsSectionTypeForm,
    AFATaskDetailsSectionTypeContributors,
    AFATaskDetailsSectionTypeFilesContent,
    AFATaskDetailsSectionTypeComments,
    AFATaskDetailsSectionTypeEnumCount
};

typedef NS_OPTIONS(NSUInteger, AFATaskDetailsLoadingState) {
    AFATaskDetailsLoadingStateIdle                          = 1<<0,
    AFATaskDetailsLoadingStatePullToRefreshInProgress       = 1<<1,
    AFATaskDetailsLoadingStateGeneralRefreshInProgress      = 1<<2
};

@interface AFATaskDetailsViewController () <AFAContentPickerViewControllerDelegate, AFATaskFormViewControllerDelegate>

@property (weak, nonatomic)   IBOutlet UIBarButtonItem                      *backBarButtonItem;
@property (weak, nonatomic)   IBOutlet UITableView                          *taskDetailsTableView;
@property (weak, nonatomic)   IBOutlet AFAActivityView                      *loadingActivityView;
@property (strong, nonatomic) UIRefreshControl                              *refreshControl;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskDetailsButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskFormButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskContentButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskContributorsButton;
@property (weak, nonatomic)   IBOutlet UIButton                             *taskCommentsButton;
@property (weak, nonatomic)   IBOutlet UIToolbar                            *datePickerToolbar;
@property (weak, nonatomic)   IBOutlet UIView                               *contentPickerContainer;
@property (weak, nonatomic)   IBOutlet UIView                               *fullScreenOverlayView;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *datePickerBottomConstraint;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *contentPickerContainerBottomConstraint;
@property (weak, nonatomic)   IBOutlet UIView                               *datePickerContainerView;
@property (strong, nonatomic) UIDatePicker                                  *datePicker;
@property (strong, nonatomic) AFAContentPickerViewController                *contentPickerViewController;
@property (strong, nonatomic) AFATaskFormViewController                     *taskFormViewController;
@property (weak, nonatomic)   IBOutlet UIView                               *formViewContainer;
@property (weak, nonatomic)   IBOutlet NSLayoutConstraint                   *taskDetailsTableViewTopConstraint;
@property (strong, nonatomic) IBOutlet UIBarButtonItem                      *addBarButtonItem;
@property (weak, nonatomic)   IBOutlet AFANoContentView                     *noContentView;

// Internal state properties
@property (assign, nonatomic) AFATaskDetailsLoadingState                    controllerState;
@property (strong, nonatomic) NSMutableDictionary                           *sectionContentDict;
@property (assign, nonatomic) NSInteger                                     currentSelectedSection;
@property (strong, nonatomic) AFATableController                            *tableController;
@property (strong, nonatomic) NSMutableDictionary                           *cellFactoryDict;
@property (strong, nonatomic) ASDKModelProfile                              *currentUserProfile;

// KVO
@property (strong, nonatomic) AFAKVOManager                                 *kvoManager;

@end

@implementation AFATaskDetailsViewController

#pragma mark -
#pragma mark Life cycle

-(instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.controllerState |= AFATaskDetailsLoadingStateIdle;
        
        self.sectionContentDict = [NSMutableDictionary dictionary];
        self.cellFactoryDict = [NSMutableDictionary dictionary];
        
        // Set up state bindings
        [self handleBindingsForTaskListViewController];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenTaskDetailsTitleText, @"Task details title");
    
    // Set up table controller and cells factories
    self.tableController = [AFATableController new];
    [self setUpCellFactories];
    
    // Set the default cell factory to task details
    self.tableController.cellFactory = [self dequeueCellFactoryForSectionType:AFATaskDetailsSectionTypeTaskDetails];
    
    // Bind table view's delegates to table controller
    self.taskDetailsTableView.dataSource = self.tableController;
    self.taskDetailsTableView.delegate = self.tableController;
    
    // Set up the details table view to adjust it's size automatically
    self.taskDetailsTableView.estimatedRowHeight = 55.0f;
    self.taskDetailsTableView.rowHeight = UITableViewAutomaticDimension;
    
    // Update UI for current localization
    [self setupLocalization];
    
    // Set up section buttons
    self.taskDetailsButton.tag = AFATaskDetailsSectionTypeTaskDetails;
    self.taskFormButton.tag = AFATaskDetailsSectionTypeForm;
    self.taskContentButton.tag = AFATaskDetailsSectionTypeFilesContent;
    self.taskContributorsButton.tag = AFATaskDetailsSectionTypeContributors;
    self.taskCommentsButton.tag = AFATaskDetailsSectionTypeComments;
    self.currentSelectedSection = AFATaskDetailsSectionTypeTaskDetails;
    self.taskDetailsButton.tintColor = self.navigationBarThemeColor;
    
    // Set up the refresh control
    UITableViewController *tableViewController = [[UITableViewController alloc] init];
    [self addChildViewController:tableViewController];
    tableViewController.tableView = self.taskDetailsTableView;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self
                            action:@selector(onPullToRefresh)
                  forControlEvents:UIControlEventValueChanged];
    tableViewController.refreshControl = self.refreshControl;
    
    // Add shaddow to date picker toolbar
    self.datePickerToolbar.layer.masksToBounds = NO;
    self.datePickerToolbar.layer.shadowOffset = CGSizeMake(0, -.5f);
    self.datePickerToolbar.layer.shadowRadius = 2.0f;
    self.datePickerToolbar.layer.shadowOpacity = 0.5;
    
    // Make sure the add button is not pressent on certain categories.
    // It will be enabled based on the current section selection
    self.navigationItem.rightBarButtonItem = nil;
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

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([kSegueIDContentPickerComponentEmbedding isEqualToString:segue.identifier]) {
        self.contentPickerViewController = (AFAContentPickerViewController *)segue.destinationViewController;
        self.contentPickerViewController.delegate = self;
        self.contentPickerViewController.taskID = self.taskID;
    } else if ([kSegueIDFormComponent isEqualToString:segue.identifier]) {
        self.taskFormViewController = (AFATaskFormViewController *)segue.destinationViewController;
        self.taskFormViewController.delegate = self;
    } else if ([kSegueIDTaskDetailsAddContributor isEqualToString:segue.identifier]) {
        AFAPeoplePickerViewController *peoplePickerViewController = (AFAPeoplePickerViewController *)segue.destinationViewController;
        peoplePickerViewController.taskID = self.taskID;
        
        // Based on the current section decide what kind of people picker controller type
        // is going to be configured
        if (AFATaskDetailsSectionTypeTaskDetails == self.currentSelectedSection) {
            peoplePickerViewController.peoplePickerType = AFAPeoplePickerControllerTypeReAssign;
        } else {
            peoplePickerViewController.peoplePickerType = AFAPeoplePickerControllerTypeInvolve;
        }
    } else if ([kSegueIDTaskDetailsViewProcess isEqualToString:segue.identifier]) {
        AFAProcessInstanceDetailsViewController *processInstanceDetailsController = (AFAProcessInstanceDetailsViewController *)segue.destinationViewController;
        AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
        processInstanceDetailsController.processInstanceID = taskDetailsModel.currentTask.processInstanceID;
        processInstanceDetailsController.unwindActionType = AFAProcessInstanceDetailsUnwindActionTypeTaskDetails;
        processInstanceDetailsController.navigationBarThemeColor = self.navigationBarThemeColor;
    } else if ([kSegueIDTaskDetailsAddComments isEqualToString:segue.identifier]) {
        AFAAddCommentsViewController *addCommentsViewController = (AFAAddCommentsViewController *)segue.destinationViewController;
        addCommentsViewController.taskID = self.taskID;
    }
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDTaskDetailsUnwind isEqualToString:identifier]) {
        // Clear the form engine once the screen is dismissed
        AFAFormServices *formServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFormServices];
        [formServices requestEngineCleanup];
        
        AFAPushFadeSegueUnwind *unwindSegue = [AFAPushFadeSegueUnwind segueWithIdentifier:identifier
                                                                                   source:fromViewController
                                                                              destination:toViewController
                                                                           performHandler:^{}];
        return unwindSegue;
    }
    
    if ([kSegueIDProcessInstanceTaskDetailsUnwind isEqualToString:identifier]) {
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

- (IBAction)unwindPeoplePickerController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindViewProcessInstanceDetailsController:(UIStoryboardSegue *)segue {
}

- (IBAction)unwindAddCommentsController:(UIStoryboardSegue *)segue {
}


#pragma mark -
#pragma mark Actions

- (IBAction)onBack:(id)sender {
    switch (self.unwindActionType) {
        case AFATaskDetailsUnwindActionTypeTaskList: {
            [self performSegueWithIdentifier:kSegueIDTaskDetailsUnwind
                                      sender:sender];
        }
            break;
            
        case AFATaskDetailsUnwindActionTypeProcessInstanceDetails: {
            [self performSegueWithIdentifier:kSegueIDProcessInstanceTaskDetailsUnwind
                                      sender:sender];
        }
            break;
            
        default:
            break;
    }
}

- (IBAction)onSectionSwitch:(id)sender {
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
        [self.taskDetailsTableView reloadData];
    }
}

- (IBAction)onDatePickerRemove:(id)sender {
    // Remove the due date from the current task details model
    AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
    taskDetailsModel.currentTask.dueDate = nil;
    
    // Trigger an update request
    [self updateTaskDetails];
    
    // Dismiss the date picker
    [self toggleDatePickerComponent];
    [self.taskDetailsTableView reloadData];
}

- (IBAction)onDatePickerDone:(id)sender {
    // Save the picked due date
    NSDate *pickedDueDate = self.datePicker.date;
    AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
    taskDetailsModel.currentTask.dueDate = pickedDueDate;
    
    // Trigger an update request
    [self updateTaskDetails];
    
    // Dismiss the date picker
    [self toggleDatePickerComponent];
    [self.taskDetailsTableView reloadData];
}

- (void)refreshContentForCurrentSection {
    self.tableController.model = [self reusableTableControllerModelForSectionType:self.currentSelectedSection];
    self.tableController.cellFactory = [self dequeueCellFactoryForSectionType:self.currentSelectedSection];
    
    BOOL displayTaskFormContainerView = NO;
    self.navigationItem.rightBarButtonItem = nil;
    self.noContentView.hidden = YES;
    
    AFATableControllerTaskDetailsModel *taskDetailsModel = self.sectionContentDict[@(AFATaskDetailsSectionTypeTaskDetails)];
    BOOL isTaskCompleted = (taskDetailsModel.currentTask.endDate && taskDetailsModel.currentTask.duration);
    
    switch (self.currentSelectedSection) {
        case AFATaskDetailsSectionTypeTaskDetails: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenTaskDetailsTitleText, @"Task details title");
            [self refreshTaskDetails];
        }
            break;
            
        case AFATaskDetailsSectionTypeForm: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenTaskFormTitleText, @"Task form title");
            displayTaskFormContainerView = YES;
            AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
            [self.taskFormViewController startTaskFormForTaskObject:taskDetailsModel.currentTask];
        }
            break;
            
        case AFATaskDetailsSectionTypeContributors: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenContributorsTitleText, @"Contributors title");
            
            AFATableControllerTaskDetailsModel *taskDetailsModel = self.sectionContentDict[@(AFATaskDetailsSectionTypeTaskDetails)];
            AFATableControllerTaskContributorsModel *taskContributorsModel = [AFATableControllerTaskContributorsModel new];
            taskContributorsModel.involvedPeople = taskDetailsModel.currentTask.involvedPeople;
            self.tableController.model = taskContributorsModel;
            [self refreshTaskDetails];
            
            if (!isTaskCompleted) {
                self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
            }
        }
            break;
            
        case AFATaskDetailsSectionTypeFilesContent: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenContentTitleText, @"Content title");
            [self refreshTaskContent];

            if (!isTaskCompleted) {
                self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
            }
        }
            break;
            
        case AFATaskDetailsSectionTypeComments: {
            self.navigationBarTitle = NSLocalizedString(kLocalizationTaskDetailsScreenCommentsTitleText, @"Comments title");
            [self refreshTaskComments];
            
            if (!isTaskCompleted) {
                self.navigationItem.rightBarButtonItem = self.addBarButtonItem;
            }
        }
            break;
            
        default:
            break;
    }
    
    self.formViewContainer.hidden = !displayTaskFormContainerView;
}

- (void)refreshTaskDetails {
    if (!(AFATaskDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    }
    
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskDetailsForID:self.taskID
                      withCompletionBlock:^(ASDKModelTask *task, NSError *error) {
          __strong typeof(self) strongSelf = weakSelf;
          
          if (!error) {
              AFATableControllerTaskDetailsModel *taskDetailsModel = [AFATableControllerTaskDetailsModel new];
              taskDetailsModel.currentTask = task;
              strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeTaskDetails)] = taskDetailsModel;
              
              // Enable the task form button if the task has a form key defined
              strongSelf.taskFormButton.enabled = taskDetailsModel.currentTask.formKey ? YES : NO;
              
              // If the current task is claimable and has an assignee then fetch the
              // current user profile to also check if the task is already claimed and
              // can be dequeued
              dispatch_group_t taskDetailsGroup = dispatch_group_create();
              
              if ((task.isMemberOfCandidateUsers || task.isMemberOfCandidateGroup) &&
                  task.assignee) {
                  // Fetch profile information
                  dispatch_group_enter(taskDetailsGroup);
                  AFAProfileServices *profileServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
                  [profileServices requestProfileWithCompletionBlock:^(ASDKModelProfile *profile, NSError *error) {
                      if (!error) {
                          weakSelf.currentUserProfile = profile;
                          dispatch_group_leave(taskDetailsGroup);
                      } else {
                          [weakSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                      }
                  }];
              }
              
              dispatch_group_notify(taskDetailsGroup, dispatch_get_main_queue(), ^{
                  if (AFATaskDetailsSectionTypeTaskDetails == strongSelf.currentSelectedSection) {
                      AFATableControllerTaskDetailsModel *taskDetailsModel = strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeTaskDetails)];
                      taskDetailsModel.userProfile = weakSelf.currentUserProfile;
                      strongSelf.tableController.model = taskDetailsModel;
                      
                      // Change the cell factory
                      strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFATaskDetailsSectionTypeTaskDetails];
                  } else if (AFATaskDetailsSectionTypeContributors == strongSelf.currentSelectedSection) {
                      // Extract the number of collaborators for the given task
                      AFATableControllerTaskContributorsModel *taskContributorsModel = [AFATableControllerTaskContributorsModel new];
                      AFATableControllerTaskDetailsModel *currentTaskModel = strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeTaskDetails)];
                      taskContributorsModel.involvedPeople = currentTaskModel.currentTask.involvedPeople;
                      strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeContributors)] = taskContributorsModel;
                      strongSelf.tableController.model = taskContributorsModel;
                      
                      // Change the cell factory
                      strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFATaskDetailsSectionTypeContributors];
                      
                      // Check if the task is already completed and in that case mark the table
                      // controller as not editable
                      strongSelf.tableController.isEditable = !(task.endDate && task.duration);
                  }
                  
                  // Because we're switching betweeen task details and contributors views
                  // we're reloading the table view even if there is esentially the same
                  // content
                  [strongSelf.taskDetailsTableView reloadData];
                  
                  // Display the no content view if appropiate
                  if (AFATaskDetailsSectionTypeContributors == strongSelf.currentSelectedSection) {
                      strongSelf.noContentView.hidden = !task.involvedPeople.count ? NO : YES;
                      strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"contributors-large-icon"];
                      
                      BOOL isTaskCompleted = (taskDetailsModel.currentTask.endDate && taskDetailsModel.currentTask.duration);
                      strongSelf.noContentView.descriptionLabel.text = isTaskCompleted ? NSLocalizedString(kLocalizationNoContentScreenContributorsNotEditableText, @"No contributors available not editable text") : NSLocalizedString(kLocalizationNoContentScreenContributorsText, @"No contributors available text");
                  }
                  
                  // Display the last update date
                  if (strongSelf.refreshControl) {
                      strongSelf.refreshControl.attributedTitle = [[NSDate date] lastUpdatedFormattedString];
                  }
              });
          } else {
              [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
          }
          
          [[NSOperationQueue currentQueue] addOperationWithBlock:^{
              [weakSelf.refreshControl endRefreshing];
          }];
                          
          // Mark that the refresh operation has ended
          strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
          strongSelf.controllerState &= ~AFATaskDetailsLoadingStatePullToRefreshInProgress;
      }];
}

- (void)refreshTaskContent {
    if (!(AFATaskDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    }
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskContentForID:self.taskID
                      withCompletionBlock:^(NSArray *contentList, NSError *error) {
          __strong typeof(self) strongSelf = weakSelf;
          
          if (!error) {
              AFATableControllerContentModel *taskContentModel = [AFATableControllerContentModel new];
              taskContentModel.attachedContentArr = contentList;
              strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeFilesContent)] = taskContentModel;
              
              AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
              
              if (AFATaskDetailsSectionTypeFilesContent == strongSelf.currentSelectedSection) {
                  strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeFilesContent)];
                  
                  // Change the cell factory
                  strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFATaskDetailsSectionTypeFilesContent];
                  strongSelf.tableController.isEditable = !(taskDetailsModel.currentTask.endDate && taskDetailsModel.currentTask.duration);
              }
              
              // Because we're displaying a loading cell we need to refresh
              // the table view even when there are no collection changes
              // to remove the loading cell
              [strongSelf.taskDetailsTableView reloadData];
              
              // Display the no content view if appropiate
              strongSelf.noContentView.hidden = !contentList.count ? NO : YES;
              strongSelf.noContentView.iconImageView.image = [UIImage imageNamed:@"documents-large-icon"];
              
              BOOL isTaskCompleted = (taskDetailsModel.currentTask.endDate && taskDetailsModel.currentTask.duration);
              
              strongSelf.noContentView.descriptionLabel.text = isTaskCompleted ? NSLocalizedString(kLocalizationNoContentScreenFilesNotEditableText, @"No files available not editable") :  NSLocalizedString(kLocalizationNoContentScreenFilesText, @"No files available text");
              
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
          strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
          strongSelf.controllerState &= ~AFATaskDetailsLoadingStatePullToRefreshInProgress;
      }];
}

- (void)refreshTaskComments {
    if (!(AFATaskDetailsLoadingStatePullToRefreshInProgress & self.controllerState)) {
        self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    }
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskCommentsForID:self.taskID
                       withCompletionBlock:^(NSArray *commentList, NSError *error, ASDKModelPaging *paging) {
           __strong typeof(self) strongSelf = weakSelf;
           
           if (!error) {
               // Extract the updated result
               AFATableControllerCommentModel *taskCommentModel = [AFATableControllerCommentModel new];
               
               NSSortDescriptor *newestCommentsSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                                              ascending:NO];
               taskCommentModel.commentListArr = [commentList sortedArrayUsingDescriptors:@[newestCommentsSortDescriptor]];
               taskCommentModel.paging = paging;
               
               strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeComments)] = taskCommentModel;
               
               if (AFATaskDetailsSectionTypeComments == strongSelf.currentSelectedSection) {
                   strongSelf.tableController.model = strongSelf.sectionContentDict[@(AFATaskDetailsSectionTypeComments)];
                   
                   // Change the cell factory
                   strongSelf.tableController.cellFactory = [strongSelf dequeueCellFactoryForSectionType:AFATaskDetailsSectionTypeComments];
               }
               
               // Because we're displaying a loading cell we need to refresh
               // the table view even when there are no collection changes
               // to remove the loading cell
               [strongSelf.taskDetailsTableView reloadData];
               
               AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
               BOOL isTaskCompleted = (taskDetailsModel.currentTask.endDate && taskDetailsModel.currentTask.duration);
               
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
           strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
           strongSelf.controllerState &= ~AFATaskDetailsLoadingStatePullToRefreshInProgress;
    }];
}

- (void)onPullToRefresh {
    self.controllerState |= AFATaskDetailsLoadingStatePullToRefreshInProgress;
    
    [self refreshContentForCurrentSection];
}

- (void)updateTaskDetails {
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    AFATaskUpdateModel *taskUpdate = [AFATaskUpdateModel new];
    AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
    taskUpdate.taskDueDate = taskDetailsModel.currentTask.dueDate;
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskUpdateWithRepresentation:taskUpdate
                                            forTaskID:self.taskID
                                  withCompletionBlock:^(BOOL isTaskUpdated, NSError *error) {
          __strong typeof(self) strongSelf = weakSelf;
          
          if (!isTaskUpdated) {
              // Rollback changes
              AFATableControllerTaskDetailsModel *taskDetailsModel = [strongSelf reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
              taskDetailsModel.currentTask.dueDate = nil;
              
              [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskUpdateErrorText, @"Task update error")];
              [strongSelf.taskDetailsTableView reloadData];
          }
    }];
}

- (void)completeTask {
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskCompletionForID:self.taskID
                         withCompletionBlock:^(BOOL isTaskCompleted, NSError *error) {
         __strong typeof(self) strongSelf = weakSelf;
         if (!isTaskCompleted) {
             [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskUpdateErrorText, @"Task update error")];
         } else {
             // Pop the controller and see the refreshed list
             [strongSelf onBack:nil];
         }
    }];
}

- (void)onContentDeleteForTaskAtIndex:(NSInteger)taskIdx {
    // Mark that a task content refresh is in progress
    self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    AFATableControllerContentModel *taskContentModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeFilesContent];
    ASDKModelContent *selectedContentModel = taskContentModel.attachedContentArr[taskIdx];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskContentDeleteForContent:selectedContentModel
                                 withCompletionBlock:^(BOOL isContentDeleted, NSError *error) {
                                     __strong typeof(self) strongSelf = weakSelf;
                                     
                                     // Mark that the refresh operation has ended
                                     strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
                                     
                                     if (!isContentDeleted) {
                                         [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentDeleteErrorText, @"Task delete error")];
                                     } else {
                                         // Trigger a task content refresh
                                         [strongSelf refreshTaskContent];
                                     }
    }];
}

- (void)onRemoveInvolvedUserForCurrentTask:(ASDKModelUser *)user {
    // Mark that a task contributor list refresh is in progress
    self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    
    AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskService requestToRemoveTaskUserInvolvement:user
                                          forTaskID:self.taskID
                                    completionBlock:^(BOOL isUserInvolved, NSError *error) {
                                        __strong typeof(self) strongSelf = weakSelf;
                                        // Mark that the refresh operation has ended
                                        strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
                                        
                                        if (!error && !isUserInvolved) {
                                            // Trigger a task details refresh
                                            [strongSelf refreshTaskDetails];
                                        } else {
                                            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentDeleteErrorText, @"Task delete error")];
                                        }
                                    }];
}

- (void)toggleDatePickerComponent {
    // Check whether the date picker component is initialized
    if (!self.datePicker) {
        self.datePicker = [UIDatePicker new];
        self.datePicker.datePickerMode = UIDatePickerModeDate;
        [self.datePickerContainerView addSubview:self.datePicker];
        
        NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:self.datePicker
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.datePickerContainerView
                                                                         attribute:NSLayoutAttributeTop
                                                                        multiplier:1
                                                                          constant:0];
        NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:self.datePicker
                                                                             attribute:NSLayoutAttributeLeading
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.datePickerContainerView
                                                                             attribute:NSLayoutAttributeLeading
                                                                            multiplier:1
                                                                              constant:0];
        
        [NSLayoutConstraint activateConstraints:@[leadingConstraint, topConstraint]];
    }
    
    NSInteger datePickerConstant = 0;
    NSInteger taskDetailsTableViewTopConstant = 0;
    if (!self.datePickerBottomConstraint.constant) {
        datePickerConstant = -(CGRectGetHeight(self.datePicker.frame) + CGRectGetHeight(self.datePickerToolbar.frame) + 10);
    } else {
        taskDetailsTableViewTopConstant = -CGRectGetHeight(self.datePicker.frame) / 2;
    }
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:0
         usingSpringWithDamping:.9f
          initialSpringVelocity:20.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.datePickerBottomConstraint.constant = datePickerConstant;
                         self.taskDetailsTableViewTopConstraint.constant = taskDetailsTableViewTopConstant;
                         [self.view layoutIfNeeded];
                     } completion:nil];
}

- (void)toggleContentPickerComponent {
    NSInteger contentPickerConstant = 0;
    if (!self.contentPickerContainerBottomConstraint.constant) {
        contentPickerConstant = -(CGRectGetHeight(self.contentPickerContainer.frame));
    }
    
    // Show the content picker container
    if (!contentPickerConstant) {
        self.contentPickerContainer.hidden = NO;
    }
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:0
         usingSpringWithDamping:.95f
          initialSpringVelocity:20.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.contentPickerContainerBottomConstraint.constant = contentPickerConstant;
                         [self.view layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         if (contentPickerConstant) {
                             self.contentPickerContainer.hidden = YES;
                         }
                     }];
}

- (void)toggleFullscreenOverlayView {
    CGFloat alphaValue = !self.fullScreenOverlayView.alpha ? .4f : .0f;
    if (alphaValue) {
        self.fullScreenOverlayView.hidden = NO;
    }
    
    [UIView animateWithDuration:kDefaultAnimationTime animations:^{
        self.fullScreenOverlayView.alpha = alphaValue;
    } completion:^(BOOL finished) {
        if (!alphaValue) {
            self.fullScreenOverlayView.hidden = YES;
        }
    }];
}

- (IBAction)onFullscreenOverlayTap:(id)sender {
    [self toggleFullscreenOverlayView];
    
    if (AFATaskDetailsSectionTypeFilesContent == self.currentSelectedSection) {
        [self toggleContentPickerComponent];
    }
}

- (IBAction)onAdd:(UIBarButtonItem *)sender {
    if (AFATaskDetailsSectionTypeFilesContent == self.currentSelectedSection) {
        [self toggleFullscreenOverlayView];
        [self toggleContentPickerComponent];
    } else if (AFATaskDetailsSectionTypeContributors == self.currentSelectedSection) {
        [self performSegueWithIdentifier:kSegueIDTaskDetailsAddContributor
                                  sender:sender];
    } else if (AFATaskDetailsSectionTypeComments == self.currentSelectedSection) {
        [self performSegueWithIdentifier:kSegueIDTaskDetailsAddComments
                                  sender:sender];
    }
}

- (void)claimTask {
    // Mark that a general refresh operation is in progress
    self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    
    AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskService requestTaskClaimForTaskID:self.taskID
                           completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                               __strong typeof(self) strongSelf = weakSelf;
                               
                               if (!error) {
                                   // Trigger a task details refresh
                                   [strongSelf refreshTaskDetails];
                               } else {
                                   [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                               }
                               
                               // Mark that the refresh operation has ended
                               strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    }];
}

- (void)unclaimTask {
    // Mark that a general refresh operation is in progress
    self.controllerState |= AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    
    AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskService requestTaskUnclaimForTaskID:self.taskID
                             completionBlock:^(BOOL isTaskClaimed, NSError *error) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 if (!error ) {
                                     // Trigger a task details refresh
                                     [strongSelf refreshTaskDetails];
                                 } else {
                                     [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogGenericNetworkErrorText, @"Generic network error")];
                                 }
                                 
                                 // Mark that the refresh operation has ended
                                 strongSelf.controllerState &= ~AFATaskDetailsLoadingStateGeneralRefreshInProgress;
    }];
}


#pragma mark -
#pragma mark KVO bindings

- (void)handleBindingsForTaskListViewController {
    self.kvoManager = [AFAKVOManager managerWithObserver:self];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:self
                        forKeyPath:NSStringFromSelector(@selector(controllerState))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 __strong typeof(self) strongSelf = weakSelf;
                                 
                                 // Update progress status for underlaying models
                                 if ([self.tableController.model respondsToSelector:@selector(isRefreshInProgress)]) {
                                     BOOL isRefreshInProgress = (AFATaskDetailsLoadingStateGeneralRefreshInProgress & self.controllerState);
                                     
                                     ((AFATableControllerContentModel *)strongSelf.tableController.model).isRefreshInProgress = isRefreshInProgress;
                                 }
                                 
                                 strongSelf.taskDetailsTableView.hidden = (AFATaskDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                                 strongSelf.loadingActivityView.hidden = (AFATaskDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? NO : YES;
                                 strongSelf.loadingActivityView.animating = (AFATaskDetailsLoadingStateGeneralRefreshInProgress & strongSelf.controllerState) ? YES : NO;
                             }];
}


#pragma mark -
#pragma mark Cell factories and cell actions

- (void)setUpCellFactories {
    // Details cell factory
    AFATableControllerTaskDetailsCellFactory *detailsCellFactory = [AFATableControllerTaskDetailsCellFactory new];
    detailsCellFactory.appThemeColor = self.navigationBarThemeColor;
    
    // Register details cell factory actions
    __weak typeof(self) weakSelf = self;
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf performSegueWithIdentifier:kSegueIDTaskDetailsAddContributor
                                        sender:nil];
    } forCellType:[detailsCellFactory cellTypeForReAssignCell]];
    
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        // Pick date cell action
        __strong typeof(self) strongSelf = weakSelf;
        NSDate *dueDate = nil;
        
        // Display the date picker
        [strongSelf toggleDatePickerComponent];
        
        AFATableControllerTaskDetailsModel *taskDetailsModel = [self reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeTaskDetails];
        
        // If there is a previously registered due date, use that one for the date picker
        // If not, pick the current date
        dueDate = taskDetailsModel.currentTask.dueDate ? taskDetailsModel.currentTask.dueDate : [[NSDate date] endOfToday];
        
        //Change model's date according to the default pick
        taskDetailsModel.currentTask.dueDate = dueDate;
        
        [strongSelf.datePicker setDate:dueDate
                              animated:YES];
        [strongSelf.taskDetailsTableView reloadData];
    } forCellType:[detailsCellFactory cellTypeForDueDateCell]];
    
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf performSegueWithIdentifier:kSegueIDTaskDetailsViewProcess
                                        sender:nil];
    } forCellType:[detailsCellFactory cellTypeForProcessCell]];
    
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf completeTask];
    } forCellType:[detailsCellFactory cellTypeForCompleteCell]];
    
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf claimTask];
    } forCellType:[detailsCellFactory cellTypeForClaimCell]];
    
    [detailsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        [strongSelf unclaimTask];
    } forCellType:[detailsCellFactory cellTypeForRequeueCell]];
    
    // Content cell factory
    AFATableControllerContentCellFactory *contentCellFactory = [AFATableControllerContentCellFactory new];
    
    [contentCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        // Cell content delete action
        __strong typeof(self) strongSelf = weakSelf;
        
        NSInteger contentToDeleteIdx = [changeParameters[kCellFactoryCellParameterCellIdx] integerValue];
        AFATableControllerContentModel *taskContentModel = [strongSelf reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeFilesContent];
        NSString *contentName = ((ASDKModelContent *)taskContentModel.attachedContentArr[contentToDeleteIdx]).contentName;
        
        [strongSelf showConfirmationAlertControllerWithMessage:[NSString stringWithFormat:NSLocalizedString(kLocalizationAlertDialogDeleteContentQuestionFormat, @"Delete confirmation question"), contentName]
                                       confirmationBlockAction:^{
                                           [weakSelf onContentDeleteForTaskAtIndex:contentToDeleteIdx];
                                       }];
        
    } forCellType:[contentCellFactory cellTypeForDeleteContent]];
    
    [contentCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        // Cell content download action
        __strong typeof(self) strongSelf = weakSelf;
        
        NSInteger contentToDownloadIdx = ((NSIndexPath *)changeParameters[kCellFactoryCellParameterCellIndexpath]).row;
        AFATableControllerContentModel *taskContentModel = [strongSelf reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeFilesContent];
        ASDKModelContent *contentToDownload = (ASDKModelContent *)taskContentModel.attachedContentArr[contentToDownloadIdx];
        
        [strongSelf.contentPickerViewController dowloadContent:contentToDownload
                                            allowCachedContent:YES];
        
    } forCellType:[contentCellFactory cellTypeForDownloadContent]];
    
    // Contributors cell factory
    AFATableControllerTaskContributorsCellFactory *contributorsCellFactory = [AFATableControllerTaskContributorsCellFactory new];
    
    [contributorsCellFactory registerCellAction:^(NSDictionary *changeParameters) {
        __strong typeof(self) strongSelf = weakSelf;
        
        NSInteger contributorToDeleteIdx = [changeParameters[kCellFactoryCellParameterCellIdx] integerValue];
        AFATableControllerTaskContributorsModel *taskContributorsModel = [strongSelf reusableTableControllerModelForSectionType:AFATaskDetailsSectionTypeContributors];
        ASDKModelProfile *contributor = (ASDKModelProfile *)taskContributorsModel.involvedPeople[contributorToDeleteIdx];
        NSString *contributorName = [contributor normalisedName];
        
        [strongSelf showConfirmationAlertControllerWithMessage:[NSString stringWithFormat:NSLocalizedString(kLocalizationAlertDialogDeleteContributorQuestionFormat, @"Delete contributor confirmation question"), contributorName]
                                       confirmationBlockAction:^{
                                           ASDKModelUser *userModel = [ASDKModelUser new];
                                           userModel.userID = contributor.instanceID;
                                           [weakSelf onRemoveInvolvedUserForCurrentTask:userModel];
        }];
        
    } forCellType:[contributorsCellFactory cellTypeForDeleteContributor]];
    
    // Comment cell factory
    AFATableControllerCommentCellFactory *commentCellFactory = [AFATableControllerCommentCellFactory new];
    
    self.cellFactoryDict[@(AFATaskDetailsSectionTypeTaskDetails)] = detailsCellFactory;
    self.cellFactoryDict[@(AFATaskDetailsSectionTypeContributors)] = contributorsCellFactory;
    self.cellFactoryDict[@(AFATaskDetailsSectionTypeFilesContent)] = contentCellFactory;
    self.cellFactoryDict[@(AFATaskDetailsSectionTypeComments)] = commentCellFactory;
}

- (id)dequeueCellFactoryForSectionType:(AFATaskDetailsSectionType)sectionType {
    return self.cellFactoryDict[@(sectionType)];
}


#pragma mark -
#pragma mark Convenience methods

- (void)setupLocalization {
    [self.backBarButtonItem setTitleTextAttributes:@{NSFontAttributeName           : [UIFont glyphiconFontWithSize:15],
                                                     NSForegroundColorAttributeName: [UIColor whiteColor]}
                                          forState:UIControlStateNormal];
    self.backBarButtonItem.title = [NSString iconStringForIconType:ASDKGlyphIconTypeChevronLeft];
}

- (UIButton *)buttonForSection:(AFATaskDetailsSectionType)sectionType {
    switch (sectionType) {
        case AFATaskDetailsSectionTypeTaskDetails: {
            return self.taskDetailsButton;
        }
            break;
            
        case AFATaskDetailsSectionTypeForm: {
            return self.taskFormButton;
        }
            break;
            
        case AFATaskDetailsSectionTypeFilesContent: {
            return self.taskContentButton;
        }
            break;
            
        case AFATaskDetailsSectionTypeContributors: {
            return self.taskContributorsButton;
        }
            break;
            
        case AFATaskDetailsSectionTypeComments: {
            return self.taskCommentsButton;
        }
            
        default: {
            return nil;
        }
            break;
    }
}

- (id)reusableTableControllerModelForSectionType:(AFATaskDetailsSectionType)sectionType {
    id reusableObject = nil;
    
    reusableObject = self.sectionContentDict[@(sectionType)];
    if (!reusableObject) {
        switch (sectionType) {
            case AFATaskDetailsSectionTypeTaskDetails: {
                reusableObject = [AFATableControllerTaskDetailsModel new];
            }
                break;
                
            case AFATaskDetailsSectionTypeContributors: {
                reusableObject = [AFATableControllerTaskContributorsModel new];
            }
                break;
                
            case AFATaskDetailsSectionTypeFilesContent: {
                reusableObject = [AFATableControllerContentModel new];
            }
                break;
                
            case AFATaskDetailsSectionTypeComments: {
                reusableObject = [AFATableControllerCommentModel new];
            }
                break;
                
            default:
                break;
        }
    }
    
    return reusableObject;
}


#pragma mark -
#pragma mark AFAContentPickerViewController Delegate

- (void)userPickedImageAtURL:(NSURL *)imageURL {
    [self onFullscreenOverlayTap:nil];
}

- (void)userDidCancelImagePick {
    [self onFullscreenOverlayTap:nil];
}

- (void)pickedContentHasFinishedUploading {
    [self refreshContentForCurrentSection];
    [self.taskDetailsTableView reloadData];
}

- (void)userPickedImageFromCamera {
    [self onFullscreenOverlayTap:nil];
}

- (void)pickedContentHasFinishedDownloadingAtURL:(NSURL *)downloadedFileURL {
}


#pragma mark -
#pragma mark AFATaskformViewControllerDelegate

- (void)userDidCompleteForm {
    [self onBack:nil];
}

- (void)presentFormDetailController:(UIViewController *)controller {
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
    [self.navigationController popToViewController:self
                                          animated:YES];
}

@end
