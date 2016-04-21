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

#import "AFALoginViewController.h"
#import "UIView+AFAViewAnimations.h"
#import "AFAUIConstants.h"
#import "AFABusinessConstants.h"
#import "AFACredentialsPageViewController.h"
#import "AFALoginModel.h"
#import "AFAActivityView.h"
#import "AFAModalReplaceSegueUnwind.h"
#import "AFAKeychainWrapper.h"
#import "AFALogConfiguration.h"
#import "AFAContainerViewController.h"
@import ActivitiSDK;

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFALoginViewController ()

// Views
@property (weak, nonatomic) IBOutlet UIView                     *effectViewContainer;
@property (weak, nonatomic) IBOutlet UIImageView                *activitiLogoImageView;
@property (weak, nonatomic) IBOutlet UIView                     *serverButtonsContainerView;
@property (weak, nonatomic) IBOutlet UIView                     *roundedViewsContainer;
@property (weak, nonatomic) IBOutlet UIView                     *embeddedViewContainer;
@property (weak, nonatomic) IBOutlet UIToolbar                  *buttonToolbar;
@property (weak, nonatomic) IBOutlet AFAActivityView            *activityView;

// Constraints
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *activitiLogoCenterConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *activitiLogoCenterPaddedConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *activitiLogoTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *activitiLogoPaddedTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *roundedViewsCenterConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *serverButtonsCenterConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *roundedViewsPaddedConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *serverButtonsPaddedConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *containerViewTopAlignment;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint         *containerViewCenterConstraint;

// Controllers
@property (strong, nonatomic) AFACredentialsPageViewController  *credentialsPageViewController;

// Models
@property (strong, nonatomic) AFALoginModel                     *loginModel;

// KVO
@property (strong, nonatomic) ASDKKVOManager                     *kvoManager;

@end

@implementation AFALoginViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.loginModel = [AFALoginModel new];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.activitiLogoCenterConstraint.active = NO;
    self.activitiLogoCenterPaddedConstraint.active = YES;
    
    // Check if we have registered credentials and if so login the user
    // without showing the menu
    [self.loginModel updateUserNameEntry:[AFAKeychainWrapper keychainStringFromMatchingIdentifier:kUsernameCredentialIdentifier]];
    [self.loginModel updatePasswordEntry:[AFAKeychainWrapper keychainStringFromMatchingIdentifier:kPasswordCredentialIdentifier]];
    [self.loginModel updateHostNameEntry:[AFAKeychainWrapper keychainStringFromMatchingIdentifier:kHostNameCredentialIdentifier]];
    [self.loginModel updateCommunicationOverSecureLayer:[[AFAKeychainWrapper keychainStringFromMatchingIdentifier:kSecureLayerCredentialIdentifier] isEqualToString:kBooleanTrueCredentialIdentifier] ? YES : NO];
    
    if ([self.loginModel canUserSignIn]) {
        [self.loginModel requestLoginWithCompletionBlock:^(BOOL isLoggedIn, NSError *error) {
            BOOL displayEnvironmentMenu = NO;
            if (!error) {
                if (!isLoggedIn) {
                    // Credentials might have expired or have been changed
                    // Display the environment menu options
                    displayEnvironmentMenu = YES;
                }
            } else {
                displayEnvironmentMenu = YES;
                AFALogVerbose(@"Failed to auto login with Keychain credentials. Reason:%@", error.localizedDescription);
            }
            
            
            if (displayEnvironmentMenu) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView animateViewsFromArray:@[self.roundedViewsContainer, self.serverButtonsContainerView]
                                        withAlpha:1.0f
                                     withDuration:kLoginScreenServerButtonsFadeInTime
                              withCompletionBlock:nil];
                });
            }
        }];
        
    } else { // Show the enviroment menu options
        [UIView animateViewsFromArray:@[self.roundedViewsContainer, self.serverButtonsContainerView]
                            withAlpha:1.0f
                         withDuration:kLoginScreenServerButtonsFadeInTime
                  withCompletionBlock:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark -
#pragma mark Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender {
    // Get a hold of the reference for the embedded page view controller
    if ([kStoryboardIDEmbeddedCredentialsPageController isEqualToString:segue.identifier]) {
        self.credentialsPageViewController = segue.destinationViewController;
        self.credentialsPageViewController.loginModel = self.loginModel;
        [self handleBindingsForLoginViewController];
    }
    
    if ([kSegueIDLoginAuthorized isEqualToString:segue.identifier]) {
        AFAContainerViewController *containerViewController = segue.destinationViewController;
        containerViewController.loginModel = self.loginModel;
    }
}

- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    if ([kSegueIDLoginAuthorizedUnwind isEqualToString:identifier]) {
        AFAModalReplaceSegueUnwind *unwindSegue = [AFAModalReplaceSegueUnwind segueWithIdentifier:identifier
                                                                                           source:fromViewController
                                                                                      destination:toViewController
                                                                                   performHandler:^{}];
        return unwindSegue;
    }
    
    return [super segueForUnwindingToViewController:toViewController
                                 fromViewController:fromViewController
                                         identifier:identifier];
}

- (IBAction)unwindToLoginController:(UIStoryboardSegue *)segue {
    
}


#pragma mark -
#pragma mark Actions

- (IBAction)onActivitiCloud:(id)sender {
    [self performCredentialPageAnimationInReverse:NO
                                  completionBlock:^(BOOL finished) {
        [self.credentialsPageViewController showCloudLoginCredentials];
    }];
}

- (IBAction)onActivitiPremise:(id)sender {
    [self performCredentialPageAnimationInReverse:NO
                                  completionBlock:^(BOOL finished) {
        [self.credentialsPageViewController showPremiseLoginCredentials];
    }];
}

- (IBAction)onEnvironment:(id)sender {
    // Cancel possible ongoing login request
    [self.loginModel cancelLoginRequest];
    [self showEnvironmentPageAnimation];
}


#pragma mark -
#pragma mark Animations

- (void)performLogoShrinkAndCredentialsPaddingAnimationInReverse:(BOOL)isReverseAnimation {
    // Animate activiti logo from center position to the first quarter
    // of the upper part adjusting also it's size
    if (!isReverseAnimation) {
        self.activitiLogoCenterPaddedConstraint.active = NO;
        self.activitiLogoPaddedTopConstraint.active = YES;
        self.activitiLogoTopConstraint.active = YES;
        
        // Animate the embedded container view center Y position and lift it
        self.containerViewTopAlignment.active = NO;
        self.containerViewCenterConstraint.active = YES;
    } else {
        self.activitiLogoTopConstraint.active = NO;
        self.activitiLogoPaddedTopConstraint.active = NO;
        self.activitiLogoCenterPaddedConstraint.active = YES;
        
        self.containerViewCenterConstraint.active = NO;
        self.containerViewTopAlignment.active = YES;
    }
    
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:5.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:nil];
}

- (void)performCredentialPageAnimationInReverse:(BOOL)isReverseAnimation
                                completionBlock:(void (^)(BOOL finished))completionBlock {
    if (!isReverseAnimation) {
        // Make visible the environment toolbar
        [self.buttonToolbar animateAlpha:1.0f
                            withDuration:kDefaultAnimationTime
                     withCompletionBlock:nil];
        
        // Animate moving rounded views and server buttons to the left side
        self.roundedViewsCenterConstraint.active = NO;
        self.serverButtonsCenterConstraint.active = NO;
        self.roundedViewsPaddedConstraint.active = YES;
        self.serverButtonsPaddedConstraint.active = YES;
    } else {
        // Animate moving rounded views and server buttons to the right side
        
        self.roundedViewsPaddedConstraint.active = NO;
        self.serverButtonsPaddedConstraint.active = NO;
        
        self.roundedViewsCenterConstraint.active = YES;
        self.serverButtonsCenterConstraint.active = YES;
    }
    
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:5.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.roundedViewsContainer layoutIfNeeded];
                         [self.serverButtonsContainerView layoutIfNeeded];
                     } completion:completionBlock];
}

- (void)performActivityAnimationInReverse:(BOOL)isReverseAnimation {
    self.activityView.animating = !self.activityView.animating;
    
    [UIView animateWithDuration:kDefaultAnimationTime
                          delay:.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         if (!isReverseAnimation) {
                             // Flip logo image view
                             self.activitiLogoImageView.layer.transform = CATransform3DMakeRotation(M_PI_2,0.0,1.0,0.0);
                         } else {
                             self.activityView.layer.transform = self.activityView.layer.transform = CATransform3DMakeRotation(-M_PI_2, 0.0f, 1.0f, 0.0f);
                         }
                     } completion:^(BOOL finished) {
                         // Pre-flip activity view to continue from there
                         CATransform3D preFlipTransform = CATransform3DMakeRotation(-M_PI_2, 0.0f, 1.0f, 0.0f);
                         
                         if (self.activityView.animating) {
                             self.activityView.hidden = NO;
                         } else {
                             self.activityView.hidden = YES;
                         }
                         
                         if (!isReverseAnimation) {
                             self.activityView.layer.transform = preFlipTransform;
                         } else {
                             self.activitiLogoImageView.layer.transform = preFlipTransform;
                         }
                         
                         [UIView animateWithDuration:kDefaultAnimationTime
                                               delay:.0f
                                             options:UIViewAnimationOptionCurveEaseInOut
                                          animations:^{
                                              // Flip from pre-flipped position
                                              CATransform3D transform = CATransform3DIdentity;
                                              transform = CATransform3DMakeRotation(0, 0.0f, 1.0f, 0.0f);
                                              transform.m34 = 0.0015;
                                              
                                              if (isReverseAnimation ) {
                                                  self.activitiLogoImageView.layer.transform = transform;
                                              } else {
                                                  self.activityView.layer.transform = transform;
                                              }
                                          } completion:nil];
                     }];
}

- (void)showEnvironmentPageAnimation {
    [self.credentialsPageViewController hideCurrentPageWithCompletionBlock:^(BOOL finished) {
        // Hide the environment toolbar
        [self.buttonToolbar animateAlpha:.0f
                            withDuration:kDefaultAnimationTime
                     withCompletionBlock:nil];
        
        [self performCredentialPageAnimationInReverse:YES
                                      completionBlock:nil];
    }];
}

#pragma mark -
#pragma mark KVO bindings

- (void)handleBindingsForLoginViewController {
    self.kvoManager = [ASDKKVOManager managerWithObserver:self];
    
    __weak typeof(self) weakSelf = self;
    [self.kvoManager observeObject:self.loginModel
                        forKeyPath:NSStringFromSelector(@selector(isCredentialInputInProgress))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 BOOL isEditingInProgress = [change[NSKeyValueChangeNewKey] boolValue];
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     [weakSelf performLogoShrinkAndCredentialsPaddingAnimationInReverse:!isEditingInProgress];
                                 });
                             }];
    
    [self.kvoManager observeObject:self.loginModel
                        forKeyPath:NSStringFromSelector(@selector(authState))
                           options:NSKeyValueObservingOptionNew
                             block:^(id observer, id object, NSDictionary *change) {
                                 AFALoginViewModelAuthentificationState authState = [change[NSKeyValueChangeNewKey] unsignedIntegerValue];
                                 
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     if (AFALoginViewModelAuthentificationStateLoggedOut == authState) {
                                         [weakSelf showEnvironmentPageAnimation];
                                         return ;
                                     }
                                     
                                     // If the user performed an action asses whether an animation is needed
                                     if (AFALoginViewModelAuthentificationStatePreparing != authState) {
                                         [weakSelf performActivityAnimationInReverse:(AFALoginViewModelAuthentificationStateInProgress == authState) ? NO : YES];
                                     }
                                     
                                     if (AFALoginViewModelAuthentificationStateAuthorized == authState) {
                                         [weakSelf performSegueWithIdentifier:kSegueIDLoginAuthorized
                                                                   sender:nil];
                                     }
                                 });
                             }];
}


@end
