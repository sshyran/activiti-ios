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

#import "AFADrawerMenuViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"

// Cells
#import "AFAAvatarMenuTableViewCell.h"
#import "AFAMenuButtonCell.h"

// Cateogires
#import "UIImage+AFAFontGlyphicons.h"
#import "UIColor+AFATheme.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFAThumbnailManager.h"
#import "AFAProfileServices.h"

typedef NS_ENUM(NSInteger, AFADrawerMenuCellType) {
    AFADrawerMenuCellTypeAvatar = 0,
    AFADrawerMenuCellTypeApplications,
    AFADrawerMenuCellTypeTasks,
    AFADrawerMenuCellTypeLogout,
    AFADrawerMenuCellTypeEnumCount
};

@interface AFADrawerMenuViewController () <AFAAvatarMenuTableViewCellDelegate, AFAMenuButtonTableViewCellDelegate>

@property (weak, nonatomic)   IBOutlet UITableView  *menuTableView;
@property (strong, nonatomic) UIImage               *profileImage;
@property (assign, nonatomic) BOOL                  processedProfileImage;

@end

@implementation AFADrawerMenuViewController


#pragma mark -
#pragma mark Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshDrawerMenu {
    [self.menuTableView reloadData];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


#pragma mark -
#pragma mark AvatarMenuTableViewCell Delegate

- (void)onAvatarFromCell:(UITableViewCell *)cell {
    if ([self.delegate respondsToSelector:@selector(showUserProfile)]) {
        [self.delegate showUserProfile];
    }
}


#pragma mark -
#pragma mark MenuButtonTableViewCell Delegate

- (void)onMenuButtonFromCell:(UITableViewCell *)cell {
    AFADrawerMenuCellType cellType = [self.menuTableView indexPathForCell:cell].row;
    
    switch (cellType) {
        case AFADrawerMenuCellTypeTasks: {
            if ([self.delegate respondsToSelector:@selector(showAdhocTasks)]) {
                [self.delegate showAdhocTasks];
            }
        }
            break;
            
        case AFADrawerMenuCellTypeLogout: {
            if ([self.delegate respondsToSelector:@selector(logoutUser)]) {
                [self.delegate logoutUser];
            }
        }
            break;
            
        case AFADrawerMenuCellTypeApplications: {
            if ([self.delegate respondsToSelector:@selector(showApplications)]) {
                [self.delegate showApplications];
            }
        }
            break;
            
        default:
            break;
    }
}


#pragma mark -
#pragma mark Service integration

- (void)updateProfileImage {
    AFAProfileServices *profileService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
    __weak typeof(self) weakSelf = self;
    [profileService requestProfileImageWithCompletionBlock:^(UIImage *profileImage, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!error) {
            strongSelf.profileImage = profileImage;
            [strongSelf.menuTableView reloadData];
        }
    }];
}


#pragma mark -
#pragma mark Tableview Delegate & Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return AFADrawerMenuCellTypeEnumCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    
    switch (indexPath.row) {
        case AFADrawerMenuCellTypeAvatar: {
            AFAAvatarMenuTableViewCell *avatarCell = [tableView dequeueReusableCellWithIdentifier:kCellIDDrawerMenuAvatar];
            
            // If we don't have loaded a thumbnail image use a placeholder instead
            // otherwise look in the cache or compute the image and set it once
            // available
            __weak typeof(self) weakSelf = self;
            AFAThumbnailManager *thumbnailManager = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeThumbnailManager];
            
            if (self.processedProfileImage) {
                self.profileImage = [thumbnailManager thumbnailImageForIdentifier:kProfileImageThumbnailIdentifier];
            } else {
                self.profileImage = [thumbnailManager thumbnailForImage:self.profileImage
                                                         withIdentifier:kProfileImageThumbnailIdentifier
                                                               withSize:CGRectGetHeight(avatarCell.avatarView.frame) * [UIScreen mainScreen].scale
                                              processingCompletionBlock:^(UIImage *processedThumbnailImage) {
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      __strong typeof(self) strongSelf = weakSelf;
                                                      strongSelf.processedProfileImage = YES;
                                                      
                                                      AFAAvatarMenuTableViewCell *refetchedAvatarCell = (AFAAvatarMenuTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
                                                      refetchedAvatarCell.avatarView.profileImage = processedThumbnailImage;
                                                  });
                                              }];
            }
            
            avatarCell.avatarView.profileImage = self.profileImage;
            avatarCell.delegate = self;
            
            cell = avatarCell;
        }
            break;
            
        case AFADrawerMenuCellTypeApplications: {
            AFAMenuButtonCell *taskButtonCell = [tableView dequeueReusableCellWithIdentifier:kCellIDDrawerMenuButton];
            taskButtonCell.delegate = self;
            [taskButtonCell.menuButton setImage:[UIImage imageNamed:@"application-icon"]
                                       forState:UIControlStateNormal];
            taskButtonCell.menuButton.tintColor = [UIColor whiteColor];
            
            cell = taskButtonCell;
        }
            break;
            
        case AFADrawerMenuCellTypeTasks: {
            AFAMenuButtonCell *taskButtonCell = [tableView dequeueReusableCellWithIdentifier:kCellIDDrawerMenuButton];
            taskButtonCell.delegate = self;
            [taskButtonCell.menuButton setImage:[UIImage imageNamed:@"adhoc-icon"]
                                       forState:UIControlStateNormal];
            taskButtonCell.menuButton.tintColor = [UIColor whiteColor];
            
            cell = taskButtonCell;
        }
            break;
            
        case AFADrawerMenuCellTypeLogout: {
            AFAMenuButtonCell *logoutButtonCell = [tableView dequeueReusableCellWithIdentifier:kCellIDDrawerMenuButton];
            logoutButtonCell.delegate = self;
            [logoutButtonCell.menuButton setImage:[UIImage imageNamed:@"logout-icon"]
                                         forState:UIControlStateNormal];
            logoutButtonCell.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:.7f];
            
            cell = logoutButtonCell;
        }
            break;
            
        default:
            break;
    }
    
    cell.backgroundColor = [UIColor clearColor];
    
    return cell;
}

@end
