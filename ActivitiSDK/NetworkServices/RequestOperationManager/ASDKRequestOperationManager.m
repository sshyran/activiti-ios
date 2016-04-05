/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
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

#import "ASDKRequestOperationManager.h"
#import "ASDKLogConfiguration.h"
#import "ASDKNetworkServiceConstants.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_WARN; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKRequestOperationManager ()

@property (strong, nonatomic) AFHTTPRequestSerializer *authenticationProvider;

@end

@implementation ASDKRequestOperationManager

- (instancetype)initWithBaseURL:(NSURL *)url
         authenticationProvider:(AFHTTPRequestSerializer *)authenticationProvider {
    NSParameterAssert(url);
    
    self = [super initWithBaseURL:url];
    if (self) {
        ASDKLogVerbose(@"Request manager initialized with baseURL:%@", url.absoluteString);
        
        // Allow invalid certificates for test environments
#ifdef DEBUG
            ASDKLogWarn(@"Invalid SSL certificates are allowed. Configuration available just in DEBUG mode.");
        // Create a custom security policy where we allow SSLPinning
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
            securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
        self.securityPolicy = securityPolicy;
#endif
        self.authenticationProvider = authenticationProvider;
        self.requestSerializer = authenticationProvider;
        
        // Start monitoring network changes
        NSOperationQueue *operationQueue = self.operationQueue;
        [self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            switch (status) {
                case AFNetworkReachabilityStatusReachableViaWWAN:
                case AFNetworkReachabilityStatusReachableViaWiFi: {
                    ASDKLogWarn(@"Reachability status changed. Resuming network operation queue...");
                    [operationQueue setSuspended:NO];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kASDKAPINetworkServiceInternetConnectionAvailable
                                                                        object:nil];
                }
                    break;
                    
                case AFNetworkReachabilityStatusNotReachable: {
                    ASDKLogWarn(@"Reachability status changed. Suspending network operation queue...");
                    [operationQueue setSuspended:YES];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kASDKAPINetworkServiceNoInternetConnection
                                                                        object:nil];
                }
                    break;
                    
                default:
                    break;
            }
        }];
        
        [self.reachabilityManager startMonitoring];
    }
    
    return self;
}

- (AFHTTPRequestSerializer *)authenticationProvider {
    return _authenticationProvider;
}

@end
