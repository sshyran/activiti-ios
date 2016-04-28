/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti Mobile iOS App.
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

#import "AFAFormServices.h"
@import ActivitiSDK;

// Models
#import "AFAGenericFilterModel.h"

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAFormServices ()

@property (strong, nonatomic) dispatch_queue_t                      formUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKFormNetworkServices               *formNetworkService;
@property (strong, nonatomic) ASDKFormRenderEngine                  *formRenderEngine;

@end

@implementation AFAFormServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.formUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.formNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormNetworkServiceProtocol)];
        self.formNetworkService.resultsQueue = self.formUpdatesProcessingQueue;
        self.formRenderEngine = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormRenderEngineProtocol)];
        self.formRenderEngine.formNetworkServices = self.formNetworkService;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

#pragma mark -
#pragma mark Form requests

- (UICollectionViewController *)requestSetupWithFormDescription:(ASDKModelFormDescription *)formDescription {
    NSParameterAssert(formDescription);
    
    UICollectionViewController *formViewController = [self.formRenderEngine setupWithFormDescription:formDescription];
    
    AFALogVerbose(@"Form render engine %@ with form description associated with process definition :%@", formViewController ? @"did set up successfully" : @"failed to set up", formDescription.processDefinitionName);
    
    return formViewController;
}

- (void)requestSetupWithTaskModel:(ASDKModelTask *)task
            renderCompletionBlock:(AFAFormServicesEngineSetupCompletionBlock)renderCompletionBlock
              formCompletionBlock:(AFAFormServicesEngineCompletionBlock)formCompletionBlock
                    formSaveBlock:(AFAFormServicesEngineSaveBlock)formSaveBlock {
    NSParameterAssert(task);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    NSParameterAssert(formSaveBlock);
    
    [self.formRenderEngine setupWithTaskModel:task
                        renderCompletionBlock:^(UICollectionViewController<ASDKFormControllerNavigationProtocol> *formController, NSError *error) {
                            if (formController && !error) {
                                AFALogVerbose(@"Received form controller for task:%@ (ID:%@)", task.name, task.instanceID);
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    renderCompletionBlock(formController, nil);
                                });
                            } else {
                                AFALogError(@"An error occured while requesting the form controller for task %@ (ID:%@).Reason:%@", task.name, task.instanceID, error.localizedDescription);
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    renderCompletionBlock(nil, error);
                                });
                            }
                        } formCompletionBlock:^(BOOL isFormCompleted, NSError *error) {
                            if (!error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    formCompletionBlock(isFormCompleted, error);
                                });
                            } else {
                                AFALogError(@"An error occured while requesting the completion of the form for task definition %@ (ID:%@). Reason:%@", task.name, task.instanceID, error.localizedDescription);
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    formCompletionBlock(NO, error);
                                });
                            }
                        } formSaveBlock:^(BOOL isFormSaved, NSError *error) {
                            if (!error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    formSaveBlock(isFormSaved, nil);
                                });
                            } else {
                                AFALogError(@"An error occured while saving the form for task %@ (ID:%@). Reason:%@", task.name, task.instanceID, error.localizedDescription);
                            }
                        }];
}

- (void)requestSetupWithProcessDefinition:(ASDKModelProcessDefinition *)processDefinition
                    renderCompletionBlock:(AFAFormServicesEngineSetupCompletionBlock)renderCompletionBlock
                      formCompletionBlock:(AFAStartFormServicesEngineCompletionBlock)formCompletionBlock {
    NSParameterAssert(processDefinition);
    NSParameterAssert(renderCompletionBlock);
    NSParameterAssert(formCompletionBlock);
    
    [self.formRenderEngine setupWithProcessDefinition:processDefinition
                                renderCompletionBlock:^(UICollectionViewController<ASDKFormControllerNavigationProtocol> *formController, NSError *error) {
                                    if (formController && !error) {
                                        AFALogVerbose(@"Received form controller for process definition:%@ (ID:%@)", processDefinition.name, processDefinition.instanceID);
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            renderCompletionBlock(formController, nil);
                                        });
                                    } else {
                                        AFALogError(@"An error occured while requesting the form controller for process definition %@ (ID:%@).Reason:%@", processDefinition.name, processDefinition.instanceID, error.localizedDescription);
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            renderCompletionBlock(nil, error);
                                        });
                                    }
                                } formCompletionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                    if (!error) {
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            formCompletionBlock(processInstance, error);
                                        });
                                    } else {
                                        AFALogVerbose(@"An error occured while requesting the completion of the form for process definition %@ (ID:%@). Reason:%@", processDefinition.name, processDefinition.instanceID, error.localizedDescription);
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            formCompletionBlock(nil, error);
                                        });
                                    }
                                }];
}

- (void)requestEngineCleanup {
    [self.formRenderEngine performEngineCleanup];
}

@end
