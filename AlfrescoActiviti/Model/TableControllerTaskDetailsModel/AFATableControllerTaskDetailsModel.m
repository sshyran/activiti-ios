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

#import "AFATableControllerTaskDetailsModel.h"
#import "AFATableControllerTaskDetailsCellFactory.h"

@implementation AFATableControllerTaskDetailsModel


#pragma mark -
#pragma mark AFATableViewModel Delegate

- (NSInteger)numberOfSections {
    return 1;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section {
    BOOL isFormDefined = self.currentTask.formKey ? YES : NO;
    
    // If we're dealing with a completed task display additional field
    // for end date and duration
    if ([self isCompletedTask]) {
        return AFACompletedTaskDetailsCellTypeEnumCount - (isFormDefined ? 0 : 1);
    } else if (![self.currentTask.assigneeModel.modelID isEqualToString:self.userProfile.modelID]) {
        // If the assignee does not match the current user profile this means that the current user
        // is involved and cannot see the complete/queue cell
        return AFAInvolvedTaskDetailsCellTypeEnumCount - (isFormDefined ? 0 : 1);
    } else {
        return AFATaskDetailsCellTypeEnumCount - (isFormDefined ? 0 : 1);
    }
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath {
    return self.currentTask;
}

- (BOOL)isCompletedTask {
    return self.currentTask.endDate ? YES : NO;
}

- (BOOL)canBeRequeued {
    return [self.currentTask.involvedPeople containsObject:self.currentTask.assigneeModel] && (self.currentTask.isMemberOfCandidateUsers || self.currentTask.isMemberOfCandidateGroup);
}

- (BOOL)isAssignedTask {
   return [self.currentTask.assigneeModel.modelID isEqualToString:self.userProfile.modelID];
}

- (BOOL)isChecklistTask {
    return self.currentTask.parentTaskID ? YES : NO;
}

- (BOOL)isAdhocTask {
    return !self.currentTask.processInstanceID.length && !self.currentTask.parentTaskID ? YES : NO;
}

@end
