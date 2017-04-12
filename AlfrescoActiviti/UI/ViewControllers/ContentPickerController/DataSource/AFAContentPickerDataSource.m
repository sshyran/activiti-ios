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

#import "AFAContentPickerDataSource.h"

// Constants
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"

// Cells
#import "AFAAddContentTableViewCell.h"

// Managers
@import ActivitiSDK;
#import "AFAIntegrationServices.h"
#import "AFAServiceRepository.h"

@interface AFAContentPickerDataSource ()

@property (strong, nonatomic) NSArray *integrationAccountsArr;

@end

@implementation AFAContentPickerDataSource


#pragma mark -
#pragma mark Public interface

- (void)fetchIntegrationAccountsWithCompletionBlock:(void (^)(NSArray *accounts, NSError *error, ASDKModelPaging *paging))completionBlock {
    __weak typeof(self) weakSelf = self;
    AFAIntegrationServices *integrationServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:(AFAServiceObjectTypeIntegrationServices)];
    [integrationServices requestIntegrationAccountsWithCompletionBlock:^(NSArray *accounts, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            // Filter out all but the Alfresco cloud services - development in progress
            NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"integrationServiceID == %@", kASDKAPIServiceIDAlfrescoCloud];
            NSArray *filtereAccountsdArr = [accounts filteredArrayUsingPredicate:searchPredicate];
            strongSelf.integrationAccountsArr = filtereAccountsdArr;
        }
        
        completionBlock(strongSelf.integrationAccounts, error, paging);
    }];
}

- (NSArray *)integrationAccounts {
    return _integrationAccountsArr;
}


#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return AFAContentPickerCellTypeEnumCount + self.integrationAccounts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AFAAddContentTableViewCell *taskCell = [tableView dequeueReusableCellWithIdentifier:kCellIDAddContent];
    
    switch (indexPath.row) {
        case AFAContentPickerCellTypeLocalContent: {
            taskCell.iconImageView.image = [UIImage imageNamed:@"phone-icon"];
            taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentLocalContent, @"Local content text");
        }
            break;
            
        case AFAContentPickerCellTypeCamera: {
            taskCell.iconImageView.image = [UIImage imageNamed:@"camera-icon"];
            taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentCameraContent, @"Camera content text");
        }
            break;
            
        default:
        { // Handle the integration cells
            ASDKModelIntegrationAccount *account = self.integrationAccounts[indexPath.row - AFAContentPickerCellTypeEnumCount];
            
            if ([kASDKAPIServiceIDAlfrescoCloud isEqualToString:account.integrationServiceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"alfresco-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentAlfrescoContentText, @"Alfresco cloud text");
            } else if ([kASDKAPIServiceIDBox isEqualToString:account.integrationServiceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"box-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentBoxContentText, @"Box text");
            } else if ([kASDKAPIServiceIDGoogleDrive isEqualToString:account.integrationServiceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"drive-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentDriveContentText, @"Google drive text");
            }
        }
            break;
    }
    
    return taskCell;
}

@end
