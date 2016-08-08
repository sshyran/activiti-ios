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

#import "AFAFilterViewController.h"

// Categories
#import "UIColor+AFATheme.h"

// Cells
#import "AFAFilterOptionTableViewCell.h"
#import "AFAFilterHeaderTableViewCell.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFALogConfiguration.h"
#import "AFAFilterServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"

// Constants
#import "AFABusinessConstants.h"
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"

typedef NS_ENUM(NSInteger, AFAFilterSectionType) {
    AFAFilterSectionTypeFilterOptions = 0,
    AFAFilterSectionTypeSortOptions,
    AFAFilterSectionTypeEnumCount
};


static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAFilterViewController () <AFAFilterOptionTableViewcellProtocol, AFAFilterHeaderTableViewCellProtocol>

@property (weak, nonatomic) IBOutlet UITableView                            *filterTableView;
@property (weak, nonatomic) IBOutlet UIButton                               *searchButton;


// Internal properties
@property (strong, nonatomic) NSArray                                       *filterListArr;
@property (strong, nonatomic) NSArray                                       *sortOptionArr;
@property (strong, nonatomic) AFAGenericFilterModel                         *currentFilterModel;
@property (assign, nonatomic) AFAGenericFilterStateType                     state;
@property (assign, nonatomic) AFAGenericFilterModelSortType                 sortType;
@property (assign, nonatomic) AFAGenericFilterAssignmentType                assignmentType;
@property (strong, nonatomic) NSString                                      *filterID;
@property (strong, nonatomic) AFAFilterServicesFilterListCompletionBlock    taskFilterListResponseCompletionBlock;
@property (strong, nonatomic) AFAFilterServicesFilterListCompletionBlock    processInstanceFilterListResponseCompletionBlock;
@property (strong, nonatomic) UIColor                                       *applicationThemeColor;

@end

@implementation AFAFilterViewController


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.filterListArr = [NSArray array];
        self.sortOptionArr = @[NSLocalizedString(kLocalizationListScreenSortNewestFirstText, @"Newest first"),
                               NSLocalizedString(kLocalizationListScreenSortOldestFirstText, @"Oldest first"),
                               NSLocalizedString(kLocalizationListScreenSortDueFirstText, @"Due first"),
                               NSLocalizedString(kLocalizationListScreenSortDueLastText, @"Due Last"),];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.applicationThemeColor = self.currentApp ? [UIColor applicationColorForTheme:self.currentApp.theme] : [UIColor applicationThemeDefaultColor];
    
    // Apply the theme color to the search button
    self.searchButton.backgroundColor = self.applicationThemeColor;
    
    // Set up the filter list table view to adjust it's size automatically
    self.filterTableView.estimatedRowHeight = 44.0f;
    self.filterTableView.rowHeight = UITableViewAutomaticDimension;
    
    __weak typeof(self) weakSelf = self;
    self.taskFilterListResponseCompletionBlock = ^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf handleFilterResponseFor:filterList
                                      error:error
                                 filterType:AFAFilterTypeTask];
    };
    
    self.processInstanceFilterListResponseCompletionBlock = ^(NSArray *filterList, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf handleFilterResponseFor:filterList
                                      error:error
                                 filterType:AFAFilterTypeProcessInstance];
    };
    
    // Fetch filter values from server
    [self loadTaskFilterList];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Public interface

- (void)loadTaskFilterList {
    [self fetchTaskFilterListWithCompletionBlock:self.taskFilterListResponseCompletionBlock];
}

- (void)loadProcessInstanceFilterList {
    [self fetchProcessInstanceFilterListWithCompletionBlock:self.processInstanceFilterListResponseCompletionBlock];
}

- (CGSize)contentSizeForFilterView {
    CGSize tableContentSize = self.filterTableView.contentSize;
    // Besides the height of the table content size return also the height
    // of the search button and it's vertical constraints values
    tableContentSize.height += CGRectGetHeight(self.searchButton.frame) + 70;
    return tableContentSize;
}

- (void)rollbackFilterValuesToFilter:(AFAGenericFilterModel *)filterModel {
    self.currentFilterModel = filterModel;
    self.sortType = filterModel.sortType;
    [self.filterTableView reloadData];
}

#pragma mark -
#pragma mark Actions

- (IBAction)onSearch:(id)sender {
    AFAGenericFilterModel *filter = [AFAGenericFilterModel new];
    filter.state = self.state;
    filter.assignmentType = self.assignmentType;
    filter.sortType = self.sortType;
    filter.filterID = self.filterID;
    filter.appDefinitionID = self.currentApp.modelID;
    
    if ([self.delegate respondsToSelector:@selector(searchWithFilterModel:)]) {
        [self.delegate searchWithFilterModel:filter];
    }
}


#pragma mark -
#pragma mark Service integration

- (void)fetchTaskFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    AFAFilterServices *filterServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFilterServices];
    
    // If there's an app defined fetch the filters for it,
    // otherwise fetch the filter list for ad-hoc tasks
    if (self.currentApp) {
        [filterServices requestTaskFilterListForAppID:self.currentApp.modelID
                                  withCompletionBlock:completionBlock];
    } else {
        [filterServices requestTaskFilterListWithCompletionBlock:completionBlock];
    }
}

- (void)fetchProcessInstanceFilterListWithCompletionBlock:(AFAFilterServicesFilterListCompletionBlock)completionBlock {
    AFAFilterServices *filterServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeFilterServices];
    
    // If there's an app defined fetch the filters for it,
    // otherwise fetch the filter list for ad-hoc tasks
    if (self.currentApp) {
        [filterServices requestProcessInstanceFilterListForAppID:self.currentApp.modelID
                                             withCompletionBlock:completionBlock];
    } else {
        [filterServices requestProcessInstanceFilterListWithCompletionBlock:completionBlock];
    }
}


#pragma mark -
#pragma mark AFAFilterOptionTableViewcellProtocol

- (void)didChangedFilterOptionForCell:(AFAFilterOptionTableViewCell *)cell {
    NSIndexPath *cellIndexPathForFilterOption = [self.filterTableView indexPathForCell:cell];
    
    switch (cellIndexPathForFilterOption.section) {
        case AFAFilterSectionTypeFilterOptions: {
            self.currentFilterModel = [self buildFilterFromModel:self.filterListArr[cellIndexPathForFilterOption.row]];
        }
            break;
            
        case AFAFilterSectionTypeSortOptions: {
            // Create a AFAGenericFilterModelSortType enum value by adding 1 as a displacement
            // according to the convention made on the enum
            self.sortType = cellIndexPathForFilterOption.row + 1;
        }
            break;
            
        default:
            break;
    }
    
    [self.filterTableView reloadData];
}


#pragma mark -
#pragma mark AFAFilterHeaderTableViewCellProtocol

- (void)didClearAll:(AFAFilterHeaderTableViewCell *)cell {
    // Reset back to the first filter of the collection
    self.currentFilterModel = [self buildFilterFromModel:self.filterListArr.firstObject];
    [self.filterTableView reloadData];
    
    if ([self.delegate respondsToSelector:@selector(clearFilterInputText)]) {
        [self.delegate clearFilterInputText];
    }
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return AFAFilterSectionTypeEnumCount;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    NSUInteger sectionCount = 0;
    
    switch (section) {
        case AFAFilterSectionTypeFilterOptions: {
            sectionCount = self.filterListArr.count;
        }
            break;
            
        case AFAFilterSectionTypeSortOptions: {
            sectionCount = self.sortOptionArr.count;
        }
            break;
            
        default:
            break;
    }
    
    return sectionCount;
}

-(UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    AFAFilterHeaderTableViewCell *filterHeaderViewCell = [tableView dequeueReusableCellWithIdentifier:kCellIDFilterHeader];
    filterHeaderViewCell.delegate = self;
    
    switch (section) {
        case AFAFilterSectionTypeFilterOptions: {
            [filterHeaderViewCell setUpForFilterList];
        }
            break;
            
        case AFAFilterSectionTypeSortOptions: {
            [filterHeaderViewCell setUpForSortList];
        }
            break;
            
        default:
            break;
    }
    
    return filterHeaderViewCell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFAFilterOptionTableViewCell *filterOptionCell = [tableView dequeueReusableCellWithIdentifier:kCellIDFilterOption
                                                                                     forIndexPath:indexPath];
    filterOptionCell.checkboxButton.trailStrokeColor = self.applicationThemeColor;
    filterOptionCell.checkboxButton.strokeColor = self.applicationThemeColor;
    filterOptionCell.delegate = self;
    
    switch (indexPath.section) {
        case AFAFilterSectionTypeFilterOptions:{
            filterOptionCell.filterLabel.text = ((ASDKModelFilter *) self.filterListArr[indexPath.row]).name;
            
            filterOptionCell.checkboxButton.selected = (indexPath.row == [self indexOfModelForFilter:self.currentFilterModel]);
        }
            break;
            
        case AFAFilterSectionTypeSortOptions: {
            filterOptionCell.filterLabel.text = (NSString *)self.sortOptionArr[indexPath.row];
            
            filterOptionCell.checkboxButton.selected = (indexPath.row == self.sortType - 1);
        }
            break;
            
        default:
            break;
    }
    
    return filterOptionCell;
}


#pragma mark -
#pragma mark Utilities

- (AFAGenericFilterModel *)buildFilterFromModel:(ASDKModelFilter *)filterModel {
    self.filterID = filterModel ? filterModel.modelID : nil;
    self.assignmentType = filterModel ? (NSInteger)filterModel.assignmentType : AFAGenericFilterAssignmentTypeUndefined;
    self.state = filterModel ? (NSInteger)filterModel.state : AFAGenericFilterStateTypeUndefined;
    self.sortType = (NSInteger)filterModel.sortType;
    
    AFAGenericFilterModel *filter = [AFAGenericFilterModel new];
    filter.state = self.state;
    filter.assignmentType = self.assignmentType;
    filter.sortType = self.sortType;
    filter.filterID = self.filterID;
    filter.appDefinitionID = self.currentApp.modelID;
    
    return filter;
}

- (NSInteger)indexOfModelForFilter:(AFAGenericFilterModel *)filter {
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"SELF.modelID == %@", filter.filterID];
    NSArray *filterCollection = [self.filterListArr filteredArrayUsingPredicate:filterPredicate];
    return [self.filterListArr indexOfObject:filterCollection.firstObject];
}

- (void)handleFilterResponseFor:(NSArray *)filterList
                          error:(NSError *)error
                     filterType:(AFAFilterType)filterType {
    __weak typeof(self) weakSelf = self;
    if (!error) {
        // Save the results
        self.filterListArr = filterList ;
        
        // Default as the current filter the first object of the collection
        ASDKModelFilter *currentSelectedFilter =(ASDKModelFilter *)self.filterListArr.firstObject;
        self.currentFilterModel = [self buildFilterFromModel:currentSelectedFilter];
        
        // Notify the delegate that a filter has been parsed and marked as default
        if ([self.delegate respondsToSelector:@selector(filterModelsDidLoadWithDefaultFilter:filterType:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                [strongSelf.delegate filterModelsDidLoadWithDefaultFilter:strongSelf.currentFilterModel
                                                               filterType:filterType];
            });
        }
        
        [self.filterTableView reloadData];
    } else {
        AFALogError(@"There are no selectable filter options available for the user to choose");
        
        // Notify the delegate about the missing filter data
        if ([self.delegate respondsToSelector:@selector(filterModelsDidLoadWithDefaultFilter:filterType:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                [strongSelf.delegate filterModelsDidLoadWithDefaultFilter:nil
                                                               filterType:filterType];
            });
        }
        
    }
}

@end
