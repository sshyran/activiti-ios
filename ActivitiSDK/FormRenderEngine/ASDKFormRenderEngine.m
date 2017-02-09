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

#import "ASDKFormRenderEngine.h"
@import UIKit;

// Constants
#import "ASDKFormRenderEngineConstants.h"

// Controllers
#import "ASDKFormCollectionViewController.h"

// Models
#import "ASDKFormFieldValueRequestRepresentation.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormField.h"
#import "ASDKModelRestFormField.h"
#import "ASDKModelFormDescription.h"
#import "ASDKModelFormTabDescription.h"

// Managers
#import "ASDKFormRenderDataSource.h"
#import "ASDKDynamicTableRenderDataSource.h"
#import "ASDKFormEngineActionHandler.h"

#import "ASDKFormPreProcessor.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKFormRenderEngine ()

/**
 *  Property meant to hold a reference to the form data source
 */
@property (strong, nonatomic) ASDKFormRenderDataSource                  *dataSource;

/**
 *  Property meant to hold a reference to the form completion block invoked
 *  when the user completes a form.
 */
@property (strong, nonatomic) ASDKFormRenderEngineCompletionBlock       formCompletionBlock;

/**
 *  Property meant to hold a reference to the start form completion block invoked
 *  when the user completes the a process instance associated start form.
 */
@property (strong, nonatomic) ASDKStartFormRenderEngineCompletionBlock  startFormCompletionBlock;

/**
 *  Property meant to hold a reference to the save form completion block invoked
 *  when the user saves a form.
 */
@property (strong, nonatomic) ASDKFormRenderEngineSaveBlock             saveFormCompletionBlock;

@end

@implementation ASDKFormRenderEngine


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.actionHandler = [ASDKFormEngineActionHandler new];
    }
    
    return self;
}


#pragma mark -
#pragma mark ASDKFormRenderEngine Protocol

- (UICollectionViewController *)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields {
    // Load from nib the form collection view controller and link it's data source
    UIStoryboard *formStoryboard = [UIStoryboard storyboardWithName:kASDKFormStoryboardBundleName
                                                             bundle:[NSBundle bundleForClass:[ASDKFormCollectionViewController class]]];
    ASDKFormCollectionViewController *formCollectionViewController = [formStoryboard instantiateViewControllerWithIdentifier:kASDKStoryboardIDCollectionController];
    formCollectionViewController.dataSource = self.dataSource;
    formCollectionViewController.renderDelegate = self;
    
    return formCollectionViewController;
}

- (void)setupWithTaskModel:(ASDKModelTask *)task
     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock
             formSaveBlock:(ASDKFormRenderEngineSaveBlock)formSaveBlock {
    // Check mandatory parameteres
    NSParameterAssert(task);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    NSParameterAssert(formSaveBlock);
    
    self.task = task;
    self.formCompletionBlock = formCompletionBlock;
    self.saveFormCompletionBlock = formSaveBlock;
    
    [self.formNetworkServices
     fetchFormForTaskWithID:task.modelID
     completionBlock:^(ASDKModelFormDescription *formDescription, NSError *error) {
         // Check for form description errors first
         if (error) {
             renderCompletionBlock(nil, error);
             return;
         }
         
         self.formPreProcessor = [ASDKFormPreProcessor new];
         self.formPreProcessor.formNetworkServices = self.formNetworkServices;
         
         [self.formPreProcessor setupWithTaskID:task.modelID
                                 withFormFields:formDescription.formFields
                        withDynamicTableFieldID:nil
                      preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                          formDescription.formFields = processedFormFields;
                          
                          // Set up the data source for the form collection view controller
                          self.dataSource = [[ASDKFormRenderDataSource alloc] initWithTaskFormDescription:formDescription];
                          self.dataSource.isReadOnlyForm = self.task.endDate ? YES : NO;
                          
                          // Always dispath on the main queue results related to the form view
                          dispatch_async(dispatch_get_main_queue(), ^{
                              
                              UICollectionViewController *formCollectionViewController = [self prepareWithFormDescription:formDescription];
                              
                              // First check for integrity errors
                              if (!formCollectionViewController) {
                                  NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Setup operation for form controller failed.",
                                                             NSLocalizedFailureReasonErrorKey     : @"The operation could not be completed because the form render engine could not generate the form view.",
                                                             NSLocalizedRecoverySuggestionErrorKey: @"Please check your form description model and make sure it has all the information needed to render."
                                                             };
                                  NSError *error = [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                                                                       code:kASDKFormRenderEngineSetupErrorCode
                                                                   userInfo:userInfo];
                                  
                                  renderCompletionBlock(nil, error);
                              } else {
                                  renderCompletionBlock(formCollectionViewController, nil);
                              }
                          });
                      }];
     }];
}

- (void)setupWithProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
             renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
               formCompletionBlock:(ASDKStartFormRenderEngineCompletionBlock)formCompletionBlock {
    NSParameterAssert(processDefinition);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    
    self.processDefinition = processDefinition;
    self.startFormCompletionBlock = formCompletionBlock;
    
    [self.formNetworkServices
     startFormForProcessDefinitionID:processDefinition.modelID
     completionBlock:^(ASDKModelFormDescription *formDescription, NSError *error) {
         // Check for form description errors first
         if (error) {
             renderCompletionBlock(nil, error);
         }
         
         self.formPreProcessor = [ASDKFormPreProcessor new];
         self.formPreProcessor.formNetworkServices = self.formNetworkServices;
         
         [self.formPreProcessor setupWithProcessDefinitionID:processDefinition.modelID
                                              withFormFields:formDescription.formFields
                                     withDynamicTableFieldID:nil
                                   preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                                       formDescription.formFields = processedFormFields;
                                       
                                       // Set up the data source for the form collection view controller
                                       self.dataSource = [[ASDKFormRenderDataSource alloc] initWithProcessDefinitionFormDescription:formDescription];
                                       self.dataSource.isReadOnlyForm = self.task.endDate ? YES : NO;
                                       
                                       // Always dispath on the main queue results related to the form view
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           UICollectionViewController *formCollectionViewController = [self prepareWithFormDescription:formDescription];
                                           
                                           // First check for integrity errors
                                           if (!formCollectionViewController) {
                                               NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Setup operation for form controller failed.",
                                                                          NSLocalizedFailureReasonErrorKey     : @"The operation could not be completed because the form render engine could not generate the form view.",
                                                                          NSLocalizedRecoverySuggestionErrorKey: @"Please check your form description model and make sure it has all the information needed to render."
                                                                          };
                                               NSError *error = [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                                                                                    code:kASDKFormRenderEngineSetupErrorCode
                                                                                userInfo:userInfo];
                                               
                                               renderCompletionBlock(nil, error);
                                           } else {
                                               renderCompletionBlock(formCollectionViewController, nil);
                                           }
                                       });
                                   }];
     }];
}

- (void)setupWithProcessInstance:(ASDKModelProcessInstance *)processInstance
           renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock {
    NSParameterAssert(processInstance);
    NSParameterAssert(renderCompletionBlock);
    
    self.processInstance = processInstance;
    
    [self.formNetworkServices
     startFormForProcessInstanceID:processInstance.modelID
     completionBlock:^(ASDKModelFormDescription *formDescription, NSError *error) {
         // Check for form description errors first
         if (error) {
             renderCompletionBlock(nil, error);
         }
         
         self.formPreProcessor = [ASDKFormPreProcessor new];
         self.formPreProcessor.formNetworkServices = self.formNetworkServices;
         
         [self.formPreProcessor setupWithProcessDefinitionID:processInstance.processDefinitionID
                                              withFormFields:formDescription.formFields
                                     withDynamicTableFieldID:nil
                                   preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                                       formDescription.formFields = processedFormFields;
                                       
                                       // Set up the data source for the form collection view controller
                                       self.dataSource = [[ASDKFormRenderDataSource alloc] initWithProcessDefinitionFormDescription:formDescription];
                                       self.dataSource.isReadOnlyForm = YES;
                                       
                                       // Always dispath on the main queue results related to the form view
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           UICollectionViewController *formCollectionViewController = [self prepareWithFormDescription:formDescription];
                                           
                                           // First check for integrity errors
                                           if (!formCollectionViewController) {
                                               NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Setup operation for form controller failed.",
                                                                          NSLocalizedFailureReasonErrorKey     : @"The operation could not be completed because the form render engine could not generate the form view.",
                                                                          NSLocalizedRecoverySuggestionErrorKey: @"Please check your form description model and make sure it has all the information needed to render."
                                                                          };
                                               NSError *error = [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                                                                                    code:kASDKFormRenderEngineSetupErrorCode
                                                                                userInfo:userInfo];
                                               
                                               renderCompletionBlock(nil, error);
                                           } else {
                                               renderCompletionBlock(formCollectionViewController, nil);
                                           }
                                       });
                                   }];
     }];
}

- (void)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields
                   dynamicTableFormFieldID:(NSString *)dynamicTableFormFieldID
                                 taskModel:(ASDKModelTask *)task
                     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
                       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock {
    // Check mandatory parameteres
    NSParameterAssert(dynamicTableRowFormFields);
    NSParameterAssert(dynamicTableFormFieldID);
    NSParameterAssert(task);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    
    self.task = task;
    self.formCompletionBlock = formCompletionBlock;
    
    // Set up the data source for the form collection view controller
    self.dataSource = [[ASDKDynamicTableRenderDataSource alloc] initWithFormFields:dynamicTableRowFormFields];
    self.dataSource.isReadOnlyForm = self.task.endDate ? YES : NO;
    self.formPreProcessor = [ASDKFormPreProcessor new];
    self.formPreProcessor.formNetworkServices = self.formNetworkServices;
    
    [self.formPreProcessor setupWithTaskID:task.modelID
                            withFormFields:dynamicTableRowFormFields
                   withDynamicTableFieldID:dynamicTableFormFieldID
                 preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                     // Always dispath on the main queue results related to the form views
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         UICollectionViewController *formCollectionViewController = [self setupWithDynamicTableRowFormFields:processedFormFields];
                         // First check for integrity errors
                         if (!formCollectionViewController) {
                             NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Setup operation for form controller failed.",
                                                        NSLocalizedFailureReasonErrorKey     : @"The operation could not be completed because the form render engine could not generate the form view.",
                                                        NSLocalizedRecoverySuggestionErrorKey: @"Please check your form description model and make sure it has all the information needed to render."
                                                        };
                             NSError *error = [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                                                                  code:kASDKFormRenderEngineSetupErrorCode
                                                              userInfo:userInfo];
                             
                             renderCompletionBlock(nil, error);
                         } else {
                             renderCompletionBlock(formCollectionViewController, nil);
                         }
                     });
                 }];
}

- (void)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields
                   dynamicTableFormFieldID:(NSString *)dynamicTableFormFieldID
                         processDefinition:(ASDKModelProcessDefinition *)processDefinition
                     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
                       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock {
    // Check mandatory parameteres
    NSParameterAssert(dynamicTableRowFormFields);
    NSParameterAssert(processDefinition);
    NSParameterAssert(dynamicTableFormFieldID);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    
    self.processDefinition = processDefinition;
    self.formCompletionBlock = formCompletionBlock;
    
    // Set up the data source for the form collection view controller
    self.dataSource = [[ASDKDynamicTableRenderDataSource alloc] initWithFormFields:dynamicTableRowFormFields];
    self.dataSource.isReadOnlyForm = self.task.endDate ? YES : NO;
    self.formPreProcessor = [ASDKFormPreProcessor new];
    self.formPreProcessor.formNetworkServices = self.formNetworkServices;
    
    [self.formPreProcessor setupWithProcessDefinitionID:processDefinition.modelID
                                         withFormFields:dynamicTableRowFormFields
                                withDynamicTableFieldID:dynamicTableFormFieldID
                              preProcessCompletionBlock:^(NSArray *processedFormFields, NSError *error) {
                                  // Always dispath on the main queue results related to the form views
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      
                                      UICollectionViewController *formCollectionViewController = [self setupWithDynamicTableRowFormFields:processedFormFields];
                                      
                                      // First check for integrity errors
                                      if (!formCollectionViewController) {
                                          NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Setup operation for form controller failed.",
                                                                     NSLocalizedFailureReasonErrorKey     : @"The operation could not be completed because the form render engine could not generate the form view.",
                                                                     NSLocalizedRecoverySuggestionErrorKey: @"Please check your form description model and make sure it has all the information needed to render."
                                                                     };
                                          NSError *error = [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                                                                               code:kASDKFormRenderEngineSetupErrorCode
                                                                           userInfo:userInfo];
                                          
                                          renderCompletionBlock(nil, error);
                                      } else {
                                          renderCompletionBlock(formCollectionViewController, nil);
                                      }
                                  });
                              }];
}

- (UICollectionViewController *)setupWithTabFormDescription:(ASDKModelFormTabDescription *)formDescription {
    self.dataSource = [[ASDKFormRenderDataSource alloc] initWithTabFormDescription:formDescription];
    self.dataSource.isReadOnlyForm = formDescription.isReadOnlyForm;
    return [self prepareWithFormDescription:formDescription];
}

- (void)completeFormWithFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValueRequestRepresentation {
    __weak typeof(self) weakSelf = self;
    
    // Check which complete method should be used i.e tasks or process definitions based on the
    // initialised content
    if (self.task) {
        [self.formNetworkServices completeFormForTaskID:self.task.modelID
                withFormFieldValueRequestRepresentation:formFieldValueRequestRepresentation
                                        completionBlock:^(BOOL isFormCompleted, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            if (strongSelf.formCompletionBlock) {
                                                strongSelf.formCompletionBlock(isFormCompleted, error);
                                            }
                                            
                                            // After a successfull form completion clean up the engine
                                            // and prepare it for reuse
                                            if (isFormCompleted) {
                                                [self performEngineCleanup];
                                            }
                                        }];
    } else if (self.processDefinition) {
        [self.formNetworkServices completeFormForProcessDefinition:self.processDefinition
                          withFormFieldValuesRequestrepresentation:formFieldValueRequestRepresentation
                                                   completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                                       __strong typeof(self) strongSelf = weakSelf;
                                                       
                                                       if (strongSelf.startFormCompletionBlock) {
                                                           strongSelf.startFormCompletionBlock(processInstance, error);
                                                       }
                                                       
                                                       // After a successfull form completion clean up the engine
                                                       // and prepare it for reuse
                                                       if (processInstance) {
                                                           [self performEngineCleanup];
                                                       }
                                                   }];
    }
    
}

- (void)saveFormWithFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValueRequestRepresentation {
    __weak typeof(self) weakSelf = self;
    
    [self.formNetworkServices saveFormForTaskID:self.task.modelID
       withFormFieldValuesRequestrepresentation:formFieldValueRequestRepresentation
                                completionBlock:^(BOOL isFormSaved, NSError *error) {
                                    __strong typeof(self) strongSelf = weakSelf;
                                    
                                    if (strongSelf.saveFormCompletionBlock) {
                                        strongSelf.saveFormCompletionBlock(isFormSaved, error);
                                    }
                                }];
}

- (void)performEngineCleanup {
    self.task = nil;
    self.processDefinition = nil;
    self.dataSource = nil;
    self.formCompletionBlock = nil;
    self.startFormCompletionBlock = nil;
}


#pragma mark -
#pragma mark Private API

- (UICollectionViewController *)prepareWithFormDescription:(ASDKModelFormDescription *)formDescription {
    // Load from nib the form collection view controller and link it's data source
    UIStoryboard *formStoryboard = [UIStoryboard storyboardWithName:kASDKFormStoryboardBundleName
                                                             bundle:[NSBundle bundleForClass:[ASDKFormCollectionViewController class]]];
    ASDKFormCollectionViewController *formCollectionViewController = [formStoryboard instantiateViewControllerWithIdentifier:kASDKStoryboardIDCollectionController];
    self.dataSource.delegate = formCollectionViewController;
    formCollectionViewController.dataSource = self.dataSource;
    formCollectionViewController.renderDelegate = self;
    
    return formCollectionViewController;
}

@end
