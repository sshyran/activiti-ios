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

#import "AFATableControllerTaskDetailsCellFactory.h"

// Cells
#import "AFANameTableViewCell.h"
#import "AFACompleteTableViewCell.h"
#import "AFAAssigneeTableViewCell.h"
#import "AFADueTableViewCell.h"
#import "AFADescriptionTableViewCell.h"
#import "AFACreatedDateTableViewCell.h"
#import "AFAProcessMembershipTableViewCell.h"
#import "AFACompletedDateTableViewCell.h"
#import "AFADurationTableViewCell.h"
#import "AFAClaimTableViewCell.h"
#import "AFAAuditLogTableViewCell.h"

// Constants
#import "AFAUIConstants.h"

@interface AFATableControllerTaskDetailsCellFactory () <AFADueTableViewCellDelegate,
                                                        AFACompleteTableViewCellDelegate,
                                                        AFAProcessMembershipTableViewCellDelegate,
                                                        AFAClaimTableViewCellDelegate,
                                                        AFAAssigneeTableViewCellDelegate,
                                                        AFAAuditLogTableViewCellDelegate>

@end

@implementation AFATableControllerTaskDetailsCellFactory

#pragma mark -
#pragma mark AFATableViewCellFactoryDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView
              cellForIndexPath:(NSIndexPath *)indexPath
                      forModel:(id<AFATableViewModelDelegate>)model {
    UITableViewCell *cell = nil;
    BOOL isCompletedTask = NO;
    BOOL isAssignedTask = [[[model assignee] instanceID] isEqualToString:[[model currentUserProfile] instanceID]];
    
    if ([model respondsToSelector:@selector(hasEndDate)]) {
        isCompletedTask = [model hasEndDate];
    }
    
    if (!isCompletedTask) {
        if (isAssignedTask) {
            // Handle task details cell section rows
            switch (indexPath.row) {
                case AFATaskDetailsCellTypeTaskName: {
                    cell = [self dequeuedNameCellAtIndexPath:indexPath
                                               fromTableView:tableView
                                                   withModel:model];
                }
                    break;
                    
                case AFATaskDetailsCellTypeComplete: {
                    // There are cases when the user needs to be displayed on the same
                    // position as the complete cell with choices regarding claiming
                    // and / or completing the task
                    if (([model isMemberOfCandidateGroup] ||
                         [model isMemberOfCandidateUsers]) &&
                        ![model assignee]) {
                        cell = [self dequeuedClaimCellAtIndexPath:indexPath
                                                    fromTableView:tableView];
                    } else {
                        cell = [self dequeuedCompleteCellAtIndexPath:indexPath
                                                       fromTableView:tableView
                                                           withModel:model];
                    }
                }
                    break;
                    
                case AFATaskDetailsCellTypeAssignee: {
                    cell = [self dequeuedAssigneeCellAtIndexPath:indexPath
                                                   fromTableView:tableView
                                                       withModel:model];
                }
                    break;
                    
                case AFATaskDetailsCellTypeCreated: {
                    cell = [self dequeuedCreatedDateCellAtIndexPath:indexPath
                                                      fromTableView:tableView
                                                          withModel:model];
                }
                    break;
                    
                case AFATaskDetailsCellTypeDue: {
                    cell = [self dequeuedDueCellAtIndexPath:indexPath
                                              fromTableView:tableView
                                                  withModel:model];
                }
                    break;
                    
                case AFATaskDetailsCellTypeProcess: {
                    cell = [self dequeuedProcessMembershipCellAtIndexPath:indexPath
                                                            fromTableView:tableView
                                                                withModel:model];
                }
                    break;
                    
                case AFATaskDetailsCellTypeDescription: {
                    cell = [self dequeuedDescriptionCellAtIndexPath:indexPath
                                                      fromTableView:tableView
                                                          withModel:model];
                }
                    break;
                    
                default: break;
            }
        } else {
            // Handle involved task details cells
            switch (indexPath.row) {
                case AFAInvolvedTaskDetailsCellTypeName: {
                    cell = [self dequeuedNameCellAtIndexPath:indexPath
                                               fromTableView:tableView
                                                   withModel:model];
                }
                    break;
                    
                case AFAInvolvedTaskDetailsCellTypeAssignee: {
                    cell = [self dequeuedAssigneeCellAtIndexPath:indexPath
                                                   fromTableView:tableView
                                                       withModel:model];
                }
                    break;
                    
                case AFAInvolvedTaskDetailsCellTypeCreated: {
                    cell = [self dequeuedCreatedDateCellAtIndexPath:indexPath
                                                      fromTableView:tableView
                                                          withModel:model];
                }
                    break;
                    
                case AFAInvolvedTaskDetailsCellTypeDue: {
                    cell = [self dequeuedDueCellAtIndexPath:indexPath
                                              fromTableView:tableView
                                                  withModel:model];
                }
                    break;
                    
                case AFAInvolvedTaskDetailsCellTypeProcess: {
                    cell = [self dequeuedProcessMembershipCellAtIndexPath:indexPath
                                                            fromTableView:tableView
                                                                withModel:model];
                }
                    break;
                    
                case AFAInvolvedTaskDetailsCellTypeDescription: {
                    cell = [self dequeuedDescriptionCellAtIndexPath:indexPath
                                                      fromTableView:tableView
                                                          withModel:model];
                }
                    break;
                    
                default:
                    break;
            }
        }
    } else {
        // Handle completed task details cell section rows
        switch (indexPath.row) {
            case AFACompletedTaskDetailsCellTypeTaskName: {
                cell = [self dequeuedNameCellAtIndexPath:indexPath
                                           fromTableView:tableView
                                               withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeAssignee: {
                cell = [self dequeuedAssigneeCellAtIndexPath:indexPath
                                               fromTableView:tableView
                                                   withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeCreated: {
                cell = [self dequeuedCreatedDateCellAtIndexPath:indexPath
                                                  fromTableView:tableView
                                                      withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeDue: {
                cell = [self dequeuedDueCellAtIndexPath:indexPath
                                          fromTableView:tableView
                                              withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeEnd: {
                cell = [self dequeuedEndDateCellAtIndexPath:indexPath
                                              fromTableView:tableView
                                                  withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeDuration: {
                cell = [self dequeuedDurationCellAtIndexPath:indexPath
                                               fromTableView:tableView
                                                   withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeProcess: {
                cell = [self dequeuedProcessMembershipCellAtIndexPath:indexPath
                                                        fromTableView:tableView
                                                            withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeAuditLog: {
                cell = [self dequeueAuditLogCellAtIndexPath:indexPath
                                              fromTableView:tableView
                                                  withModel:model];
            }
                break;
                
            case AFACompletedTaskDetailsCellTypeDescription: {
                cell = [self dequeuedDescriptionCellAtIndexPath:indexPath
                                                  fromTableView:tableView
                                                      withModel:model];
            }
                break;
                
            default: break;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
         forModel:(id<AFATableViewModelDelegate>)model {
    // Prevent the cell from inheriting the Table View's margin settings
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}


#pragma mark -
#pragma mark AFAAssigneeTableViewCellDelegate

- (void)onChangeAssignee {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeReAssign];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark AFADueTableViewCellDelegate

- (void)onAddDueDateTap {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeDue];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark AFACompleteTableViewCellDelegate

- (void)onCompleteTask {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeComplete];
    if (actionBlock) {
        actionBlock(nil);
    }
}

- (void)onRequeueTask {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeRequeue];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark AFAProcessMembershipTableViewCellDelegate

- (void)onViewProcessTap {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeProcess];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark AFAClaimTableViewCellDelegate

- (void)onClaimTask {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFATaskDetailsCellTypeClaim];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark AFAAuditLogTableViewCellDelegate

- (void)onViewAuditLog {
    AFATableControllerCellActionBlock actionBlock = [self actionForCellOfType:AFACompletedTaskDetailsCellTypeAuditLog];
    if (actionBlock) {
        actionBlock(nil);
    }
}


#pragma mark -
#pragma mark Public interface

- (NSInteger)cellTypeForDueDateCell {
    return AFATaskDetailsCellTypeDue;
}

- (NSInteger)cellTypeForCompleteCell {
    return AFATaskDetailsCellTypeComplete;
}

- (NSInteger)cellTypeForProcessCell {
    return AFATaskDetailsCellTypeProcess;
}

- (NSInteger)cellTypeForClaimCell {
    return AFATaskDetailsCellTypeClaim;
}

- (NSInteger)cellTypeForRequeueCell {
    return AFATaskDetailsCellTypeRequeue;
}

- (NSInteger)cellTypeForReAssignCell {
    return AFATaskDetailsCellTypeReAssign;
}

- (NSInteger)cellTypeForAuditLogCell {
    return AFACompletedTaskDetailsCellTypeAuditLog;
}


#pragma mark -
#pragma mark Convenience methods

- (UITableViewCell *)dequeuedNameCellAtIndexPath:(NSIndexPath *)indexPath
                                   fromTableView:(UITableView *)tableView
                                       withModel:(id<AFATableViewModelDelegate>)model {
    AFANameTableViewCell *nameCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsName
                                                                     forIndexPath:indexPath];
    [nameCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    
    return nameCell;
}

- (UITableViewCell *)dequeuedCompleteCellAtIndexPath:(NSIndexPath *)indexPath
                                       fromTableView:(UITableView *)tableView
                                           withModel:(id<AFATableViewModelDelegate>)model {
    AFACompleteTableViewCell *completeCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsComplete
                                                                             forIndexPath:indexPath];
    completeCell.delegate = self;
    [completeCell setUpWithThemeColor:self.appThemeColor];
    
    // Enable the requeue button if it's the case
    BOOL displayRequeueButton = [[[model assignee] instanceID] isEqualToString:[[model currentUserProfile] instanceID]];
    completeCell.requeueRoundedBorderView.hidden = !displayRequeueButton;
    completeCell.requeueTaskButton.hidden = !displayRequeueButton;
    
    return completeCell;
}

- (UITableViewCell *)dequeuedClaimCellAtIndexPath:(NSIndexPath *)indexPath
                                    fromTableView:(UITableView *)tableView {
    AFAClaimTableViewCell *claimCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsClaim
                                                                       forIndexPath:indexPath];
    claimCell.delegate = self;
    [claimCell setUpWithThemeColor:self.appThemeColor];
    
    return claimCell;
}

- (UITableViewCell *)dequeuedAssigneeCellAtIndexPath:(NSIndexPath *)indexPath
                                       fromTableView:(UITableView *)tableView
                                           withModel:(id<AFATableViewModelDelegate>)model {
    AFAAssigneeTableViewCell *assigneeCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsAssignee
                                                                             forIndexPath:indexPath];
    [assigneeCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    assigneeCell.delegate = self;
    
    return assigneeCell;
}

- (UITableViewCell *)dequeuedCreatedDateCellAtIndexPath:(NSIndexPath *)indexPath
                                       fromTableView:(UITableView *)tableView
                                           withModel:(id<AFATableViewModelDelegate>)model {
    AFACreatedDateTableViewCell *createdDateCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsCreated
                                                                                   forIndexPath:indexPath];
    [createdDateCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    
    return createdDateCell;
}

- (UITableViewCell *)dequeuedDueCellAtIndexPath:(NSIndexPath *)indexPath
                                          fromTableView:(UITableView *)tableView
                                              withModel:(id<AFATableViewModelDelegate>)model {
    AFADueTableViewCell *dueCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsDue
                                                                   forIndexPath:indexPath];
    [dueCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    dueCell.delegate = self;
    
    return dueCell;
}

- (UITableViewCell *)dequeuedProcessMembershipCellAtIndexPath:(NSIndexPath *)indexPath
                                                fromTableView:(UITableView *)tableView
                                                    withModel:(id<AFATableViewModelDelegate>)model {
    AFAProcessMembershipTableViewCell *processCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsProcess
                                                                                     forIndexPath:indexPath];
    [processCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    processCell.delegate = self;
    
    return processCell;
}

- (UITableViewCell *)dequeuedDescriptionCellAtIndexPath:(NSIndexPath *)indexPath
                                          fromTableView:(UITableView *)tableView
                                              withModel:(id<AFATableViewModelDelegate>)model {
    AFADescriptionTableViewCell *descriptionCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsDescription
                                                                                   forIndexPath:indexPath];
    [descriptionCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    
    return descriptionCell;
}

- (UITableViewCell *)dequeuedEndDateCellAtIndexPath:(NSIndexPath *)indexPath
                                    fromTableView:(UITableView *)tableView
                                        withModel:(id<AFATableViewModelDelegate>)model {
    AFACompletedDateTableViewCell *completedDateCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsCompletedDate
                                                                                       forIndexPath:indexPath];
    [completedDateCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    return completedDateCell;
}

- (UITableViewCell *)dequeuedDurationCellAtIndexPath:(NSIndexPath *)indexPath
                                       fromTableView:(UITableView *)tableView
                                           withModel:(id<AFATableViewModelDelegate>)model {
    AFADurationTableViewCell *durationCell = [tableView dequeueReusableCellWithIdentifier:kCellIDTaskDetailsDuration
                                                                             forIndexPath:indexPath];
    [durationCell setUpCellWithTask:[model itemAtIndexPath:indexPath]];
    
    return durationCell;
}

- (UITableViewCell *)dequeueAuditLogCellAtIndexPath:(NSIndexPath *)indexPath
                                      fromTableView:(UITableView *)tableView
                                          withModel:(id<AFATableViewModelDelegate>)model {
    AFAAuditLogTableViewCell *auditCell = [tableView dequeueReusableCellWithIdentifier:kCellIDAuditLog
                                                                          forIndexPath:indexPath];
    return auditCell;
}

@end
