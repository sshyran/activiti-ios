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

#import "ASDKModelFormVisibilityCondition.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKModelFormVisibilityCondition

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *inheretedPropertyKeys = [NSMutableDictionary dictionaryWithDictionary:[super JSONKeyPathsByPropertyKey]];
    
    if (inheretedPropertyKeys.allKeys.count) {
        [inheretedPropertyKeys addEntriesFromDictionary:
         @{//Objc property          JSON property
           @"leftFormFieldID"       : @"leftFormFieldId",
           @"leftRestResponseID"    : @"leftRestResponseId",
           @"operationOperator"     : @"operator",
           @"rightValue"            : @"rightValue",
           @"rightFormFieldID"      : @"rightFormFieldId",
           @"rightRestResponseID"   : @"rightRestResponseId",
           @"nextConditionOperator" : @"nextConditionOperator",
           @"nextCondition"         : @"nextCondition"
         }];
    }
    
    return inheretedPropertyKeys;
}


#pragma mark -
#pragma mark Value transformations

+ (NSValueTransformer *)nextConditionJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:ASDKModelFormVisibilityCondition.class];
}

+ (NSValueTransformer *)rightValueJSONTransformer {
    return [self valueTransformerForIDs];
}

+ (NSValueTransformer *)operationOperatorJSONTransformer {
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:
            @{
              @"=="         : @(ASDKModelFormVisibilityConditionOperatorTypeEqual),
              @"!="         : @(ASDKModelFormVisibilityConditionOperatorTypeNotEqual),
              @"<"          : @(ASDKModelFormVisibilityConditionOperatorTypeLessThan),
              @"<="         : @(ASDKModelFormVisibilityConditionOperatorTypeLessOrEqualThan),
              @">"          : @(ASDKModelFormVisibilityConditionOperatorTypeGreaterThan),
              @">="         : @(ASDKModelFormVisibilityConditionOperatorTypeGreatOrEqualThan),
              @"empty"      : @(ASDKModelFormVisibilityConditionOperatorTypeEmpty),
              @"not empty"  : @(ASDKModelFormVisibilityConditionOperatorTypeNotEmpty)
              }];
}

@end
