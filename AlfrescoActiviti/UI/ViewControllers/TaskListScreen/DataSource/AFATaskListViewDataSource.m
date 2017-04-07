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

#import "AFATaskListViewDataSource.h"

// Constants
#import "AFAUIConstants.h"

// Cells
#import "AFATaskListStyleCell.h"

// View controllers
#import "AFAFilterViewController.h"

// Managers
#import "AFATaskServices.h"
#import "AFAServiceRepository.h"

@implementation AFATaskListViewDataSource


#pragma mark -
#pragma mark Public interface

- (instancetype)initWithDataEntries:(NSArray *)dataEntries
                         themeColor:(UIColor *)themeColor {
    self = [super init];
    if (self) {
        _tasks = dataEntries;
        _themeColor = themeColor;
    }
    
    return self;
}

- (NSArray *)dataEntries {
    return self.tasks;
}

- (void)loadFilterListForController:(AFAFilterViewController *)filterController {
    [filterController loadTaskFilterList];
}

- (void)loadContentListForFilter:(AFAGenericFilterModel *)filter
             withCompletionBlock:(AFAListHandleCompletionBlock)completionBlock {
    AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    __weak typeof(self) weakSelf = self;
    [taskService requestTaskListWithFilter:filter
                       withCompletionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                           __strong typeof(self) strongSelf = weakSelf;
                           completionBlock (strongSelf, taskList, error, paging);
                       }];
}

- (void)processAdditionalEntries:(NSArray *)additionalEntriesArr
                       forPaging:(ASDKModelPaging *)paging {
    _tasks = [self processAdditionalEntries:additionalEntriesArr
                        forExistingEntries:self.tasks
                                    paging:paging];
}


#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFATaskListStyleCell *listCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskListStyle];
    [listCell setupWithTask:self.tasks[indexPath.row]];
    listCell.applicationThemeColor = self.themeColor;
    
    return listCell;
}

@end
