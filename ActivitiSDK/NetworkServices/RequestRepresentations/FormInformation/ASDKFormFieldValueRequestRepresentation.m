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

#import "ASDKFormFieldValueRequestRepresentation.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormField.h"
#import "ASDKNetworkServiceConstants.h"
#import "ASDKModelFormFieldOption.h"
#import "ASDKModelUser.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKFormFieldValueRequestRepresentation

#pragma mark -
#pragma mark MTLJSONSerializing Delegate

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{//Objc property          JSON property
             @"formFields"          : @"values",
             @"outcome"             : @"outcome"
             };
}


#pragma mark -
#pragma mark Value transformations

+ (NSValueTransformer *)formFieldsJSONTransformer {
    return [MTLValueTransformer transformerUsingReversibleBlock:^id(NSDictionary *formFields, BOOL *success, NSError *__autoreleasing *error) {
        NSMutableDictionary *formFieldMetadataValuesDict = [NSMutableDictionary dictionary];
        
        for (NSNumber *sectionCount in formFields.allKeys) {
            // Extract the form fields for the correspondent container
            NSArray *associatedFormFields = [formFields[sectionCount] formFields];
            
            for (ASDKModelFormField *formField in associatedFormFields) {
                
                if (ASDKModelFormFieldRepresentationTypeReadOnly != formField.representationType
                    && ASDKModelFormFieldRepresentationTypeContainer != formField.representationType) {
                    
                    // If there's an option field available change the nesting structure
                    if (formField.metadataValue.option) {
                        [formFieldMetadataValuesDict setObject:@{kASDKAPIGenericIDParameter  : formField.instanceID,
                                                                 kASDKAPIGenericNameParameter: formField.metadataValue.option.attachedValue}
                                                        forKey:formField.instanceID];
                    } else if (formField.metadataValue.attachedValue) { // if there's a attached value
                        [formFieldMetadataValuesDict setObject:formField.metadataValue.attachedValue
                                                        forKey:formField.instanceID];
                    } else if (formField.values) { // otherwise use the original value
                        // special attach field handling
                        if (formField.representationType == ASDKModelFormFieldRepresentationTypeAttach) {
                            
                            NSMutableArray *modelContentArray = [NSMutableArray new];
                            for (ASDKModelContent *modelContent in formField.values) {
                                [modelContentArray addObject:modelContent.instanceID];
                            }
                            
                            [formFieldMetadataValuesDict setObject:[modelContentArray componentsJoinedByString:@","]
                                                            forKey:formField.instanceID];

                        }
                        // special radio / dropdown field handling
                        else if (formField.representationType == ASDKModelFormFieldRepresentationTypeDropdown ||
                            formField.representationType == ASDKModelFormFieldRepresentationTypeRadio) {
                            
                            for (ASDKModelFormFieldOption *formFieldOption in formField.formFieldOptions) {
                                if ([formFieldOption.name isEqualToString:formField.values.firstObject]) {
                                    
                                    [formFieldMetadataValuesDict setObject:@{kASDKAPIGenericIDParameter  : formFieldOption.instanceID,
                                                                             kASDKAPIGenericNameParameter: formField.values.firstObject}
                                                                    forKey:formField.instanceID];

                                    break;
                                }
                            }
                        }
                        // special people field handling
                        else if (formField.representationType == ASDKModelFormFieldRepresentationTypePeople) {
                            
                            NSError *error = nil;
                            if (formField.values.count > 1) {
                                NSArray *JSONDictionaryArr = [MTLJSONAdapter JSONArrayFromModels:formField.values
                                                                                           error:&error];

                                [formFieldMetadataValuesDict setObject:JSONDictionaryArr
                                                                forKey:formField.instanceID];
                            } else if (formField.values.count == 1) {
                                
                                NSDictionary *JSONDictionary = [MTLJSONAdapter JSONDictionaryFromModel:formField.values.firstObject
                                                                                                 error:&error];
                                [formFieldMetadataValuesDict setObject:JSONDictionary
                                                                forKey:formField.instanceID];
                            }
                        }
                        else {
                            [formFieldMetadataValuesDict setObject:formField.values.firstObject
                                                            forKey:formField.instanceID];
                        }
                        
                    }
                }
            }
        }
        
        return formFieldMetadataValuesDict;
    }];
}

@end
