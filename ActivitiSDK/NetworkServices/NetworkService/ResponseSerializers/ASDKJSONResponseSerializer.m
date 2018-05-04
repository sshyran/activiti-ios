/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import "ASDKJSONResponseSerializer.h"
#import "ASDKHTTPCodes.h"
#import "ASDKNetworkServiceConstants.h"

@implementation ASDKJSONResponseSerializer


#pragma mark -
#pragma mark AFURLResponseSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error {
    id responseObject = [super responseObjectForResponse:response
                                                    data:data
                                                   error:error];
    // For unauthorized responses a notification will be posted such that they can
    // be handled outside the SDK
    if (ASDKHTTPCode401Unauthorised == [(NSHTTPURLResponse *)response statusCode]) {
        NSDictionary *userInfo = [*error userInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:kADSKAPIUnauthorizedRequestNotification
                                                            object:nil
                                                          userInfo:userInfo];
    }
    
    return responseObject;
}

@end
