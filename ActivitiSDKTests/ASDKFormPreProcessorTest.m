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

#import "ASDKNetworkProxyBaseTest.h"

typedef void (^ASDKFormDescriptionCompletionBlock) (ASDKModelFormDescription *formDescription, NSError *error);

@interface ASDKFormPreProcessorTest : ASDKNetworkProxyBaseTest

@property (strong, nonatomic) ASDKFormPreProcessor              *formPreProcessor;
@property (strong, nonatomic) ASDKTaskFormParserOperationWorker *taskFormParserWorker;
@property (strong, nonatomic) ASDKFormNetworkServices           *formNetworkService;
@property (strong, nonatomic) id                                requestOperationManagerMock;

@end

@implementation ASDKFormPreProcessorTest

- (void)setUp {
    [super setUp];
    
    self.formNetworkService = [ASDKFormNetworkServices new];
    self.formNetworkService.resultsQueue = dispatch_get_main_queue();
    self.formNetworkService.parserOperationManager = self.parserOperationManager;
    self.formNetworkService.servicePathFactory = [ASDKServicePathFactory new];
    self.formNetworkService.diskServices = [ASDKDiskServices new];
    self.requestOperationManagerMock = OCMClassMock([ASDKRequestOperationManager class]);
    
    ASDKTaskFormParserOperationWorker *taskFormParserWorker = [ASDKTaskFormParserOperationWorker new];
    [self.formNetworkService.parserOperationManager registerWorker:taskFormParserWorker
                                                       forServices:[taskFormParserWorker availableServices]];
    
    self.formPreProcessor = [ASDKFormPreProcessor new];
    self.taskFormParserWorker = [ASDKTaskFormParserOperationWorker new];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testThatItProcessesFormFieldsInTaskFormThatDontRequireProcessing {
    // given
    ASDKModelFormDescription *formDescription = [self formFieldDescriptionFromJSON:@"TaskAllFieldsFormResponse"];
    NSData *buffer = [NSKeyedArchiver archivedDataWithRootObject:formDescription.formFields];
    NSArray *formFieldsCopy = [NSKeyedUnarchiver unarchiveObjectWithData:buffer];
    
    // expect
    XCTestExpectation *taskFormFieldsExpectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    
    // when
    [self.formPreProcessor setupWithTaskID:OCMOCK_ANY
                            withFormFields:formDescription.formFields
                   withDynamicTableFieldID:nil
                 preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                     if ([formDescription.formFields isEqualToArray:formFieldsCopy]) {
                         [taskFormFieldsExpectation fulfill];
                     }
                 }];
    
    [self waitForExpectationsWithTimeout:.5f
                                 handler:nil];
}

- (void)testThatItProcessesDropdownFormFieldWithRestURL {
    // given
    ASDKModelFormDescription *formDescription = [self formFieldDescriptionFromJSON:@"FormDropdownWithRestURLResponse"];
    
    [[[self.requestOperationManagerMock stub] andDo:^(NSInvocation *invocation) {
        ASDKTestRequestSuccessBlock successBlock;
        NSUInteger successBlockParameterIdxInMethodSignature = 5;
        [invocation getArgument:&successBlock
                        atIndex:successBlockParameterIdxInMethodSignature];
        NSURLSessionDataTask *dataTask = [self dataTaskWithStatusCode:ASDKHTTPCode200OK];
        [invocation setReturnValue:&dataTask];
        
        successBlock(dataTask, [self contentDictionaryFromJSON:@"TaskFormRestFieldValuesResponse"]);
    }] GET:OCMOCK_ANY parameters:OCMOCK_ANY progress:OCMOCK_ANY success:OCMOCK_ANY failure:OCMOCK_ANY];
    
    self.formNetworkService.requestOperationManager = self.requestOperationManagerMock;
    self.formPreProcessor.formNetworkServices = self.formNetworkService;
    
    // expect
    XCTestExpectation *dropdownFormFieldExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.processDropdownFormField", NSStringFromSelector(_cmd)]];
    XCTestExpectation *dropdownFormFieldInDynamicTableExpectation = [self expectationWithDescription:[NSString stringWithFormat:@"%@.processDropdownFormFieldInDynamicTable", NSStringFromSelector(_cmd)]];
    
    // when
    [self.formPreProcessor setupWithTaskID:OCMOCK_ANY
                            withFormFields:formDescription.formFields
                   withDynamicTableFieldID:nil
                 preProcessCompletionBlock:^(NSArray *formFields, NSError *error) {
                     ASDKModelFormField *dropDownFormField = [[(ASDKModelFormField *)formFields.firstObject formFields] firstObject];
                     
                     XCTAssert(dropDownFormField.formFieldOptions.count == 10);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions.firstObject name] isEqualToString:@"Leanne Graham"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions.firstObject modelID] isEqualToString:@"1"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions[9] name] isEqualToString:@"Clementina DuBuque"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions[9] modelID] isEqualToString:@"10"]);
                     
                     [dropdownFormFieldExpectation fulfill];
                 }];

    NSArray *dynamicTableColumnDefinitions = [(ASDKModelDynamicTableFormField *)formDescription.formFields.lastObject columnDefinitions];
    [self.formPreProcessor setupWithTaskID:OCMOCK_ANY
                            withFormFields:dynamicTableColumnDefinitions
                   withDynamicTableFieldID:OCMOCK_ANY
                 preProcessCompletionBlock:^(NSArray *formFields, NSError *error) {
                     ASDKModelFormField *dropDownFormField = (ASDKModelFormField *)formFields.firstObject;
                     
                     XCTAssert(dropDownFormField.formFieldOptions.count == 10);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions.firstObject name] isEqualToString:@"Leanne Graham"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions.firstObject modelID] isEqualToString:@"1"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions[9] name] isEqualToString:@"Clementina DuBuque"]);
                     XCTAssert([[(ASDKModelFormFieldOption *)dropDownFormField.formFieldOptions[9] modelID] isEqualToString:@"10"]);
                     
                     [dropdownFormFieldInDynamicTableExpectation fulfill];
                 }];
    
    [self waitForExpectationsWithTimeout:.5f
                                 handler:nil];
}

- (void)testThatItProcessesTaskReadonlyAmountAndHyperlinkFields {
    // given
    ASDKModelFormDescription *formDescription = [self formFieldDescriptionFromJSON:@"FormReadOnlyAmountFieldAndHyperLinkResponse"];
    
    // expect
    XCTestExpectation *taskFormFieldsExpectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    
    // when
    [self.formPreProcessor setupWithTaskID:OCMOCK_ANY
                            withFormFields:formDescription.formFields
                   withDynamicTableFieldID:nil
                 preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                     ASDKModelAmountFormField *amountFormField = (ASDKModelAmountFormField *)[(ASDKModelFormField *)processedFormFields.firstObject formFields].firstObject;
                     ASDKModelHyperlinkFormField *hyperlinkFormField = (ASDKModelHyperlinkFormField *)[(ASDKModelFormField *)processedFormFields.firstObject formFields].lastObject;
                     
                     XCTAssert([amountFormField.currency isEqualToString:@"$"]);
                     XCTAssertTrue(amountFormField.enableFractions);
                     
                     XCTAssert([hyperlinkFormField.hyperlinkURL isEqualToString:@"http://www.alfresco.com"]);
                     XCTAssert([hyperlinkFormField.displayText isEqualToString:@"Alfresco site"]);
                     
                     [taskFormFieldsExpectation fulfill];
                 }];
    
    [self waitForExpectationsWithTimeout:.5f
                                 handler:nil];
}

- (ASDKModelFormDescription *)formFieldDescriptionFromJSON:(NSString *)jsonFilename {
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
    
    __block ASDKModelFormDescription *formDescription = nil;
    NSDictionary *formDescriptionResponse = [self contentDictionaryFromJSON:jsonFilename];
    
    dispatch_group_enter(group);
    [self.taskFormParserWorker
     parseContentDictionary:formDescriptionResponse
     ofType:CREATE_STRING(ASDKTaskFormParserContentTypeFormModels)
     withCompletionBlock:^(id parsedObject, NSError *error, ASDKModelPaging *paging) {
         formDescription = (ASDKModelFormDescription *)parsedObject;
         dispatch_group_leave(group);
     } queue:processingQueue];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return formDescription;
}

@end
