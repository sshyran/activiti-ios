/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import "ASDKModelBase.h"

@interface ASDKModelFormDescription : ASDKModelBase

@property (strong, nonatomic) NSString  *processDefinitionID;
@property (strong, nonatomic) NSString  *processDefinitionName;
@property (strong, nonatomic) NSString  *processDefinitionKey;
@property (strong, nonatomic) NSArray   *formFields;
@property (strong, nonatomic) NSArray   *formOutcomes;
@property (strong, nonatomic) NSArray   *formTabs;
@property (strong, nonatomic) NSArray   *formVariables;

- (BOOL)doesFormDescriptionContainSupportedFormFields;

@end
