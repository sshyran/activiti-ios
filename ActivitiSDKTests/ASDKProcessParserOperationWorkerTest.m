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

@interface ASDKProcessParserOperationWorkerTest : ASDKBaseTest

@property (strong, nonatomic) ASDKProcessParserOperationWorker *processParserWorker;

@end

@implementation ASDKProcessParserOperationWorkerTest

- (void)setUp {
    [super setUp];
    
    self.processParserWorker = [ASDKProcessParserOperationWorker new];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testThatItReturnsAvailableServices {
    NSArray *availableServices = @[CREATE_STRING(ASDKProcessParserContentTypeProcessDefinitionList),
                                   CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceList),
                                   CREATE_STRING(ASDKProcessParserContentTypeStartProcessInstance),
                                   CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceDetails),
                                   CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceContent),
                                   CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComments),
                                   CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComment)];
    
    XCTAssert([[self.processParserWorker availableServices] isEqualToArray:availableServices]);
}

- (void)testThatItParsesProcessDefinitionList {
    // given
    NSError *error = nil;
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"ProcessDefinitionList" ofType:@"json"];
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:filePath];
    NSDictionary *response = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData
                                                                             options:NSJSONReadingMutableContainers
                                                                               error:&error];
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    
    // when
    [self.processParserWorker parseContentDictionary:response
                                              ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessDefinitionList)
                                 withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                     XCTAssertNil(error);
                                     XCTAssertNotNil(paging);
                                     XCTAssert([parsedObject isKindOfClass:[NSArray class]]);
                                     XCTAssert([(NSArray *)parsedObject count] == 1);
                                     
                                     XCTAssert(paging.pageCount == 1);
                                     XCTAssert(paging.size == 1);
                                     XCTAssert(!paging.start);
                                     
                                     ASDKModelProcessDefinition *processDefinition = [(NSArray *)parsedObject firstObject];
                                     XCTAssert([processDefinition.name isEqualToString:@"VisiblityConditionsProcess"]);
                                     XCTAssert([processDefinition.category isEqualToString:@"http://www.activiti.org/processdef"]);
                                     XCTAssert([processDefinition.deploymentID isEqualToString:@"37727"]);
                                     XCTAssertFalse(processDefinition.hasStartForm);
                                     XCTAssert([processDefinition.key isEqualToString:@"VisiblityConditionsProcess"]);
                                     XCTAssert([processDefinition.modelID isEqualToString:@"VisiblityConditionsProcess:3:37730"]);
                                     XCTAssert([processDefinition.tenantID isEqualToString:@"tenant_1"]);
                                     XCTAssert(processDefinition.version == 3);
                                     
                                     [expectation fulfill];
                                 } queue:dispatch_get_main_queue()];
    
    // then
    [self waitForExpectationsWithTimeout:.5f
                                 handler:nil];
}

- (void)testThatItParsesProcessInstanceList {
    // given
    NSError *error = nil;
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"ProcessInstanceList" ofType:@"json"];
    NSData *jsonData = [[NSData alloc] initWithContentsOfFile:filePath];
    NSDictionary *response = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData
                                                                             options:NSJSONReadingMutableContainers
                                                                               error:&error];
    XCTAssertNil(error);
    
    XCTestExpectation *expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];

    // when
    [self.processParserWorker parseContentDictionary:response
                                              ofType:CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceList)
                                 withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
                                     XCTAssertNil(error);
                                     XCTAssertNotNil(paging);
                                     XCTAssert([parsedObject isKindOfClass:[NSArray class]]);
                                     XCTAssert([(NSArray *)parsedObject count] == 2);
                                     
                                     XCTAssert(paging.pageCount == 2);
                                     XCTAssert(paging.size == 2);
                                     XCTAssert(!paging.start);
                                     
                                     ASDKModelProcessInstance *processInstance = [(NSArray *)parsedObject firstObject];
                                     XCTAssert([processInstance.name isEqualToString:@"VisiblityConditionsProcess - October 5th 2016"]);
                                     XCTAssert([processInstance.modelID isEqualToString:@"50259"]);
                                     XCTAssertNil(processInstance.endDate);
                                     XCTAssert([processInstance.processDefinitionKey isEqualToString:@"VisiblityConditionsProcess"]);
                                     XCTAssert([processInstance.processDefinitionName isEqualToString:@"VisiblityConditionsProcess"]);
                                     XCTAssertTrue(processInstance.graphicalNotationDefined);
                                     XCTAssert([processInstance.tenantID isEqualToString:@"tenant_1"]);
                                     XCTAssert([processInstance.initiatorModel isKindOfClass:[ASDKModelProfile class]]);
                                     XCTAssert([processInstance.processDefinitionDeploymentID isEqualToString:@"37727"]);
                                     XCTAssertFalse(processInstance.isStartFormDefined);
                                     XCTAssert(processInstance.processDefinitionVersion == 3);
                                     XCTAssertNil(processInstance.processDefinitionDescription);
                                     XCTAssert([processInstance.processDefinitionCategory isEqualToString:@"http://www.activiti.org/processdef"]);
                                     NSDate *jsonDate = [[ASDKModelBase standardDateFormatter] dateFromString:@"2016-10-05T13:54:56.326+0000"];
                                     XCTAssert(NSOrderedSame == [processInstance.startDate compare:jsonDate]);
                                     
                                     [expectation fulfill];
                                 } queue:dispatch_get_main_queue()];
    
    // then
    [self waitForExpectationsWithTimeout:.5f
                                 handler:nil];
}

@end
