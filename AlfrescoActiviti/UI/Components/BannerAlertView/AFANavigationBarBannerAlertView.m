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

#import "AFANavigationBarBannerAlertView.h"
#import "UIColor+AFATheme.h"
#import "AFAUIConstants.h"

static const CGFloat kTopMargin = 10.f;
static const NSTimeInterval kHideTimeout = 2.f;

@interface AFANavigationBarBannerAlertView()

@property (strong, nonatomic) UILabel               *alertTextLabel;
@property (strong, nonatomic) NSLayoutConstraint    *topSpacingConstraint;
@property (weak, nonatomic) UIViewController        *parentViewController;
@property (strong, nonatomic) NSTimer               *hideTimer;

@end

@implementation AFANavigationBarBannerAlertView

- (instancetype)initWithFrame:(CGRect)frame
                    alertText:(NSString *)alertText
                   alertStyle:(AFABannerAlertStyle)alertStyle
         parentViewController:(UIViewController *)parentViewController {
    self = [super initWithFrame:frame];
    if (self) {
        _alertText = alertText;
        _alertStyle = alertStyle;
        _parentViewController = parentViewController;
        
        [self setUpBannerComponents];
    }
    return self;
}

+ (instancetype)showAlertWithText:(NSString *)alertText
                            style:(AFABannerAlertStyle)alertStyle
                 inViewController:(UIViewController *)viewController {
    AFANavigationBarBannerAlertView *bannerAlert = [[AFANavigationBarBannerAlertView alloc] initWithFrame:CGRectZero
                                                                                                alertText:alertText
                                                                                               alertStyle:alertStyle
                                                                                     parentViewController:viewController];
    [bannerAlert showAndHideWithTimeout:kHideTimeout];
    
    return bannerAlert;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.alertTextLabel.preferredMaxLayoutWidth = CGRectGetWidth(self.alertTextLabel.frame);
}

- (void)updateConstraints {
    [super updateConstraints];
    
    UINavigationBar *navigationBar = self.parentViewController.navigationController.navigationBar;
    self.topSpacingConstraint.constant = CGRectGetMaxY(navigationBar.frame);
    
    if (!self.isBannerVisible) {
        self.topSpacingConstraint.constant += -self.frame.size.height;
    }
}

- (void)setUpBannerComponents {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Set up alert label
    self.alertTextLabel = [[UILabel alloc] init];
    self.alertTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.alertTextLabel.numberOfLines = 0;
    self.alertTextLabel.textAlignment = NSTextAlignmentCenter;
    self.alertTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.alertTextLabel.backgroundColor = [UIColor clearColor];
    self.alertTextLabel.text = self.alertText;
    self.alertTextLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                               size:14.0f];
    [self addSubview:self.alertTextLabel];
    
    // Set up background and text color based on the style of the alert
    UIColor *backgroundColor = nil;
    UIColor *alertTextColor = nil;
    
    if (AFABannerAlertStyleWarning == self.alertStyle) {
        backgroundColor = [UIColor yellowColor];
        alertTextColor = [UIColor darkGreyTextColor];
    } else if (AFABannerAlertStyleError == self.alertStyle) {
        backgroundColor = [UIColor redColor];
        alertTextColor = [UIColor whiteColor];
    }
    
    self.backgroundColor = backgroundColor;
    self.alertTextLabel.textColor = alertTextColor;
    
    // Configure alert label constraints
    NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[alertLabel]-|"
                                                                             options:kNilOptions
                                                                             metrics:nil
                                                                               views:@{@"alertLabel" : self.alertTextLabel}];
    
    NSArray *verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(top)-[alertLabel]-(bottom)-|"
                                                                           options:kNilOptions
                                                                           metrics:@{@"top"         : @(kTopMargin),
                                                                                     @"bottom"      : @(kTopMargin),}
                                                                             views:@{@"alertLabel"  : self.alertTextLabel}];
    [self addConstraints:horizontalConstraints];
    [self addConstraints:verticalConstraints];
}

- (void)updateUI {
    [self updateConstraintsIfNeeded];
    [self layoutIfNeeded];
    
    [self setNeedsUpdateConstraints];
}

- (void)show {
    _isBannerVisible = YES;
    
    UINavigationBar *navigationBar = self.parentViewController.navigationController.navigationBar;
    [navigationBar.superview insertSubview:self
                              belowSubview:navigationBar];
    
    CGFloat topOffset = CGRectGetMaxY(navigationBar.frame);
    NSArray *horizontalConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[banner]|"
                                                                             options:0
                                                                             metrics:nil
                                                                               views:@{@"banner": self}];
    NSArray *topConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(offset)-[banner]"
                                                                      options:0
                                                                      metrics:@{@"offset": @(topOffset)}
                                                                        views:@{@"banner": self}];
    self.topSpacingConstraint = topConstraints.firstObject;
    
    [self.superview addConstraints:horizontalConstraints];
    [self.superview addConstraints:topConstraints];
    
    [self updateUI];
    
    self.transform = CGAffineTransformMakeTranslation(0, -self.frame.size.height);
    [UIView animateWithDuration:kDefaultAnimationTime
                     animations:^{
                         self.transform = CGAffineTransformIdentity;
                     }];
}

- (void)hide {
    if (self.hideTimer) {
        [self.hideTimer invalidate];
        self.hideTimer = nil;
    }
    
    _isBannerVisible = NO;
    
    [self updateUI];
    
    self.transform = CGAffineTransformMakeTranslation(0, self.frame.size.height);
    [UIView animateWithDuration:kDefaultAnimationTime animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)showAndHideWithTimeout:(NSTimeInterval)timeout {
    [self show];
    
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                      target:self
                                                    selector:@selector(hide)
                                                    userInfo:nil
                                                     repeats:NO];
}

@end
