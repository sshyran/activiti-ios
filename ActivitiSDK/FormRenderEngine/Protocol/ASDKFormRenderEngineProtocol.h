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

#import <UIKit/UIKit.h>

@class ASDKModelFormDescription,
ASDKModelFormDescription,
ASDKFormNetworkServices,
ASDKModelTask,
ASDKModelProcessDefinition,
ASDKModelProcessInstance,
ASDKFormFieldValueRequestRepresentation,
ASDKFormPreProcessor;

typedef void  (^ASDKFormRenderEngineSetupCompletionBlock) (UICollectionViewController *formController, NSError *error);
typedef void  (^ASDKFormRenderEngineCompletionBlock) (BOOL isFormCompleted, NSError *error);
typedef void  (^ASDKStartFormRenderEngineCompletionBlock) (ASDKModelProcessInstance *processInstance, NSError *error);

@protocol ASDKFormRenderEngineProtocol <NSObject>

/**
 *  Holds a refference to the current form description begin used to create
 *  the form view.
 *  NOTE: The property is declared as a readonly to force interaction with the
 *        form description to be made via protocol declared methods thus making
 *        the process safer.
 */
@property (strong, nonatomic, readonly) ASDKModelFormDescription *currenFormDescription;

/**
 *  Holds a refference to the form network service used in conjucture with the 
 *  convenience setup method. 
 *  NOTE: See the setupWithTaskModel:renderCompletionBlock:formCompletionBlock: 
 *  method for details
 */
@property (strong, nonatomic) ASDKFormNetworkServices *formNetworkServices;

@property (strong, nonatomic) ASDKFormPreProcessor *formPreProcessor;

/**
 *  Designated setup method for the form render engine class.
 *
 *  @param formDescription Description object containing form models that will be
 *                         displayed in the form view
 *  @return                A collection view controller instance containing the
 *                         the rendered form view
 */
- (UICollectionViewController *)setupWithFormDescription:(ASDKModelFormDescription *)formDescription;

/**
 *  Setup method for dynamic table rows
 *
 *  @param formDescription Description object containing form models that will be
 *                         displayed in the form view
 *  @return                A collection view controller instance containing the
 *                         the rendered form view
 */
- (UICollectionViewController *)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields;

/**
 *  Designated setup method for the form render engine class when it is used
 *  to show the form associated to a task. This method relies on the internal
 *  workings of the form render engine to make the API network calls on your 
 *  behalf and you will be provided with an instance of a collection view controller 
 *  through a completion block.
 *
 *  @param task                  Task object containing the mandatory task ID 
 *                               property.
 *  @param renderCompletionBlock Completion block providing a form controller
 *                               containing the visual representation of the
 *                               form view and additional error reason
 *  @param formCompletionBlock   Completion block providing information on
 *                               whether the form has been successfully
 *                               completed  or not and an additional error reason
 *
 */
- (void)setupWithTaskModel:(ASDKModelTask *)task
     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock;

/**
 *  Designated setup method for the form render engine class when it is used to
 *  show the start form of a process instance. This method relies on the internal
 *  workings of the form render engine to make the API network calls on your behalf
 *  and you will be provided with an instance of a collection view controller through
 *  a completion block.
 *
 *  @param processDefinition     Process definition object containing the mandatory 
 *                               process definition ID property
 *  @param renderCompletionBlock Completion block providing a form controller
 *                               containing the visual representation of the
 *                               form view and additional error reason
 *  @param formCompletionBlock   Completion block providing information on
 *                               whether the form has been successfully
 *                               completed  or not and an additional error reason
 */
- (void)setupWithProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
             renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
               formCompletionBlock:(ASDKStartFormRenderEngineCompletionBlock)formCompletionBlock;

/**
 *  Designated setup method for the form render engine class when it is used
 *  to show the dynamic table row associated to a task. This method relies on the internal
 *  workings of the form render engine to make the API network calls on your
 *  behalf and you will be provided with an instance of a collection view controller
 *  through a completion block.
 *
 *  @param dynamicTableRowFormFields    Array containing the columns (formfields) of a 
 *                                      dynamic table row
 *  @param dynamicTableFormFieldID      The ID of the dynamic table
 *  @param task                         Task object containing the mandatory task ID
 *                                      property.
 *  @param renderCompletionBlock        Completion block providing a form controller
 *                                      containing the visual representation of the
 *                                      form view and additional error reason
 *  @param formCompletionBlock          Completion block providing information on
 *                                      whether the form has been successfully
 *                                      completed  or not and an additional error reason
 *
 */
- (void)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields
                   dynamicTableFormFieldID:(NSString *)dynamicTableFormFieldID
                                 taskModel:(ASDKModelTask *)task
                     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
                       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock;

/**
 *  Designated setup method for the form render engine class when it is used
 *  to show the dynamic table row associated to a task. This method relies on the internal
 *  workings of the form render engine to make the API network calls on your
 *  behalf and you will be provided with an instance of a collection view controller
 *  through a completion block.
 *
 *  @param dynamicTableRowFormFields    Array containing the columns (formfields) of a
 *                                      dynamic table row
 *  @param dynamicTableFormFieldID      The ID of the dynamic table
 *  @param processDefinition            Process definition object containing the mandatory
 *                                      process definition ID property
 *  @param renderCompletionBlock        Completion block providing a form controller
 *                                      containing the visual representation of the
 *                                      form view and additional error reason
 *  @param formCompletionBlock          Completion block providing information on
 *                                      whether the form has been successfully
 *                                      completed  or not and an additional error reason
 *
 */
- (void)setupWithDynamicTableRowFormFields:(NSArray *)dynamicTableRowFormFields
                   dynamicTableFormFieldID:(NSString *)dynamicTableFormFieldID
                         processDefinition:(ASDKModelProcessDefinition *)processDefinition
                     renderCompletionBlock:(ASDKFormRenderEngineSetupCompletionBlock)renderCompletionBlock
                       formCompletionBlock:(ASDKFormRenderEngineCompletionBlock)formCompletionBlock;
/**
 *  Performs a form completion request given a form field value request representation object.
 *  Discussion: The form field value request representation object is generated by the form's
 *  data source object and contains information called form field metadata that's basically
 *  information that the user entered in the form fields.
 *
 *  @param formFieldValueRequestRepresentation Request representation object
 */
- (void)completeFormWithFormFieldValueRequestRepresentation:(ASDKFormFieldValueRequestRepresentation *)formFieldValueRequestRepresentation;

/**
 *  Requests the engine to perform a cleanup operation and prepare for reuse on the next 
 *  incoming form description.
 */
- (void)performEngineCleanup;

@end
