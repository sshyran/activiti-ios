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

#import "ASDKAttachFormFieldContentPickerViewController.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLocalizationConstants.h"
#import "ASDKLogConfiguration.h"
#import "ASDKNetworkServiceConstants.h"

// Categories
#import "UIViewController+ASDKAlertAddition.h"

// Models
#import "ASDKModelContent.h"
#import "ASDKModelFileContent.h"
#import "ASDKModelFormFieldAttachParameter.h"
#import "ASDKModelIntegrationAccount.h"

// Cells
#import "ASDKAddContentTableViewCell.h"

// Views
#import <JGProgressHUD/JGProgressHUD.h>

// View controllers
#import "ASDKAttachFormFieldDetailsViewController.h"
#import "ASDKIntegrationLoginWebViewViewController.h"

// Managers
#import "ASDKBootstrap.h"
#import "ASDKIntegrationNetworkServices.h"
#import "ASDKFormNetworkServices.h"
#import "ASDKServiceLocator.h"
@import Photos;
@import QuickLook;

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

typedef NS_ENUM(NSInteger, ASDKAttachFormFieldDetailsCellType) {
    ASDKAttachFormFieldDetailsCellTypeLocalContent = 0,
    ASDKAttachFormFieldDetailsCellTypeCamera,
    ASDKAttachFormFieldDetailsCellTypeEnumCount
};

@interface ASDKAttachFormFieldContentPickerViewController () <UINavigationControllerDelegate,
                                                              UIImagePickerControllerDelegate,
                                                              QLPreviewControllerDataSource,
                                                              QLPreviewControllerDelegate>

@property (weak, nonatomic)   IBOutlet UITableView                          *actionsTableView;
@property (strong, nonatomic) JGProgressHUD                                 *progressHUD;
@property (strong, nonatomic) UIImagePickerController                       *imagePickerController;
@property (strong, nonatomic) QLPreviewController                           *previewController;
@property (strong, nonatomic) ASDKIntegrationLoginWebViewViewController     *integrationLoginController;

// Internal state properties
@property (strong, nonatomic) NSURL                                         *currentSelectedUploadResourceURL;
@property (strong, nonatomic) NSURL                                         *currentSelectedDownloadResourceURL;
@property (strong, nonatomic) NSData                                        *currentSelectedResourceData;
@property (strong, nonatomic) NSArray                                       *integrationAccounts;

@end

@implementation ASDKAttachFormFieldContentPickerViewController

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
    
    __weak typeof(self) weakSelf = self;
    [self requestFormFieldContentDownloadForContent:content
                                 allowCachedResults:allowCachedContent
                                  withProgressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                      __strong typeof(self) strongSelf = weakSelf;
                                      
                                      if (!error) {
                                          strongSelf.progressHUD.detailTextLabel.text = [NSString stringWithFormat:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentDownloadProgressFormat, ASDKLocalizationTable, @"Download progress format"), formattedReceivedBytesString];
                                      } else {
                                          [strongSelf.progressHUD dismiss];
                                          [strongSelf showGenericNetworkErrorAlertControllerWithMessage:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentFailedText, ASDKLocalizationTable, @"Content download error")];
                                      }
                                  } withCompletionBlock:^(NSString *contentID, NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                      __strong typeof(self) strongSelf = weakSelf;
                                      
                                      if (!error) {
                                          
                                          // If local content is available ask the user how he would like to preview it
                                          if (isLocalContent) {
                                              
                                              [strongSelf.progressHUD dismiss];

                                              // if local content is uploaded then do not show modal
                                              if ([strongSelf.uploadedContentIDs containsObject:contentID]) {
                                                  weakSelf.currentSelectedDownloadResourceURL = downloadedContentURL;
                                                  [weakSelf previewDownloadedContent];
                                              } else {
                                                  [strongSelf showMultipleChoiceAlertControllerWithTitle:nil
                                                                                                 message:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentLocalVersionAvailableText, ASDKLocalizationTable, @"Local content available")
                                                                             choiceButtonTitlesAndBlocks:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentPreviewLocalVersionText, ASDKLocalizationTable, @"Preview local content"),
                                                   // Preview local content option
                                                   ^(UIAlertAction *action) {
                                                       weakSelf.currentSelectedDownloadResourceURL = downloadedContentURL;
                                                       [weakSelf previewDownloadedContent];
                                                   },
                                                   ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentGetLatestVersionText, ASDKLocalizationTable, @"Get latest version"),
                                                   // Get latest version from the server
                                                   ^(UIAlertAction *action) {
                                                       [weakSelf dowloadContent:content
                                                             allowCachedContent:NO];
                                                   }, nil];
                                              }
                                              
                                              return;
                                          }
                                          
                                          if (downloadedContentURL &&
                                              content) {
                                              strongSelf.currentSelectedDownloadResourceURL = downloadedContentURL;
                                              
                                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                  weakSelf.progressHUD.textLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentSuccessText, ASDKLocalizationTable,  @"Success text");
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
                                              [strongSelf showGenericNetworkErrorAlertControllerWithMessage:@"Content download error"];
                                          }
                                      } else {
                                          [strongSelf.progressHUD dismiss];
                                          [strongSelf showGenericNetworkErrorAlertControllerWithMessage:@"Content download error"];
                                      }
                                  }];
    
}

- (void)requestFormFieldContentDownloadForContent:(ASDKModelContent *)content
                          allowCachedResults:(BOOL)allowCachedResults
                           withProgressBlock:(ASDKFormFieldContentDownloadProgressBlock)progressBlock
                         withCompletionBlock:(ASDKFormFieldContentDownloadCompletionBlock)completionBlock {
   
    NSParameterAssert(content);
    NSParameterAssert(completionBlock);
    
    // Acquire and set up the app network service
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    ASDKFormNetworkServices *formNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormNetworkServiceProtocol)];
    
    [formNetworkService downloadContentWithModel:content
                              allowCachedResults:allowCachedResults
                                   progressBlock:^(NSString *formattedReceivedBytesString, NSError *error) {
                                       ASDKLogVerbose(@"Downloaded %@ of content for task with ID:%@ ", formattedReceivedBytesString, content.instanceID);
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           progressBlock (formattedReceivedBytesString, error);
                                       });
                                   } completionBlock:^(NSString *contentID, NSURL *downloadedContentURL, BOOL isLocalContent, NSError *error) {
                                       if (!error && downloadedContentURL) {
                                           ASDKLogVerbose(@"Content with ID:%@ was downloaded successfully.", content.instanceID);
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completionBlock(contentID, downloadedContentURL, isLocalContent, nil);
                                           });
                                       } else {
                                           ASDKLogError(@"An error occured while downloading content with ID:%@. Reason:%@", content.instanceID, error.localizedDescription);
                                           
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completionBlock(nil, nil, NO, error);
                                           });
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
                                                        
                                                        [strongSelf uploadFormFieldContentForCurrentSelectedResource];
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
        [self uploadFormFieldContentForCurrentSelectedResource];
        
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
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    ASDKIntegrationNetworkServices *integrationNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKIntegrationNetworkServiceProtocol)];
    
    
    __weak typeof(self) weakSelf = self;
    [integrationNetworkService fetchIntegrationAccountsWithCompletionBlock:^(NSArray *accounts, NSError *error, ASDKModelPaging *paging) {
        __strong typeof(self) strongSelf = weakSelf;
        
        if (!error) {
            ASDKLogVerbose(@"Successfully fetched the integration account list:%@.", accounts);
            strongSelf.integrationAccounts = accounts;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(contentPickerHasBeenPresentedWithNumberOfOptions:cellHeight:)]) {
                    [self.delegate contentPickerHasBeenPresentedWithNumberOfOptions:ASDKAttachFormFieldDetailsCellTypeEnumCount + accounts.count
                                                                         cellHeight:self.actionsTableView.rowHeight];
                }
                
                [weakSelf.actionsTableView reloadData];
            });
        } else {
            ASDKLogError(@"An error occured while fetching the integration account list. Reason:%@", error.localizedDescription);
            [strongSelf showGenericNetworkErrorAlertControllerWithMessage:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentFailedText, ASDKLocalizationTable, @"Failed title")];
        }
    }];
}

- (void)uploadFormFieldContentForCurrentSelectedResource {
    
    // Acquire and set up the app network service
    ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
    ASDKFormNetworkServices *formNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormNetworkServiceProtocol)];
    
    ASDKModelFileContent *fileContentModel = [ASDKModelFileContent new];
    fileContentModel.fileURL = self.currentSelectedUploadResourceURL;
    
    __weak typeof(self) weakSelf = self;
    [formNetworkService uploadContentWithModel:fileContentModel
                                        contentData:self.currentSelectedResourceData
                                      progressBlock:^(NSUInteger progress, NSError *error) {
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              [weakSelf.progressHUD setProgress:progress / 100.0f
                                                                         animated:YES];
                                              weakSelf.progressHUD.detailTextLabel.text = [NSString stringWithFormat:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentProgressPercentageFormat, ASDKLocalizationTable, @"Percent format"), progress];
                                          });
                                      } completionBlock:^(ASDKModelContent *modelContent, NSError *error) {
                                          __strong typeof(self) strongSelf = weakSelf;

                                          BOOL didContentUploadSucceeded = modelContent.isContentAvailable && !error;
                                          
                                          if (didContentUploadSucceeded) {
                                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                  weakSelf.progressHUD.textLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentSuccessText, ASDKLocalizationTable,  @"Success text");
                                                  weakSelf.progressHUD.detailTextLabel.text = nil;
                                                  
                                                  weakSelf.progressHUD.layoutChangeAnimationDuration = 0.3;
                                                  weakSelf.progressHUD.indicatorView = [[JGProgressHUDSuccessIndicatorView alloc] init];
                                              });
                                              
                                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                  [weakSelf.progressHUD dismiss];
                                                  
                                                  // add content to attach field
                                                  //
                                                  // if multiple files allowed -> add
                                                  // otherwise -> replace
                                                  
                                                  ASDKModelFormFieldAttachParameter *formFieldParameters = (ASDKModelFormFieldAttachParameter *)self.currentFormField.formFieldParams;
                                                  NSMutableArray *currentValuesArray = [NSMutableArray arrayWithArray:self.currentFormField.values];
                                                  
                                                  if (formFieldParameters.allowMultipleFiles) {
                                                      currentValuesArray = [NSMutableArray arrayWithArray:self.currentFormField.values];
                                                  } else {
                                                      currentValuesArray = [[NSMutableArray alloc] init];
                                                  }
                                                  
                                                  [currentValuesArray addObject:modelContent];
                                                  self.currentFormField.values = [currentValuesArray copy];
                                                  
                                                  // store uploaded content id
                                                  // used for automatic selection local storage version in stead of remote version
                                                  [self.uploadedContentIDs addObject:modelContent.instanceID];
                                                  
                                                  if ([weakSelf.delegate respondsToSelector:@selector(pickedContentHasFinishedUploading)]) {
                                                      [weakSelf.delegate pickedContentHasFinishedUploading];
                                                  }
                                              });
                                          } else {
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  [strongSelf showGenericNetworkErrorAlertControllerWithMessage:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentFailedText, ASDKLocalizationTable, @"Failed title")];
                                                  [strongSelf.progressHUD dismiss];
                                              });
                                          }
                                      }];
}


#pragma mark -
#pragma mark - Progress hud setup

- (void)showUploadProgressHUD {
    self.progressHUD.textLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentUploadingText, ASDKLocalizationTable, @"Uploading text");
    self.progressHUD.indicatorView = [[JGProgressHUDPieIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [self.progressHUD showInView:self.navigationController.view];
}

- (void)showDownloadProgressHUD {
    self.progressHUD.textLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentDownloadingText, ASDKLocalizationTable, @"Downloading text");
    self.progressHUD.indicatorView = [[JGProgressHUDIndeterminateIndicatorView alloc] initWithHUDStyle:self.progressHUD.style];
    [self.progressHUD showInView:self.navigationController.view];
}

- (JGProgressHUD *)configureProgressHUD {
    JGProgressHUD *hud = [[JGProgressHUD alloc] initWithStyle:JGProgressHUDStyleDark];
    hud.interactionType = JGProgressHUDInteractionTypeBlockAllTouches;
    JGProgressHUDFadeZoomAnimation *zoomAnimation = [JGProgressHUDFadeZoomAnimation animation];
    hud.animation = zoomAnimation;
    hud.layoutChangeAnimationDuration = .0f;
    
    hud.detailTextLabel.text = [NSString stringWithFormat:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentProgressPercentageFormat, ASDKLocalizationTable, @"Percent format"), 0];
    
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
    return ASDKAttachFormFieldDetailsCellTypeEnumCount + self.integrationAccounts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ASDKAddContentTableViewCell *taskCell = [tableView dequeueReusableCellWithIdentifier:kASDKCellIDFormFieldAttachAddContent
                                                                            forIndexPath:indexPath];
    
    switch (indexPath.row) {
        case ASDKAttachFormFieldDetailsCellTypeLocalContent: {
            taskCell.iconImageView.image = [UIImage imageNamed:@"phone-icon"];
            taskCell.actionDescriptionLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentLocalContentText, ASDKLocalizationTable, @"Local content text");
        }
            break;
            
        case ASDKAttachFormFieldDetailsCellTypeCamera: {
            taskCell.iconImageView.image = [UIImage imageNamed:@"camera-icon"];
            taskCell.actionDescriptionLabel.text =  ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentCameraContentText, ASDKLocalizationTable,@"Camera content text");
        }
            break;
            
        default: { // Handle the integration cells
            ASDKModelIntegrationAccount *account = self.integrationAccounts[indexPath.row - ASDKAttachFormFieldDetailsCellTypeEnumCount];
            NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
            
            if ([kASDKAPIServiceIDAlfrescoCloud isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"alfrescobw-icon"
                                                          inBundle:frameWorkBundle
                                     compatibleWithTraitCollection:nil];
                taskCell.actionDescriptionLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentAlfrescoContentText, ASDKLocalizationTable, @"Alfresco cloud text");
            } else if ([kASDKAPIServiceIDBox isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"box-icon"
                                                          inBundle:frameWorkBundle
                                     compatibleWithTraitCollection:nil];
                taskCell.actionDescriptionLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentBoxContentText, ASDKLocalizationTable, @"Box text");
            } else if ([kASDKAPIServiceIDGoogleDrive isEqualToString:account.serviceID]) {
                taskCell.iconImageView.image = [UIImage imageNamed:@"drive-icon"
                                                          inBundle:frameWorkBundle
                                     compatibleWithTraitCollection:nil];
                taskCell.actionDescriptionLabel.text = ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentDriveText, ASDKLocalizationTable, @"Google drive text");
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
        case ASDKAttachFormFieldDetailsCellTypeLocalContent: {
            [self onSelectPhoto];
        }
            break;
            
        case ASDKAttachFormFieldDetailsCellTypeCamera: {
            if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                [self showGenericErrorAlertControllerWithMessage:ASDKLocalizedStringFromTable(kLocalizationFormContentPickerComponentCameraNotAvailableErrorText, ASDKLocalizationTable,  @"Camera not available error text")];
            } else {
                [self onTakePhoto];
            }
        }
            break;
            
        default: { // Handle integration services cell behaviour
            ASDKModelIntegrationAccount *account = self.integrationAccounts[indexPath.row - ASDKAttachFormFieldDetailsCellTypeEnumCount];
            
            if (!account.authorized) {
                self.integrationLoginController =
                [[ASDKIntegrationLoginWebViewViewController alloc] initWithAuthorizationURL:account.authorizationURL
                                                                            completionBlock:^(BOOL isAuthorized, NSString *code) {
                }];
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:self.integrationLoginController];
                
                [self presentViewController:navigationController
                                   animated:YES
                                 completion:nil];
            }
        }
            break;
    }
}

@end