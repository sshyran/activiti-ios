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

#import "ASDKIntegrationParserOperationWorker.h"
#import "ASDKModelPaging.h"
#import "ASDKModelIntegrationAccount.h"
#import "ASDKModelNetwork.h"
#import "ASDKAPIJSONKeyParams.h"
@import Mantle;

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKIntegrationParserOperationWorker


#pragma mark -
#pragma mark ASDKParserOperationWorker Protocol

- (void)parseContentDictionary:(NSDictionary *)contentDictionary
                        ofType:(NSString *)contentType
           withCompletionBlock:(ASDKParserCompletionBlock)completionBlock
                         queue:(dispatch_queue_t)completionQueue {
    NSParameterAssert(contentDictionary);
    NSParameterAssert(contentType);
    NSParameterAssert(completionBlock);
    
    if ([CREATE_STRING(ASDKIntegrationParserContentTypeAccountList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        NSArray *accountList = [MTLJSONAdapter modelsOfClass:ASDKModelIntegrationAccount.class
                                               fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                       error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(accountList, parserError, paging);
        });
    }
    
    if ([CREATE_STRING(ASDKIntegrationParserContentTypeNetworkList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        NSArray *networkList = [MTLJSONAdapter modelsOfClass:ASDKModelNetwork.class
                                               fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                       error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(networkList, parserError, paging);
        });
    }
}

- (NSArray *)availableServices {
    return @[CREATE_STRING(ASDKIntegrationParserContentTypeAccountList),
             CREATE_STRING(ASDKIntegrationParserContentTypeNetworkList)];
}

@end
