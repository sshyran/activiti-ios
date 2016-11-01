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

#import "ASDKBaseTest.h"

@interface ASDKServicePathFactoryTest : ASDKBaseTest

@property (strong, nonatomic) ASDKServicePathFactory *servicePathFactory;

@end

@implementation ASDKServicePathFactoryTest

- (void)setUp {
    [super setUp];
 
    NSString *hostAddress = @"localhost";
    NSString *serviceDocumentPath = @"activiti-app";
    NSString *port = @"9999";
    BOOL overSecureLayer = NO;
    
    self.servicePathFactory = [[ASDKServicePathFactory alloc] initWithHostAddress:hostAddress
                                                              serviceDocumentPath:serviceDocumentPath
                                                                             port:port
                                                                  overSecureLayer:overSecureLayer];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testThatItCreatesBaseURL {
    // given
    NSString *hostnameAddress = @"http://localhost:9999";
    NSURL *baseURL = [NSURL URLWithString:@"activiti-app" relativeToURL:
                      [NSURL URLWithString:[hostnameAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    
    // then
    XCTAssertTrue([self isURL:baseURL
              equivalentToURL:self.servicePathFactory.baseURL]);
}

@end
