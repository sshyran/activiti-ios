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

#import "AFAContentPickerViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"
#import "AFABusinessConstants.h"

// Categories
#import "UIViewController+AFAAlertAddition.h"

// Managers
#import "AFAServiceRepository.h"
#import "AFATaskServices.h"
#import "AFAProfileServices.h"
#import "AFAIntegrationServices.h"
@import Photos;
@import ActivitiSDK;
@import QuickLook;

// Cells
#import "AFAAddContentTableViewCell.h"

// Views
#import <JGProgressHUD/JGProgressHUD.h>

typedef NS_ENUM(NSInteger, AFAContentPickerCellType) {
    AFAContentPickerCellTypeLocalContent = 0,
    AFAContentPickerCellTypeCamera,
    AFAContentPickerCellTypeEnumCount
};

@interface AFAContentPickerViewController () <UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
QLPreviewControllerDataSource,
QLPreviewControllerDelegate>

@property (weak, nonatomic)   IBOutlet UITableView                          *actionsTableView;
@property (strong, nonatomic) JGProgressHUD                                 *progressHUD;
@property (strong, nonatomic) UIImagePickerController                       *imagePickerController;
@property (strong, nonatomic) QLPreviewController                           *previewController;

// Internal state properties
@property (strong, nonatomic) NSURL                                         *currentSelectedUploadResourceURL;
@property (strong, nonatomic) NSURL                                         *currentSelectedDownloadResourceURL;
@property (strong, nonatomic) NSData                                        *currentSelectedResourceData;
@property (strong, nonatomic) NSArray                                       *integrationAccounts;
@property (strong, nonatomic) ASDKIntegrationLoginWebViewViewController     *integrationLoginController;

@end

@implementation AFAContentPickerViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.progressHUD = [self configureProgressHUD];
    }
    
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad {
    [self fetchIntegrationAccounts];
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
#pragma mark Getters

- (UIImagePickerController *)imagePickerController {
    if (!_imagePickerController) {
        _imagePickerController = [UIImagePickerController new];
        _imagePickerController.delegate = self;
        _imagePickerController.allowsEditing = YES;
    }
    
    return _imagePickerController;
}


#pragma mark -
#pragma mark Actions

- (void)onTakePhoto {
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    [self presentViewController:self.imagePickerController
                       animated:YES
                     completion:nil];
}

- (void)onSelectPhoto {
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self presentViewController:self.imagePickerController
                       animated:YES
                     completion:nil];
}

- (void)dowloadContent:(ASDKModelContent *)content
    allowCachedContent:(BOOL)allowCachedContent {
    [self showDownloadProgressHUD];
    
    AFATaskServices *taskServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
    
    __weak typeof(self) weakSelf = self;
    [taskServices requestTaskContentDownloadForContent:content
                                    allowCachedResults:allowCachedContent
                                     withProgressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                         __strong typeof(self) strongSelf = weakSelf;
                                         
                                         if (!error) {
                                             strongSelf.progressHUD.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(kLocalizationContentPickerComponentDownloadProgressFormat, @"Download progress format"), formattedReceivedBytesString];
                                         } else {
                                             [strongSelf.progressHUD dismiss];
                                             [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentDownloadErrorText, @"Content download error")];
                                         }
                                     } withCompletionBlock:^(NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                         __strong typeof(self) strongSelf = weakSelf;
                                         
                                         if (!error) {
                                             // If local content is available ask the user how he would like to preview it
                                             if (isLocalContent) {
                                                 [strongSelf.progressHUD dismiss];
                                                 [strongSelf showMultipleChoiceAlertControllerWithTitle:nil
                                                                                                message:NSLocalizedString(kLocalizationContentPickerComponentLocalVersionAvailableText, @"Local content available")
                                                                            choiceButtonTitlesAndBlocks:NSLocalizedString(kLocalizationContentPickerComponentPreviewLocalVersionText, @"Preview local content"),
                                                  // Preview local content option
                                                  ^(UIAlertAction *action) {
                                                      weakSelf.currentSelectedDownloadResourceURL = downloadedContentURL;
                                                      [weakSelf previewDownloadedContent];
                                                  },
                                                  NSLocalizedString(kLocalizationContentPickerComponentGetLatestVersionText, @"Get latest version"),
                                                  // Get latest version from the server
                                                  ^(UIAlertAction *action) {
                                                      [weakSelf dowloadContent:content
                                                            allowCachedContent:NO];
                                                  }, nil];
                                                 
                                                 return;
                                             }
                                             
                                             if (downloadedContentURL &&
                                                 content) {
                                                 strongSelf.currentSelectedDownloadResourceURL = downloadedContentURL;
                                                 
                                                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                     weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationSuccessText, @"Success text");
                                                     weakSelf.progressHUD.detailTextLabel.text = nil;
                                                     
                                                     weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                                                     weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                                                 });
                                                 
                                                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                     [weakSelf.progressHUD dismiss];
                                                     
                                                     if ([weakSelf.delegate respondsToSelector:@selector(pickedContentHasFinishedDownloadingAtURL:)]) {
                                                         [weakSelf.delegate pickedContentHasFinishedDownloadingAtURL:downloadedContentURL];
                                                     }
                                                     
                                                     // Present the quick look controller
                                                     [weakSelf previewDownloadedContent];
                                                 });
                                             } else {
                                                 [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentDownloadErrorText, @"Content download error")];
                                             }
                                         } else {
                                             [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentDownloadErrorText, @"Content download error")];
                                         }
                                     }];
}

- (void)previewDownloadedContent {
    if (!self.previewController) {
        self.previewController =  [QLPreviewController new];
        self.previewController.dataSource = self;
        self.previewController.delegate = self;
    } else {
        [self.previewController refreshCurrentPreviewItem];
    }
    
    [self.navigationController presentViewController:self.previewController
                                            animated:YES
                                          completion:nil];
}

#pragma mark -
#pragma mark Image Picker Controller delegate methods

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // Check if we are picking from the photo library
    if (UIImagePickerControllerSourceTypePhotoLibrary == picker.sourceType) {
        PHAsset *selectedAsset = nil;
        PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[info[UIImagePickerControllerReferenceURL]]
                                                                 options:nil];
        if (fetchResult && fetchResult.count) {
            selectedAsset = [fetchResult lastObject];
        }
        
        if (selectedAsset) {
            CGRect cropRect = [info[UIImagePickerControllerCropRect] CGRectValue];
            NSInteger retinaScale = [UIScreen mainScreen].scale;
            CGSize retinaRect = CGSizeMake(cropRect.size.width * retinaScale, cropRect.size.height * retinaScale);
            
            PHImageRequestOptions *imageRequestOptions = [PHImageRequestOptions new];
            imageRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            imageRequestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
            
            UIImage *editedImage = info[UIImagePickerControllerEditedImage];
            
            __weak typeof(self) weakSelf = self;
            [[PHImageManager defaultManager] requestImageForAsset:selectedAsset
                                                       targetSize:retinaRect
                                                      contentMode:PHImageContentModeAspectFit
                                                          options:imageRequestOptions
                                                    resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                                                        __strong typeof(self) strongSelf = weakSelf;
                                                        
                                                        strongSelf.currentSelectedResourceData = UIImageJPEGRepresentation(editedImage, 1.0f);
                                                        
                                                        NSURL *assetFileURL = info[@"PHImageFileURLKey"];
                                                        // It is possible for some pictures present in the photo gallery that the URL will not be
                                                        // returned by the Photos framework and for those we generate it on-demand like for the
                                                        // camera captured photos
                                                        if (assetFileURL) {
                                                            strongSelf.currentSelectedUploadResourceURL = assetFileURL;
                                                        } else {
                                                            strongSelf.currentSelectedUploadResourceURL =
                                                            [NSURL URLWithString:
                                                             [ASDKDiskServices generateFilenameForFileWithMIMEType:
                                                              [ASDKDiskServices mimeTypeByGuessingFromData:self.currentSelectedResourceData]]];
                                                        }
                                                        
                                                        [strongSelf uploadTaskContentForCurrentSelectedResource];
                                                    }];
        }
        
        if ([self.delegate respondsToSelector:@selector(userPickedImageAtURL:)]) {
            [self.delegate userPickedImageAtURL:self.currentSelectedUploadResourceURL];
        }
    } else if (UIImagePickerControllerSourceTypeCamera == picker.sourceType) {
        UIImage *cameraImage = info[UIImagePickerControllerEditedImage];
        self.currentSelectedResourceData = UIImageJPEGRepresentation(cameraImage, 1.0f);
        self.currentSelectedUploadResourceURL = [NSURL URLWithString:
                                                 [ASDKDiskServices generateFilenameForFileWithMIMEType:
                                                  [ASDKDiskServices mimeTypeByGuessingFromData:self.currentSelectedResourceData]]];
        [self uploadTaskContentForCurrentSelectedResource];
        
        if ([self.delegate respondsToSelector:@selector(userPickedImageFromCamera)]) {
            [self.delegate userPickedImageFromCamera];
        }
    }
    
    [picker dismissViewControllerAnimated:YES
                               completion:nil];
    
    // Mark progress and start content upload
    [self showUploadProgressHUD];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if ([self.delegate respondsToSelector:@selector(userDidCancelImagePick)]) {
        [self.delegate userDidCancelImagePick];
    }
    
    [picker dismissViewControllerAnimated:YES
                               completion:nil];
}


#pragma mark -
#pragma mark Service integration

- (void)fetchIntegrationAccounts {
    __weak typeof(self) weakSelf = self;
    AFAIntegrationServices *integrationServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:(AFAServiceObjectTypeIntegrationServices)];
    [integrationServices requestIntegrationAccountsWithCompletionBlock:^(NSArray *accounts, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            // Filter out all but the Alfresco cloud services - development in progress
            NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"serviceID == %@", kASDKAPIServiceIDAlfrescoCloud];
            NSArray *filtereAccountsdArr = [accounts filteredArrayUsingPredicate:searchPredicate];
            strongSelf.integrationAccounts = filtereAccountsdArr;
            
            if ([strongSelf.delegate respondsToSelector:@selector(contentPickerHasBeenPresentedWithNumberOfOptions:cellHeight:)]) {
                [strongSelf.delegate contentPickerHasBeenPresentedWithNumberOfOptions:AFAContentPickerCellTypeEnumCount + filtereAccountsdArr.count
                                                                           cellHeight:strongSelf.actionsTableView.rowHeight];
            }
            
            [strongSelf.actionsTableView reloadData];
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationContentPickerComponentIntegrationAccountNotAvailableText, @"Integration account error")];
        }
    }];
}

- (void)uploadTaskContentForCurrentSelectedResource {
    __weak typeof(self) weakSelf = self;
    AFATaskServicesTaskContentUploadCompletionBlock uploadCompletionBlock = ^(BOOL isContentUploaded, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (isContentUploaded) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                weakSelf.progressHUD.textLabel.text = NSLocalizedString(kLocalizationSuccessText, @"Success text");
                weakSelf.progressHUD.detailTextLabel.text = nil;
                
                weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
            });
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.progressHUD dismiss];
                
                if ([weakSelf.delegate respondsToSelector:@selector(pickedContentHasFinishedUploading)]) {
                    [weakSelf.delegate pickedContentHasFinishedUploading];
                }
            });
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentUploadErrorText, @"Content upload error")];
            [strongSelf.progressHUD dismiss];
        }
    };
    
    AFATaskServiceTaskContentProgressBlock progressBlock = ^(NSUInteger progress, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            [strongSelf.progressHUD setProgress:progress / 100.0f
                                       animated:YES];
            strongSelf.progressHUD.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(kLocalizationContentPickerComponentProgressPercentFormat, @"Percent format"), progress];
        } else {
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationAlertDialogTaskContentUploadErrorText, @"Content upload error")];
        }
    };
    
    switch (self.pickerType) {
        case AFAContentPickerViewControllerTypeTaskRelated: {
            AFATaskServices *taskService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeTaskServices];
            
            [taskService requestContentUploadAtFileURL:self.currentSelectedUploadResourceURL
                                       withContentData:self.currentSelectedResourceData
                                             forTaskID:self.taskID
                                     withProgressBlock:progressBlock
                                       completionBlock:uploadCompletionBlock];
        }
            break;
            
        case AFAContentPickerViewControllerTypeProfileRelated: {
            AFAProfileServices *profileService = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProfileServices];
            
            [profileService requestUploadProfileImageAtFileURL:self.currentSelectedUploadResourceURL
                                                   contentData:self.currentSelectedResourceData
                                                 progressBlock:progressBlock
                                               completionBlock:uploadCompletionBlock];
        }
            break;
            
        default:
            break;
    }
}


#pragma mark -
#pragma mark - Progress hud setup

- (void)showUploadProgressHUD {
    self.progressHUD.textLabel.text = NSLocalizedString(kLocalizationContentPickerComponentUploadingText, @"Uploading text");
    self.progressHUD.indicatorView = [[JGProgressHUDPieIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [self.progressHUD showInView:self.navigationController.view];
}

- (void)showDownloadProgressHUD {
    self.progressHUD.textLabel.text = NSLocalizedString(kLocalizationContentPickerComponentDownloadingText, @"Downloading text");
    self.progressHUD.indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [self.progressHUD showInView:self.navigationController.view];
}

- (void)showIntegrationLoginHUD {
    self.progressHUD.textLabel.text = NSLocalizedString(kLocalizationContentPickerComponentIntegrationLoginSuccessfullText, @"Logged in successfully text");
    self.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
    self.progressHUD.detailTextLabel.text = nil;
    [self.progressHUD showInView:self.navigationController.view];
}

- (JGProgressHUD *)configureProgressHUD {
    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
    JGProgressHUDFadeZoomAnimation *zoomAnimation = [JGProgressHUDFadeZoomAnimation animation];
    hud.animation = zoomAnimation;
    hud.layoutChangeAnimationDuration = .0f;
    
    hud.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(kLocalizationContentPickerComponentProgressPercentFormat, @"Percent format"), 0];
    
    return hud;
}


#pragma mark -
#pragma mark QLPreviewController Delegate & Datasource

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return 1;
}

- (id<QLPreviewItem> _Nonnull)previewController:(QLPreviewController * _Nonnull)controller
                             previewItemAtIndex:(NSInteger)index {
    return self.currentSelectedDownloadResourceURL;
}

#pragma mark -
#pragma mark Tableview Delegate & Datasource

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
            
            if ([kASDKAPIServiceIDAlfrescoCloud isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"alfresco-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentAlfrescoContentText, @"Alfresco cloud text");
            } else if ([kASDKAPIServiceIDBox isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"box-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentBoxContentText, @"Box text");
            } else if ([kASDKAPIServiceIDGoogleDrive isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"drive-icon"];
                taskCell.actionDescriptionLabel.text = NSLocalizedString(kLocalizationContentPickerComponentDriveContentText, @"Google drive text");
            }
        }
            break;
    }
    
    return taskCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    
    switch (indexPath.row) {
        case AFAContentPickerCellTypeLocalContent: {
            [self onSelectPhoto];
        }
            break;
            
        case AFAContentPickerCellTypeCamera: {
            if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                [self showGenericErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationContentPickerComponentCameraNotAvailableErrorText, @"Camera not available error text")];
            } else {
                [self onTakePhoto];
            }
        }
            break;
            
        default: { // Handle integration services cell behaviour
            ASDKModelIntegrationAccount *account = self.integrationAccounts[indexPath.row - AFAContentPickerCellTypeEnumCount];
            
            if (!account.authorized) {
                __weak typeof(self) weakSelf = self;
                self.integrationLoginController =
                [[ASDKIntegrationLoginWebViewViewController alloc] initWithAuthorizationURL:account.authorizationURL
                                                                            completionBlock:^(BOOL isAuthorized) {
                                                                                if (isAuthorized) {
                                                                                    __strong typeof(self) strongSelf = weakSelf;
                                                                                    [self fetchIntegrationAccounts];
                                                                                    [strongSelf showIntegrationLoginHUD];
                                                                                    
                                                                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                        [weakSelf.progressHUD dismiss];
                                                                                        
                                                                                        if ([strongSelf.delegate respondsToSelector:@selector(userPickerIntegrationAccount:)]) {
                                                                                            [strongSelf.delegate userPickerIntegrationAccount:account];
                                                                                        }
                                                                                    });
                                                                                } else {
                                                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                                                        [self showGenericErrorAlertControllerWithMessage:NSLocalizedString(kLocalizationContentPickerComponentIntegrationLoginErrorText,  @"Cannot author integration service")];
                                                                                    });
                                                                                }
                                                                            }];
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.integrationLoginController];
                
                [self presentViewController:navigationController
                                   animated:YES
                                 completion:nil];
            } else {
                if ([self.delegate respondsToSelector:@selector(userPickerIntegrationAccount:)]) {
                    [self.delegate userPickerIntegrationAccount:account];
                }
            }
        }
            break;
    }
}

@end
