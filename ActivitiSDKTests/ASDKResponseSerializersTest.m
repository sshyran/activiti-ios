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

#import "ASDKBaseTest.h"

@interface ASDKResponseSerializersTest : ASDKBaseTest

@end

@implementation ASDKResponseSerializersTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testThatItHandlesUnauthorizedResponseForHTTPSerializer {
    ASDKHTTPResponseSerializer *httpResponseSerializer = [ASDKHTTPResponseSerializer serializer];
    [self validateUnauthorizedTestForResponseSerializer:httpResponseSerializer];
}

- (void)testThatItHandlesUnauthorizedResponseForJSONSerializer {
    ASDKJSONResponseSerializer *jsonResponseSerializer = [ASDKJSONResponseSerializer serializer];
    [self validateUnauthorizedTestForResponseSerializer:jsonResponseSerializer];
}

- (void)testThatItHandlesUnauthorizedResponseForImageSerializer {
    ASDKImageResponseSerializer *imageResponseSerializer = [ASDKImageResponseSerializer serializer];
    [self validateUnauthorizedTestForResponseSerializer:imageResponseSerializer];
}


#pragma mark -
#pragma mark Utils

- (void)validateUnauthorizedTestForResponseSerializer:(id<AFURLResponseSerialization>)responseSerializer {
    // given
    NSInteger statusCode = 401;
    
    NSHTTPURLResponse *response =
    [[NSHTTPURLResponse alloc] initWithURL:[self baseURL]
                                statusCode:(NSInteger)statusCode
                               HTTPVersion:@"1.1"
                              headerFields:@{@"Content-Type": @"text/html"}];
    id observerMock = [OCMockObject observerMock];
    
    // expect
    [[NSNotificationCenter defaultCenter] addMockObserver:observerMock
                                                     name:kADSKAPIUnauthorizedRequestNotification
                                                   object:nil];
    [[observerMock expect] notificationWithName:kADSKAPIUnauthorizedRequestNotification
                                         object:[OCMArg any]
                                       userInfo:[OCMArg any]];
    
    // when
    NSError *error = nil;
    [responseSerializer responseObjectForResponse:response
                                             data:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                                            error:&error];
    
    // then
    [observerMock verify];
    [[NSNotificationCenter defaultCenter] removeObserver:observerMock];
}

@end
