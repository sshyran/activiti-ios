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

#import "AFAContributorTableViewCell.h"
@import ActivitiSDK;

@implementation AFAContributorTableViewCell

#pragma mark -
#pragma makr Life cycle

- (void)awakeFromNib {
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

#pragma mark -
#pragma mark Public interface

- (void)setUpCellWithProfile:(ASDKModelProfile *)profile {
    NSString *contributorName = nil;
    if (profile.firstName.length) {
        contributorName = profile.firstName;
    }
    
    if (profile.lastName.length) {
        if (contributorName.length) {
            contributorName = [contributorName stringByAppendingFormat:@" %@", profile.lastName];
        } else {
            contributorName = profile.lastName;
        }
    }
    
    self.contributorNameLabel.text = contributorName;
    [self.avararInitialsView updateInitialsForName:contributorName];
}

- (void)setUpCellWithUser:(ASDKModelUser *)user {
    NSString *contributorName = nil;
    if (user.firstName.length) {
        contributorName = user.firstName;
    }
    
    if (user.lastName.length) {
        if (contributorName.length) {
            contributorName = [contributorName stringByAppendingFormat:@" %@", user.lastName];
        } else {
            contributorName = user.lastName;
        }
    }
    
    self.contributorNameLabel.text = contributorName;
    [self.avararInitialsView updateInitialsForName:contributorName];
}

@end
