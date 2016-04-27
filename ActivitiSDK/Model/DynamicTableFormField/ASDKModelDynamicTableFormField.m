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

#import "ASDKModelDynamicTableFormField.h"
#import "ASDKModelDynamicTableColumnDefinitionFormField.h"
#import "ASDKModelDynamicTableColumnDefinitionRestFormField.h"
#import "ASDKModelDynamicTableColumnDefinitionAmountFormField.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKModelDynamicTableFormField

#pragma mark -
#pragma mark MTLJSONSerializing Delegate


+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *inheretedPropertyKeys = [NSMutableDictionary dictionaryWithDictionary:[super JSONKeyPathsByPropertyKey]];
    
    if (inheretedPropertyKeys.allKeys.count) {
        [inheretedPropertyKeys addEntriesFromDictionary:@{//Objc property           JSON property
                                                          @"columnDefinitions"      : @"columnDefinitions"
                                                          }];
    }
    
    return inheretedPropertyKeys;
}

+ (NSValueTransformer *)columnDefinitionsJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSDictionary *value, BOOL *success, NSError *__autoreleasing *error) {
        
        NSMutableArray *columnDefinitions = [NSMutableArray array];
        for (NSDictionary *columnDefinitionJSON in value) {
            
            NSError *formFieldsParseError = nil;
            id parsedColumnDefinition = nil;

            if ([columnDefinitionJSON[@"type"] isEqualToString:@"String"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeText];
            } else if([columnDefinitionJSON[@"type"] isEqualToString:@"Boolean"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeBoolean];
            } else if([columnDefinitionJSON[@"type"] isEqualToString:@"Date"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeDate];
            } else if([columnDefinitionJSON[@"type"] isEqualToString:@"Number"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeNumerical];
            } else if ([columnDefinitionJSON[@"type"] isEqualToString:@"Amount"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionAmountFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeAmount];
            } else if([columnDefinitionJSON[@"type"] isEqualToString:@"Dropdown"]) {
                parsedColumnDefinition = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableColumnDefinitionRestFormField.class
                                                   fromJSONDictionary:columnDefinitionJSON
                                                                error:&formFieldsParseError];
                [self setRepresentationTypeForFormField:parsedColumnDefinition
                                 withRepresentationType:ASDKModelFormFieldRepresentationTypeDropdown];
            }
            
            if (parsedColumnDefinition != nil) {
                [columnDefinitions addObject:parsedColumnDefinition];
            }
        }
        
        return columnDefinitions;
    }];
}

+ (NSValueTransformer *)valuesJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        if (value) {
            if ([value isKindOfClass:[NSArray class]]) {
                if (!((NSArray *)value).count) {
                    return nil;
                } else {
                    return value;
                }
            }
        }
        
        return nil;
    }];
}

+ (void)setRepresentationTypeForFormField:(ASDKModelFormField *)formField
                   withRepresentationType:(ASDKModelFormFieldRepresentationType)representationType {
    formField.representationType = representationType;
}

@end