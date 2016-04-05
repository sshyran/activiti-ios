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

#import "ASDKTaskDetailsParserOperationWorker.h"
#import "ASDKModelProfile.h"
#import "ASDKModelTask.h"
#import "ASDKModelPaging.h"
#import "ASDKModelFilter.h"
#import "ASDKModelContent.h"
#import "ASDKModelComment.h"
#import "ASDKLogConfiguration.h"
#import "ASDKAPIJSONKeyParams.h"
@import Mantle;

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@implementation ASDKTaskDetailsParserOperationWorker


#pragma mark -
#pragma mark ASDKParserOperationWorker Protocol

- (void)parseContentDictionary:(NSDictionary *)contentDictionary
                        ofType:(NSString *)contentType
           withCompletionBlock:(ASDKParserCompletionBlock)completionBlock
                         queue:(dispatch_queue_t)completionQueue {
    NSParameterAssert(contentDictionary);
    NSParameterAssert(contentType);
    NSParameterAssert(completionBlock);
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        NSArray *taskList = [MTLJSONAdapter modelsOfClass:ASDKModelTask.class
                                            fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                    error:&parserError];
        dispatch_async(completionQueue, ^{
            completionBlock(taskList, parserError, paging);
        });
    }
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeFilterList) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelPaging *paging = [MTLJSONAdapter modelOfClass:ASDKModelPaging.class
                                            fromJSONDictionary:contentDictionary
                                                         error:&parserError];
        
        NSMutableArray *filterList = [NSMutableArray array];
        for (NSDictionary *filterDescription in contentDictionary[kASDKAPIJSONKeyData]) {
            // Extract nested filter information
            ASDKModelFilter *filter = [MTLJSONAdapter modelOfClass:ASDKModelFilter.class
                                                fromJSONDictionary:filterDescription[kASDKAPIJSONKeyFilter]
                                                             error:&parserError];
            if (parserError) {
                ASDKLogError(@"Internal loop parser error for filter model.Reason:%@", parserError.localizedDescription);
            }
            
            // Manualy extract filter general description information and update the converted model
            filter.name = filterDescription[kASDKAPIJSONKeyName];
            filter.instanceID = filterDescription[kASDKAPIJSONKeyID];
            
            [filterList addObject:filter];
        }
        
        dispatch_async(completionQueue, ^{
            completionBlock(filterList, parserError, paging);
        });
    }
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskDetails) isEqualToString:contentType]) {
        NSError *parserError = nil;
        ASDKModelTask *task = [MTLJSONAdapter modelOfClass:ASDKModelTask.class
                                        fromJSONDictionary:contentDictionary
                                                     error:&parserError];
        
        dispatch_async(completionQueue, ^{
            completionBlock(task, parserError, nil);
        });
    }
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeContent) isEqualToString:contentType]) {
        NSError *parserError = nil;
        BOOL isParsedContentACollection = contentDictionary[kASDKAPIJSONKeyData] ? YES : NO;
        
        if (!isParsedContentACollection) {
            ASDKModelContent *content = [MTLJSONAdapter modelOfClass:ASDKModelContent.class
                                                  fromJSONDictionary:contentDictionary
                                                               error:&parserError];
            dispatch_async(completionQueue, ^{
                completionBlock(content, parserError, nil);
            });
        } else {
            NSArray *contentList = [MTLJSONAdapter modelsOfClass:ASDKModelContent.class
                                                   fromJSONArray:contentDictionary[kASDKAPIJSONKeyData]
                                                           error:&parserError];
            dispatch_async(completionQueue, ^{
                completionBlock(contentList, parserError, nil);
            });
        }
    }
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeComments) isEqualToString:contentType]) {
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
    
    if ([CREATE_STRING(ASDKTaskDetailsParserContentTypeComment) isEqualToString:contentType]) {
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
    return @[CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskList),
             CREATE_STRING(ASDKTaskDetailsParserContentTypeFilterList),
             CREATE_STRING(ASDKTaskDetailsParserContentTypeTaskDetails),
             CREATE_STRING(ASDKTaskDetailsParserContentTypeContent),
             CREATE_STRING(ASDKTaskDetailsParserContentTypeComments),
             CREATE_STRING(ASDKTaskDetailsParserContentTypeComment)];
}

@end
