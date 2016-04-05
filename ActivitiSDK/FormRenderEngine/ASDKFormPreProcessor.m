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

#import "ASDKFormPreProcessor.h"
#import "ASDKModelFormField.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelRestFormField.h"
#import "ASDKModelAmountFormField.h"
#import "ASDKModelHyperlinkFormField.h"

@interface ASDKFormPreProcessor ()

@property (strong, nonatomic) NSString                              *taskID;
@property (strong, nonatomic) NSString                              *processDefinitionID;
@property (strong, nonatomic) ASDKModelFormDescription              *formDescription;
@property (assign, nonatomic) BOOL                                  isStartForm;

@end

@implementation ASDKFormPreProcessor

- (void)setupWithTaskID:(NSString *)taskID
withFormDescriptionModel:(ASDKModelFormDescription *)formDescription
preProcessCompletionBlock:(ASDKFormPreProcessCompletionBlock)preProcessCompletionBlock {
    
    NSParameterAssert(taskID);
    NSParameterAssert(formDescription);
    NSParameterAssert(preProcessCompletionBlock);
    
    self.isStartForm = NO;
    self.taskID = taskID;
    self.formDescription = formDescription;
    
    // create dispatch group
    // all async calls for augmenting the form description need to be completed before
    // the completion block is returned
    dispatch_group_t group = dispatch_group_create();

    for (ASDKModelFormField *formField in formDescription.formFields) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            NSArray *containerFormFields = formField.formFields;
            [self preProcessFormFields:containerFormFields
                     withDispatchGroup:group];
        }
    }
    
    // dispatch group finished
    dispatch_group_notify(group,dispatch_get_main_queue(),^{
        preProcessCompletionBlock(formDescription, nil);
    });

}

- (void)setupWithProcessDefinitionID:(NSString *)processDefinitionID
            withFormDescriptionModel:(ASDKModelFormDescription *)formDescription
           preProcessCompletionBlock:(ASDKFormPreProcessCompletionBlock)preProcessCompletionBlock {
    
    NSParameterAssert(processDefinitionID);
    NSParameterAssert(formDescription);
    NSParameterAssert(preProcessCompletionBlock);
    
    self.isStartForm = YES;
    self.processDefinitionID = processDefinitionID;
    self.formDescription = formDescription;
    
    // create dispatch group
    // all async calls for augmenting the form description need to be completed before
    // the completion block is returned
    dispatch_group_t group = dispatch_group_create();
    
    for (ASDKModelFormField *formField in formDescription.formFields) {
        if (ASDKModelFormFieldTypeContainer == formField.fieldType) {
            NSArray *containerFormFields = formField.formFields;
            [self preProcessFormFields:containerFormFields
                     withDispatchGroup:group];
        }
    }
    
    // dispatch group finished
    dispatch_group_notify(group,dispatch_get_main_queue(),^{
        preProcessCompletionBlock(formDescription, nil);
    });
    
}

- (void)preProcessFormFields:(NSArray *)formFieldsArr
           withDispatchGroup:(dispatch_group_t) group {
    
    for (ASDKModelFormField *formField in formFieldsArr) {
        
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
                ASDKModelRestFormField *restFormField = (ASDKModelRestFormField *) formField;
                
                if ([restFormField respondsToSelector:@selector(restURL)] && restFormField.restURL) {
                    
                    // entering service group
                    dispatch_group_enter(group);
                    
                    if (self.isStartForm) {
                        
                        [self.formNetworkServices fetchRestFieldValuesForStartFormWithProcessDefinitionID:self.processDefinitionID
                                                                                              withFieldID:formField.instanceID
                                                                                          completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {
                                                                                              
                                                                                              formField.formFieldOptions = restFormFieldOptions;
                                                                                              
                                                                                              // leaving dispatch group
                                                                                              dispatch_group_leave(group);
                                                                                          }];
                    } else {
                        
                        [self.formNetworkServices fetchRestFieldValuesForTaskWithID:self.taskID
                                                                        withFieldID:formField.instanceID
                                                                    completionBlock:^(NSArray *restFormFieldOptions, NSError *error) {
                                                                        
                                                                        formField.formFieldOptions = restFormFieldOptions;
                                                                        
                                                                        // leaving dispatch group
                                                                        dispatch_group_leave(group);
                                                                    }];
                    }
                }
            }
                break;
                
            case ASDKModelFormFieldRepresentationTypeAmount:
                // display value
                if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
                    ASDKModelAmountFormField *amountFormField = (ASDKModelAmountFormField *) formField;
                    ASDKModelAmountFormField *amountFormFieldParams =  (ASDKModelAmountFormField *) formField.formFieldParams;
                    amountFormField.currency = amountFormFieldParams.currency;
                    amountFormField.enableFractions = amountFormFieldParams.enableFractions;
                }
                break;
                
            case ASDKModelFormFieldRepresentationTypeHyperlink:
                // display value
                if (ASDKModelFormFieldRepresentationTypeReadOnly == formField.representationType) {
                    ASDKModelHyperlinkFormField *hyperlinkFormField = (ASDKModelHyperlinkFormField *) formField;
                    ASDKModelHyperlinkFormField *hyperlinkFormFieldParams =  (ASDKModelHyperlinkFormField *) formField.formFieldParams;
                    hyperlinkFormField.hyperlinkURL = hyperlinkFormFieldParams.hyperlinkURL;
                    hyperlinkFormField.displayText = hyperlinkFormFieldParams.displayText;
                }
                break;
                
            default:
                break;
        }
        
    }
}

@end
