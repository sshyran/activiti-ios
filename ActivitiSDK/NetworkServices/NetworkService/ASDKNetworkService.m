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

#import "ASDKNetworkService.h"
#import "ASDKNetworkServiceConstants.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKNetworkService()

@property (strong, nonatomic) NSDictionary *responseSerializersDict;
@property (strong, nonatomic) NSDictionary *requestSerializersDict;

@end

@implementation ASDKNetworkService

#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithRequestManager:(ASDKRequestOperationManager *)requestOperationManager
                         parserManager:(ASDKParserOperationManager *)parserManager
                    servicePathFactory:(ASDKServicePathFactory *)servicePathFactory
                          diskServices:(ASDKDiskServices *)diskServices
                          tokenStorage:(ASDKCSRFTokenStorage *)tokenStorage
                          resultsQueue:(dispatch_queue_t)resultsQueue {
    NSParameterAssert(requestOperationManager);
    NSParameterAssert(parserManager);
    NSParameterAssert(servicePathFactory);
    NSParameterAssert(tokenStorage);
    
    self = [super init];
    
    if (self) {
        self.requestOperationManager = requestOperationManager;
        self.parserOperationManager = parserManager;
        self.servicePathFactory = servicePathFactory;
        self.diskServices = diskServices;
        self.tokenStorage = tokenStorage;
        self.resultsQueue = resultsQueue;
        
        self.responseSerializersDict = @{@(ASDKNetworkServiceResponseSerializerTypeJSON) : [AFJSONResponseSerializer serializer],
                                         @(ASDKNetworkServiceResponseSerializerTypeImage): [AFImageResponseSerializer serializer],
                                         @(ASDKNetworkServiceResponseSerializerTypeHTTP) : [AFHTTPResponseSerializer serializer]};
        
        // Configure the request serializers to use the CSRF header field
        AFJSONRequestSerializer *jsonRequestSerializer = [AFJSONRequestSerializer serializer];
        [jsonRequestSerializer setValue:[tokenStorage csrfTokenString]
                     forHTTPHeaderField:kASDKAPICSRFHeaderFieldParameter];
        
        AFHTTPRequestSerializer *httpRequestSerializer = [AFHTTPRequestSerializer serializer];
        [httpRequestSerializer setValue:[tokenStorage csrfTokenString]
                     forHTTPHeaderField:kASDKAPICSRFHeaderFieldParameter];
        
        [requestOperationManager.authenticationProvider setValue:[tokenStorage csrfTokenString]
                                              forHTTPHeaderField:kASDKAPICSRFHeaderFieldParameter];
        
        self.requestSerializersDict = @{@(ASDKNetworkServiceRequestSerializerTypeJSON) : jsonRequestSerializer,
                                        @(ASDKNetworkServiceRequestSerializerTypeHTTP) : httpRequestSerializer};
        
        // Search for the CSRF cookie and if it's not available create it for future requests
        BOOL isCSRFCookieAvailable = NO;
        for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
            if ([cookie.name isEqualToString:kASDKAPICSRFCookieName]) {
                isCSRFCookieAvailable = YES;
                break;
            }
        }
        
        if (!isCSRFCookieAvailable) {
            NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:self.requestOperationManager.baseURL
                                                          resolvingAgainstBaseURL:YES];
            
            NSDictionary *cookieProperties = @{NSHTTPCookieName     : kASDKAPICSRFCookieName,
                                               NSHTTPCookieValue    : [tokenStorage csrfTokenString],
                                               NSHTTPCookiePath     : @"/",
                                               NSHTTPCookieVersion  : @"0",
                                               NSHTTPCookieDomain   : urlComponents.host};
            NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }
    }
    
    return self;
}

#pragma mark - 
#pragma mark Public interface

- (AFHTTPResponseSerializer *)responseSerializerOfType:(ASDKNetworkServiceResponseSerializerType)serializerType {
    return self.responseSerializersDict[@(serializerType)];
}

- (AFHTTPRequestSerializer *)requestSerializerOfType:(ASDKNetworkServiceRequestSerializerType)serializerType {
    return self.requestSerializersDict[@(serializerType)];
}

@end
