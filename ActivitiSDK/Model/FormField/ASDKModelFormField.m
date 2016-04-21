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

#import "ASDKModelFormField.h"
#import "ASDKLogConfiguration.h"
#import "ASDKNetworkServiceConstants.h"
#import "ASDKModelFormFieldOption.h"
#import "ASDKModelAmountFormField.h"
#import "ASDKModelFormFieldAttachParameter.h"
#import "ASDKModelContent.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelHyperlinkFormField.h"
#import "ASDKModelRestFormField.h"
#import "ASDKModelPeopleFormField.h"
#import "ASDKModelDynamicTableFormField.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@implementation ASDKModelFormField


#pragma mark -
#pragma mark Class cluster handling

+ (Class)classForParsingJSONDictionary:(NSDictionary *)JSONDictionary {
    // input forms
    if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"AmountFieldRepresentation"]) {
        return ASDKModelAmountFormField.class;
    } else if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"HyperlinkRepresentation"]) {
        return ASDKModelHyperlinkFormField.class;
    } else if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"RestFieldRepresentation"]) {
        return ASDKModelRestFormField.class;
    } else if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"FormFieldRepresentation"]
               && [JSONDictionary[@"type"] isEqualToString:@"people"]) {
        return ASDKModelPeopleFormField.class;
    } else if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"DynamicTableRepresentation"]) {
        return ASDKModelDynamicTableFormField.class;
    }
    // completed forms
    if ([JSONDictionary[@"type"] isEqualToString:@"readonly"]) {
        if ([JSONDictionary[@"params"][@"field"][@"type"] isEqualToString:@"people"]) {
            return ASDKModelPeopleFormField.class;
        }
    }
    
    // display value
    if ([JSONDictionary[kASDKAPIFormFieldTypeParameter] isEqualToString:@"FormFieldRepresentation"]
        && [JSONDictionary[@"type"] isEqualToString:@"readonly"]) {
        
        if ([JSONDictionary[@"params"][@"field"][@"type"] isEqualToString:@"amount"]) {
            return ASDKModelAmountFormField.class;
        }
        if ([JSONDictionary[@"params"][@"field"][@"type"] isEqualToString:@"hyperlink"]) {
            return ASDKModelHyperlinkFormField.class;
        }
        if ([JSONDictionary[@"params"][@"field"][@"type"] isEqualToString:@"dynamic-table"]) {
            return ASDKModelDynamicTableFormField.class;
        }

    }

    return self;
}

#pragma mark -
#pragma mark MTLJSONSerializing Delegate

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *inheretedPropertyKeys = [NSMutableDictionary dictionaryWithDictionary:[super JSONKeyPathsByPropertyKey]];
    
    if (inheretedPropertyKeys.allKeys.count) {
        [inheretedPropertyKeys addEntriesFromDictionary:
         @{//Objc property           JSON property
           @"fieldType"            : @"fieldType",
           @"fieldName"            : @"name",
           @"representationType"   : @"type",
           @"placeholer"           : @"placeholder",
           @"values"               : @"value",
           @"isReadOnly"           : @"readOnly",
           @"isRequired"           : @"required",
           @"sizeX"                : @"sizeX",
           @"sizeY"                : @"sizeY",
           @"formFields"           : @"fields",
           @"formFieldParams"      : @"params",
           @"formFieldOptions"     : @"options"
           }];
    }
    
    return inheretedPropertyKeys;
}


#pragma mark -
#pragma mark Value transformations

+ (NSValueTransformer *)fieldTypeJSONTransformer {
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:
            @{
              @"ContainerRepresentation"       : @(ASDKModelFormFieldTypeContainer),
              @"FormFieldRepresentation"       : @(ASDKModelFormFieldTypeFormField),
              @"RestFieldRepresentation"       : @(ASDKModelFormFieldTypeRestField),
              @"AmountFieldRepresentation"     : @(ASDKModelFormFieldTypeAmountField),
              @"AttachFileFieldRepresentation" : @(ASDKModelFormFieldTypeAttachField),
              @"HyperlinkRepresentation"       : @(ASDKModelFormFieldTypeHyperlinkField),
              @"DynamicTableRepresentation"    : @(ASDKModelFormFieldTypeDynamicTableField)
            }];
}

+ (NSValueTransformer *)representationTypeJSONTransformer {
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:
            @{
              @"readonly"       : @(ASDKModelFormFieldRepresentationTypeReadOnly),
              @"container"      : @(ASDKModelFormFieldRepresentationTypeContainer),
              @"group"          : @(ASDKModelFormFieldRepresentationTypeHeader),
              @"text"           : @(ASDKModelFormFieldRepresentationTypeText),
              @"boolean"        : @(ASDKModelFormFieldRepresentationTypeBoolean),
              @"date"           : @(ASDKModelFormFieldRepresentationTypeDate),
              @"integer"        : @(ASDKModelFormFieldRepresentationTypeNumerical),
              @"dropdown"       : @(ASDKModelFormFieldRepresentationTypeDropdown),
              @"radio-buttons"  : @(ASDKModelFormFieldRepresentationTypeRadio),
              @"amount"         : @(ASDKModelFormFieldRepresentationTypeAmount),
              @"multi-line-text": @(ASDKModelFormFieldRepresentationTypeMultiline),
              @"readonly-text"  : @(ASDKModelFormFieldRepresentationTypeReadonlyText),
              @"upload"         : @(ASDKModelFormFieldRepresentationTypeAttach),
              @"hyperlink"      : @(ASDKModelFormFieldRepresentationTypeHyperlink),
              @"people"         : @(ASDKModelFormFieldRepresentationTypePeople),
              @"dynamic-table"  : @(ASDKModelFormFieldRepresentationTypeDynamicTable)
              }];
}

+ (NSValueTransformer *)formFieldsJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSDictionary *value, BOOL *success, NSError *__autoreleasing *error) {
        NSMutableArray * childrenFormFieldsJSONArr = [NSMutableArray array];
        for (NSString *key in value.allKeys) {
            // We know that we're receiving an array of dictionaries
            NSArray *formFieldsForKey = value[key];
            [childrenFormFieldsJSONArr addObjectsFromArray:formFieldsForKey];
        }
        
        NSError *childrenFormFieldsParseError = nil;
        NSArray *childrenFormModels = [MTLJSONAdapter modelsOfClass:ASDKModelFormField.class
                                                      fromJSONArray:childrenFormFieldsJSONArr
                                                              error:&childrenFormFieldsParseError];
        if (childrenFormFieldsParseError) {
            ASDKLogVerbose(@"Cannot parse children form models. Reason:%@", childrenFormFieldsParseError.localizedDescription);
        }
        
        return childrenFormModels;
    } reverseBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        // Not applicable for the time being to provide back a JSON representation
        return nil;
    }];
}

+ (NSValueTransformer *)formFieldParamsJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSDictionary *value, BOOL *success, NSError *__autoreleasing *error) {
        NSError *formFieldsParseError = nil;
        id parsedFormFieldParams = nil;
        
        if (value[kASDKAPIFormFieldParameter]) {
            if ([value[kASDKAPIFormFieldParameter][@"type"] isEqualToString:@"amount"]) {
                parsedFormFieldParams = [MTLJSONAdapter modelOfClass:ASDKModelAmountFormField.class
                                                  fromJSONDictionary:value[kASDKAPIFormFieldParameter]
                                                               error:&formFieldsParseError];
            } else if([value[kASDKAPIFormFieldParameter][@"type"] isEqualToString:@"hyperlink"]) {
                parsedFormFieldParams = [MTLJSONAdapter modelOfClass:ASDKModelHyperlinkFormField.class
                                                  fromJSONDictionary:value[kASDKAPIFormFieldParameter]
                                                               error:&formFieldsParseError];
            } else if([value[kASDKAPIFormFieldParameter][@"type"] isEqualToString:@"dynamic-table"]) {
                parsedFormFieldParams = [MTLJSONAdapter modelOfClass:ASDKModelDynamicTableFormField.class
                                                  fromJSONDictionary:value[kASDKAPIFormFieldParameter]
                                                               error:&formFieldsParseError];
            } else {
                parsedFormFieldParams = [MTLJSONAdapter modelOfClass:ASDKModelFormField.class
                                                  fromJSONDictionary:value[kASDKAPIFormFieldParameter]
                                                               error:&formFieldsParseError];
            }
        } else if (value[kASDKAPIFileSourceFormFieldParameter]) {
            parsedFormFieldParams = [MTLJSONAdapter modelOfClass:ASDKModelFormFieldAttachParameter.class
                                              fromJSONDictionary:value
                                                           error:&formFieldsParseError];
        }
        
        if (formFieldsParseError) {
            ASDKLogVerbose(@"Cannot parse form field parameters model. Reason:%@", formFieldsParseError.localizedDescription);
        }
        
        return parsedFormFieldParams;
    }];
}

+ (NSValueTransformer *)formFieldOptionsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:ASDKModelFormFieldOption.class];
}

+ (NSValueTransformer *)valuesJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        if ([value isKindOfClass:[NSString class]]) {
            return @[value];
        }
        
        if (value) {
            if ([value isKindOfClass:[NSArray class]]) {
                if (!((NSArray *)value).count) {
                    return nil;
                } else {
                    NSError *formFieldsParseError = nil;
                    NSArray *formFields = nil;
                    
                    // Examine one of the collection's element to check for their type
                    // and then try to parse it to a model if possible
                    if ([((NSArray *)value).firstObject isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *firstElement = [value firstObject];
                        
                        // Check for form fields attached content
                        if (firstElement[kASDKAPIContentAvailableParameter]) {
                            formFields = [MTLJSONAdapter modelsOfClass:ASDKModelContent.class
                                                         fromJSONArray:value
                                                                 error:&formFieldsParseError];
                            if (formFieldsParseError) {
                                ASDKLogVerbose(@"Cannot parse form field parameters model. Reason:%@", formFieldsParseError.localizedDescription);
                            }
                        }
                    }
                    
                    return formFields;
                }
            } else {
                return @[[NSString stringWithFormat:@"%@", value]];
            }
        }
        
        return nil;
    }];
}

@end
