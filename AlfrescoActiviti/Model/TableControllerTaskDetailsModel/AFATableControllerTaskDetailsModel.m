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
    // If we're dealing with a completed task display additional field
    // for end date and duration
    if ([self hasEndDate]) {
        return AFACompletedTaskDetailsCellTypeEnumCount;
    } else if (![self.currentTask.assignee.instanceID isEqualToString:self.userProfile.instanceID]) {
        // If the assignee does not match the current user profile this means that the current user
        // is involved and cannot see the complete/queue cell
        return AFAInvolvedTaskDetailsCellTypeEnumCount;
    } else {
        return AFATaskDetailsCellTypeEnumCount;
    }
}

- (id)itemAtIndexPath:(NSIndexPath *)indexPath {
    return self.currentTask;
}

- (BOOL)hasEndDate {
    return self.currentTask.endDate ? YES : NO;
}

- (BOOL)isMemberOfCandidateUsers {
    return self.currentTask.isMemberOfCandidateUsers;
}

- (BOOL)isMemberOfCandidateGroup {
    return self.currentTask.isMemberOfCandidateGroup;
}

- (ASDKModelProfile *)assignee {
    return self.currentTask.assignee;
}

- (ASDKModelProfile *)currentUserProfile {
    return self.userProfile;
}

@end
