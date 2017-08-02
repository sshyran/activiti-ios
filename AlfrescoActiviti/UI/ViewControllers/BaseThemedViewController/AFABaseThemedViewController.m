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

#import "AFABaseThemedViewController.h"

// Constants
#import "AFAUIConstants.h"
#import "AFALocalizationConstants.h"

// Managers
@import ActivitiSDK;

@interface AFABaseThemedViewController ()

@property (strong, nonatomic) id                                reachabilityChangeObserver;
@property (strong, nonatomic) AFANavigationBarBannerAlertView   *bannerAlertView;
@property (assign, nonatomic) BOOL                              isControllerViewVisible;

@end

@implementation AFABaseThemedViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        __weak typeof(self) weakSelf = self;
        _reachabilityChangeObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceNoInternetConnection
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                          __strong typeof(self) strongSelf = weakSelf;
                                                          
                                                          if (strongSelf.isControllerViewVisible) {
                                                              [self didLoseNetworkConnectivity];
                                                          }
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceInternetConnectionAvailable
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                          __strong typeof(self) strongSelf = weakSelf;
                                                          
                                                          if (strongSelf.isControllerViewVisible) {
                                                              [strongSelf showWarningMessage:NSLocalizedString(kLocalizationOfflineConnectivityRetryText, @"Reconnect text")];
                                                              [strongSelf didRestoredNetworkConnectivity];
                                                          }
                                                      }];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityChangeObserver];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _bannerAlertView = [[AFANavigationBarBannerAlertView alloc] initWithParentViewController:self];
}

- (void)viewDidAppear:(BOOL)animated {
    self.isControllerViewVisible = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    self.isControllerViewVisible = NO;
}


#pragma mark -
#pragma mark Setters

- (void)setNavigationBarTitle:(NSString *)navigationBarTitle {
    if (![_navigationBarTitle isEqualToString:navigationBarTitle]) {
        _navigationBarTitle = navigationBarTitle;
        
        // Update navigation bar title
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = _navigationBarTitle;
        titleLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                          size:17];
        titleLabel.textColor = [UIColor whiteColor];
        [titleLabel sizeToFit];
        self.navigationItem.titleView = titleLabel;
    }
}

- (void)setNavigationBarThemeColor:(UIColor *)navigationBarThemeColor {
    if (_navigationBarThemeColor != navigationBarThemeColor) {
        _navigationBarThemeColor = navigationBarThemeColor;
        
        // Make the color change an animated transition
        [self.navigationController.navigationBar.layer addAnimation:[self fadeTransitionWithDuration:kOverlayAlphaChangeTime]
                                                             forKey:nil];
        [self.navigationController.navigationBar setBarTintColor:_navigationBarThemeColor];
        [self.navigationController.navigationBar setTranslucent:NO];
    }
}

- (CATransition *)fadeTransitionWithDuration:(CGFloat)duration {
    CATransition *transition = [CATransition animation];
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionFade;
    transition.duration = duration;
    return transition;
}


#pragma mark -
#pragma mark Public interface

- (void)showWarningMessage:(NSString *)warningMessage {
    [self.bannerAlertView showAndHideWithText:warningMessage
                                        style:AFABannerAlertStyleWarning];
}

- (void)showErrorMessage:(NSString *)errorMessage {
    [self.bannerAlertView showAndHideWithText:errorMessage
                                        style:AFABannerAlertStyleError];
}

- (void)showConfirmationMessage:(NSString *)confirmationMessage {
    [self.bannerAlertView showAndHideWithText:confirmationMessage
                                        style:AFABannerAlertStyleSuccess];
}

- (void)didRestoredNetworkConnectivity {
    [self showConfirmationMessage:NSLocalizedString(kLocalizationOfflineConnectivityConnectedRefreshingText, @"Reconect text")];
}

- (void)didLoseNetworkConnectivity {
    // Override in child classes
}

@end
