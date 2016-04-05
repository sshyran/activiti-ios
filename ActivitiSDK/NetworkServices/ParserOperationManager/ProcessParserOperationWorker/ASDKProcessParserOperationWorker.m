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

#import "ASDKProcessParserOperationWorker.h"
#import "ASDKModelPaging.h"
#import "ASDKModelProcessDefinition.h"
#import "ASDKModelProcessInstance.h"
#import "ASDKModelProcessInstanceContent.h"
#import "ASDKModelComment.h"
#import "ASDKAPIJSONKeyParams.h"

@import Mantle;

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKProcessParserOperationWorker

#pragma mark -
#pragma mark ASDKParserOperationWorker Protocol

- (void)parseContentDictionary:(NSDictionary *)contentDictionary
                        ofType:(NSString *)contentType
           withCompletionBlock:(ASDKParserCompletionBlock)completionBlock
                         queue:(dispatch_queue_t)completionQueue {
    NSParameterAssert(contentDictionary);
    NSParameterAssert(contentType);
    NSParameterAssert(completionBlock);
    
    if ([CREATE_STRING(ASDKProcessParserContentTypeProcessDefinitionList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        
        NSArray *processDefinitionList = [MTLJSONAdapter modelsOfClass:ASDKModelProcessDefinition.class
                                                         fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                                 error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(processDefinitionList, parserError, paging);
        });
    }
    if ([CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        
        NSArray *processInstanceList = [MTLJSONAdapter modelsOfClass:ASDKModelProcessInstance.class
                                                       fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                               error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(processInstanceList, parserError, paging);
        });
    }
    if ([CREATE_STRING(ASDKProcessParserContentTypeStartProcessInstance) isEqualToString:contentType] ||
        [CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceDetails) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelProcessInstance *processInstance = [MTLJSONAdapter modelOfClass:ASDKModelProcessInstance.class
                                                              fromJSONDictionary:contentDictionary
                                                                           error:&parserError];
        
        dispatch_async(completionQueue, ^{
            completionBlock(processInstance, parserError, nil);
        });
    }
    if ([CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceContent) isEqualToString:contentType]) {
        NSError *parserError = nil;
        NSMutableArray *contentList = [NSMutableArray array];
        NSArray *processInstanceContentModels = contentDictionary[kASDKAPIJSONKeyData];
        
        for(NSDictionary *contentDict in processInstanceContentModels) {
            ASDKModelProcessInstanceContent *processContentModel = [MTLJSONAdapter modelOfClass:ASDKModelProcessInstanceContent.class
                                                                             fromJSONDictionary:contentDict
                                                                                          error:&parserError];
            [contentList addObject:processContentModel];
        }

        dispatch_async(completionQueue, ^{
            completionBlock(contentList, parserError, nil);
        });
    }
    if ([CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComments) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        NSArray *commentList = [MTLJSONAdapter modelsOfClass:ASDKModelComment.class
                                               fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                       error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(commentList, parserError, paging);
        });
    }
    if ([CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComment) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelComment *comment = [MTLJSONAdapter modelOfClass:ASDKModelComment.class
                                              fromJSONDictionary:contentDictionary
                                                           error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(comment, parserError, nil);
        });
    }
}

- (NSArray *)availableServices {
    return @[CREATE_STRING(ASDKProcessParserContentTypeProcessDefinitionList),
             CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceList),
             CREATE_STRING(ASDKProcessParserContentTypeStartProcessInstance),
             CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceDetails),
             CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceContent),
             CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComments),
             CREATE_STRING(ASDKProcessParserContentTypeProcessInstanceComment)];
}

@end
