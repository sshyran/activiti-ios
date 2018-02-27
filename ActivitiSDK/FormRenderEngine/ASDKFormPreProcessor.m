/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

#import "ASDKFormPreProcessor.h"

#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelRestFormField.h"
#import "ASDKModelAmountFormField.h"
#import "ASDKModelHyperlinkFormField.h"
#import "ASDKModelDynamicTableFormField.h"
#import "ASDKModelFormFieldOption.h"

@interface ASDKFormPreProcessor ()

@property (strong, nonatomic) NSString  *taskID;
@property (strong, nonatomic) NSString  *processDefinitionID;
@property (assign, nonatomic) BOOL      isStartForm;
@property (strong, nonatomic) NSString  *dynamicTableFieldID;

@end

@implementation ASDKFormPreProcessor

- (void)setupWithTaskID:(NSString *)taskID
         withFormFields:(NSArray *)formFields
withDynamicTableFieldID:(NSString *)dynamicTableFieldID
preProcessCompletionBlock:(ASDKFormPreProcessCompletionBlock)preProcessCompletionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(formFields);
    NSParameterAssert(preProcessCompletionBlock);
    
    self.isStartForm = NO;
    self.taskID = taskID;
    self.dynamicTableFieldID = dynamicTableFieldID;
    
    // create dispatch group
    // all async calls for augmenting the form description need to be completed before
    // the completion block is returned
    dispatch_group_t group = dispatch_group_create();
    
    for (ASDKModelFormField *formField in formFields) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            for (ASDKModelFormField *formFieldInContainer in formField.formFields) {
                [self preProcessFormField:formFieldInContainer
                        withDispatchGroup:group];
            }
        } else {
            [self preProcessFormField:formField
                    withDispatchGroup:group];
        }
    }
    
    // dispatch group finished
    dispatch_group_notify(group,dispatch_get_main_queue(),^{
        preProcessCompletionBlock(formFields, nil);
    });
    
}

- (void)setupWithProcessDefinitionID:(NSString *)processDefinitionID
                      withFormFields:(NSArray *)formFields
             withDynamicTableFieldID:(NSString *)dynamicTableFieldID
           preProcessCompletionBlock:(ASDKFormPreProcessCompletionBlock)preProcessCompletionBlock {
    NSParameterAssert(processDefinitionID);
    NSParameterAssert(formFields);
    NSParameterAssert(preProcessCompletionBlock);
    
    self.isStartForm = YES;
    self.processDefinitionID = processDefinitionID;
    self.dynamicTableFieldID = dynamicTableFieldID;
    
    // create dispatch group
    // all async calls for augmenting the form description need to be completed before
    // the completion block is returned
    dispatch_group_t group = dispatch_group_create();
    
    for (ASDKModelFormField *formField in formFields) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            for (ASDKModelFormField *formFieldInContainer in formField.formFields) {
                [self preProcessFormField:formFieldInContainer
                        withDispatchGroup:group];
            }
        } else{
            [self preProcessFormField:formField
                    withDispatchGroup:group];
        }
    }
    
    // dispatch group finished
    dispatch_group_notify(group,dispatch_get_main_queue(),^{
        preProcessCompletionBlock(formFields, nil);
    });
    
}

- (void)preProcessFormField:(ASDKModelFormField *)formField
          withDispatchGroup:(dispatch_group_t)group {
    NSInteger representationType = ASDKModelFormFieldRepresentationTypeUndefined;
    
    // If dealing with read-only forms extract the representation type from the attached
    // form field params model
    if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
        representationType = formField.formFieldParams.representationType;
    } else {
        representationType = formField.representationType;
    }
    
    switch (representationType) {
        case ASDKModelFormFieldRepresentationTypeDropdown:
        case ASDKModelFormFieldRepresentationTypeRadio: {
            ASDKModelRestFormField *restFormField = (ASDKModelRestFormField *)formField;
            
            if ([restFormField respondsToSelector:@selector(restURL)] && restFormField.restURL) {
                // entering service group
                dispatch_group_enter(group);
                
                if (self.isStartForm) {
                    if (self.dynamicTableFieldID) {
                        [self.formNetworkServices fetchRestFieldValuesForStartFormWithProcessDefinitionID:self.processDefinitionID
                                                                                              withFieldID:self.dynamicTableFieldID
                                                                                             withColumnID:formField.modelID                                                                                              completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {
                                                                                                 
                                                                                                 formField.formFieldOptions = restFormFieldOptions;
                                                                                                 
                                                                                                 // leaving dispatch group
                                                                                                 dispatch_group_leave(group);
                                                                                             }];
                    } else {
                        [self.formNetworkServices fetchRestFieldValuesForStartFormWithProcessDefinitionID:self.processDefinitionID
                                                                                              withFieldID:formField.modelID
                                                                                          completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {
                                                                                              
                                                                                              formField.formFieldOptions = restFormFieldOptions;
                                                                                              
                                                                                              // leaving dispatch group
                                                                                              dispatch_group_leave(group);
                                                                                          }];
                    }
                } else {
                    if (self.dynamicTableFieldID) {
                        [self.formNetworkServices fetchRestFieldValuesForTaskWithID:self.taskID
                                                                        withFieldID:self.dynamicTableFieldID
                                                                       withColumnID:formField.modelID
                                                                    completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {

                                                                        formField.formFieldOptions = restFormFieldOptions;
                                                                        
                                                                        // leaving dispatch group
                                                                        dispatch_group_leave(group);
                                                                    }];
                    } else {
                        [self.formNetworkServices fetchRestFieldValuesForTaskWithID:self.taskID
                                                                        withFieldID:formField.modelID
                                                                    completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {
                                                                        
                                                                        formField.formFieldOptions = restFormFieldOptions;
                                                                        
                                                                        // leaving dispatch group
                                                                        dispatch_group_leave(group);
                                                                    }];
                    }
                }
            }
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeAmount:
            // display value
            if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
                ASDKModelAmountFormField *amountFormField = (ASDKModelAmountFormField *)formField;
                ASDKModelAmountFormField *amountFormFieldParams = (ASDKModelAmountFormField *)formField.formFieldParams;
                amountFormField.currency = amountFormFieldParams.currency;
                amountFormField.enableFractions = amountFormFieldParams.enableFractions;
            }
            break;
            
        case ASDKModelFormFieldRepresentationTypeHyperlink:
            // display value
            if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
                ASDKModelHyperlinkFormField *hyperlinkFormField = (ASDKModelHyperlinkFormField *)formField;
                ASDKModelHyperlinkFormField *hyperlinkFormFieldParams = (ASDKModelHyperlinkFormField *)formField.formFieldParams;
                if (hyperlinkFormFieldParams.hyperlinkURL) {
                    hyperlinkFormField.hyperlinkURL = hyperlinkFormFieldParams.hyperlinkURL;
                }
                if (hyperlinkFormFieldParams.displayText) {
                    hyperlinkFormField.displayText = hyperlinkFormFieldParams.displayText;
                }
            }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDynamicTable:
            // populate column definition form fields with values
            if (formField.values) {
                // Display value
                if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType &&
                    ASDKModelFormFieldRepresentationTypeDynamicTable == formField.formFieldParams.representationType &&
                    !((ASDKModelDynamicTableFormField *)formField).columnDefinitions) {
                    ASDKModelDynamicTableFormField *dynamicTableFormField = (ASDKModelDynamicTableFormField *)formField;
                    ASDKModelDynamicTableFormField *dynamicTableFormFieldParams = (ASDKModelDynamicTableFormField *)formField.formFieldParams;
                    dynamicTableFormField.columnDefinitions = dynamicTableFormFieldParams.columnDefinitions;
                    dynamicTableFormField.isTableEditable = dynamicTableFormFieldParams.isTableEditable;
                }
                
                NSMutableArray *newFormFieldValues = [[NSMutableArray alloc] init];
                ASDKModelDynamicTableFormField *dynamicTableFormField = (ASDKModelDynamicTableFormField *)formField;
                
                // create column definition dictionary for quick access
                NSMutableDictionary *columnFormFieldDict = [[NSMutableDictionary alloc] init];
                for (ASDKModelFormField *columnFormField in dynamicTableFormField.columnDefinitions) {
                    [columnFormFieldDict setValue:columnFormField
                                           forKey:columnFormField.modelID];
                }
                
                for (NSDictionary *rowValues in dynamicTableFormField.values) {
                    // initialize array with 'column definition template'
                    // needed for placing objects at specified index later
                    NSMutableArray *newRowFormFieldValues = [[NSMutableArray alloc] initWithCapacity:dynamicTableFormField.columnDefinitions.count];
                    
                    for (ASDKModelFormField *columnDefinitionTemplate in dynamicTableFormField.columnDefinitions) {
                        ASDKModelFormField *newRowFormFieldValue = [columnDefinitionTemplate copy];
                        if (ASDKModelFormFieldRepresentationTypeReadOnly == dynamicTableFormField.representationType) {
                            ASDKModelFormField *formFieldParams = nil;
                            if (ASDKModelFormFieldRepresentationTypeAmount == columnDefinitionTemplate.representationType) {
                                formFieldParams = [ASDKModelAmountFormField new];
                                formFieldParams.fieldName = newRowFormFieldValue.fieldName;
                            } else {
                                formFieldParams = [ASDKModelFormField new];
                            }
                            formFieldParams.representationType = newRowFormFieldValue.representationType;
                            formFieldParams.fieldName = newRowFormFieldValue.fieldName;
                            newRowFormFieldValue.formFieldParams = formFieldParams;
                            newRowFormFieldValue.representationType = ASDKModelFormFieldRepresentationTypeReadOnly;
                        }
                        [newRowFormFieldValues addObject:newRowFormFieldValue];
                    }
                    
                    // create new values based on column definition 'template'
                    for (NSString *columnId in rowValues) {
                        NSArray *columnDefinitionValues = [NSArray arrayWithObject:rowValues[columnId]];
                        ASDKModelFormField *columnDefinitionWithValue = [[columnFormFieldDict valueForKey:columnId] copy];
                        
                        if (ASDKModelFormFieldRepresentationTypeReadOnly == dynamicTableFormField.representationType) {
                            ASDKModelFormField *formFieldParams = nil;
                            if (ASDKModelFormFieldRepresentationTypeAmount == columnDefinitionWithValue.representationType) {
                                formFieldParams = [ASDKModelAmountFormField new];
                                formFieldParams.fieldName = columnDefinitionWithValue.fieldName;
                            } else {
                                formFieldParams = [ASDKModelFormField new];
                            }
                            formFieldParams.representationType = columnDefinitionWithValue.representationType;
                            formFieldParams.fieldName = columnDefinitionWithValue.fieldName;
                            columnDefinitionWithValue.formFieldParams = formFieldParams;
                            
                            if (!dynamicTableFormField.isTableEditable) {
                                columnDefinitionWithValue.representationType = ASDKModelFormFieldRepresentationTypeReadOnly;
                            }
                        }
                        
                        columnDefinitionWithValue.values = columnDefinitionValues;
                        
                        NSInteger newRowFormFieldValuesIndex = [self getIndexFromObjectProperty:columnId
                                                                                        inArray:dynamicTableFormField.columnDefinitions];
                        if (newRowFormFieldValuesIndex != NSNotFound) {
                            [newRowFormFieldValues replaceObjectAtIndex:newRowFormFieldValuesIndex
                                                             withObject:columnDefinitionWithValue];
                        }
                    }
                    [newFormFieldValues addObject:newRowFormFieldValues];
                }
                
                formField.values = [NSArray arrayWithArray:newFormFieldValues];
            }
            break;
            
        default:
            break;
    }
}

- (NSInteger)getIndexFromObjectProperty:(NSString *)property
                                inArray:(NSArray *)myArray {
    return [myArray indexOfObjectPassingTest:
            ^(id obj, NSUInteger idx, BOOL *stop) {
                BOOL res;
                ASDKModelFormField *modelFormField = (ASDKModelFormField *) obj;
                if ([property isEqualToString:modelFormField.modelID]) {
                    res = YES;
                    *stop = YES;
                } else {
                    res = NO;
                }
                return res;
            }];
}

@end
