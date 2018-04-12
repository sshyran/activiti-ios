/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile SDK.
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

#import "ASDKReachabilityViewController.h"
#import "ASDKNetworkServiceConstants.h"
#import "ASDKProfileDataAccessor.h"

@interface ASDKReachabilityViewController ()

@property (strong, nonatomic) id reachabilityObserver;

@end

@implementation ASDKReachabilityViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        __weak typeof(self) weakSelf = self;
        
        _networkReachabilityStatus = [self requestInitialReachabilityStatus];
        
        _reachabilityObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceNoInternetConnection
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                          __strong typeof(self) strongSelf = weakSelf;
                                                          
                                                          strongSelf.networkReachabilityStatus = ASDKNetworkReachabilityStatusNotReachable;
                                                      }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:kASDKAPINetworkServiceInternetConnectionAvailable
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
                                                          __strong typeof(self) strongSelf = weakSelf;
                                                          
                                                          strongSelf.networkReachabilityStatus = ASDKNetworkReachabilityStatusReachableViaWWANOrWifi;
                                                      }];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
}

- (ASDKNetworkReachabilityStatus)requestInitialReachabilityStatus {
    ASDKProfileDataAccessor *profileDataAccessor = [[ASDKProfileDataAccessor alloc] initWithDelegate:nil];
    return [profileDataAccessor networkReachabilityStatus];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

@end
