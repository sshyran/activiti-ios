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

#import "AFANavigationController.h"
#import "AFAUIConstants.h"
#import "AFAConnectivityViewController.h"
#import "AFALoginViewController.h"
@import ActivitiSDK;

@interface AFANavigationController ()

@property (strong, nonatomic) id                            reachabilityChangeObserver;
@property (strong, nonatomic) AFAConnectivityViewController *connectivityViewController;

@end

@implementation AFANavigationController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        __weak typeof(self) weakSelf = self;
        self.reachabilityChangeObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceNoInternetConnection
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
          __strong typeof(self) strongSelf = weakSelf;
          if (strongSelf.topViewController.class != [AFALoginViewController class]) {
              strongSelf.connectivityViewController = [strongSelf.storyboard instantiateViewControllerWithIdentifier:kStoryboardIDConnectivityViewController];
              [strongSelf presentViewController:strongSelf.connectivityViewController
                                       animated:YES
                                     completion:nil];
          }
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceInternetConnectionAvailable
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
          __strong typeof(self) strongSelf = weakSelf;
          [strongSelf.connectivityViewController dismissViewControllerAnimated:YES
                                                                    completion:nil];
        }];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityChangeObserver];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 
#pragma mark Navigation

// Pass the call to the top most of the navigation stack
- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    UIViewController *controller = self.topViewController;
    return [controller segueForUnwindingToViewController:toViewController
                                      fromViewController:fromViewController
                                              identifier:identifier];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}

@end
