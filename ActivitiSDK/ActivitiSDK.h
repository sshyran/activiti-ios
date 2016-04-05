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

// Bootstrap
#import <ActivitiSDK/ASDKBootstrap.h>

// Model imports
#import <ActivitiSDK/ASDKModelServerConfiguration.h>
#import <ActivitiSDK/ASDKBaseRequestRepresentation.h>
#import <ActivitiSDK/ASDKPagingRequestRepresentation.h>
#import <ActivitiSDK/ASDKTaskRequestRepresentation.h>
#import <ActivitiSDK/ASDKFilterRequestRepresentation.h>
#import <ActivitiSDK/ASDKTaskUpdateRequestRepresentation.h>
#import <ActivitiSDK/ASDKFilterListRequestRepresentation.h>
#import <ActivitiSDK/ASDKUserRequestRepresentation.h>
#import <ActivitiSDK/ASDKStartProcessRequestRepresentation.h>
#import <ActivitiSDK/ASDKTaskListQuerryRequestRepresentation.h>
#import <ActivitiSDK/ASDKTaskCreationRequestRepresentation.h>

#import <ActivitiSDK/ASDKModelApp.h>
#import <ActivitiSDK/ASDKModelTask.h>
#import <ActivitiSDK/ASDKModelPaging.h>
#import <ActivitiSDK/ASDKModelFilter.h>
#import <ActivitiSDK/ASDKModelProfile.h>
#import <ActivitiSDK/ASDKModelContent.h>
#import <ActivitiSDK/ASDKModelComment.h>
#import <ActivitiSDK/ASDKModelFileContent.h>
#import <ActivitiSDK/ASDKModelFormDescription.h>
#import <ActivitiSDK/ASDKModelFormField.h>
#import <ActivitiSDK/ASDKModelFormOutcome.h>
#import <ActivitiSDK/ASDKModelProcessInstance.h>
#import <ActivitiSDK/ASDKModelProcessDefinition.h>
#import <ActivitiSDK/ASDKModelUser.h>
#import <ActivitiSDK/ASDKModelProcessInstanceContent.h>
#import <ActivitiSDK/ASDKModelProcessInstanceContentField.h>

// Network services protocols
#import <ActivitiSDK/ASDKAppNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKProfileNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKFilterNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKTaskNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKProcessInstanceNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKProcessDefinitionNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKFormNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKUserNetworkServiceProtocol.h>
#import <ActivitiSDK/ASDKQuerryNetworkServiceProtocol.h>

// Other service protocols
#import <ActivitiSDK/ASDKDiskServiceProtocol.h>

// Service locator imports
#import <ActivitiSDK/ASDKServiceLocator.h>

// Service proxies
#import <ActivitiSDK/ASDKAppNetworkServices.h>
#import <ActivitiSDK/ASDKProfileNetworkServices.h>
#import <ActivitiSDK/ASDKFilterNetworkServices.h>
#import <ActivitiSDK/ASDKTaskNetworkServices.h>
#import <ActivitiSDK/ASDKProcessInstanceNetworkServices.h>
#import <ActivitiSDK/ASDKProcessDefinitionNetworkServices.h>
#import <ActivitiSDK/ASDKFormNetworkServices.h>
#import <ActivitiSDK/ASDKUserNetworkServices.h>
#import <ActivitiSDK/ASDKQuerryNetworkServices.h>
#import <ActivitiSDK/ASDKDiskServices.h>

// Form render engine
#import <ActivitiSDK/ASDKFormRenderEngine.h>
#import <ActivitiSDK/ASDKFormControllerNavigationProtocol.h>

// Logger utilities
#import <ActivitiSDK/ASDKLogConfiguration.h>
#import <ActivitiSDK/ASDKLogFormatter.h>

// UI Components
#import <ActivitiSDK/ASDKRoundedBorderView.h>
#import <ActivitiSDK/ASDKFormCheckbox.h>

// UI Categories
#import <ActivitiSDK/NSString+ASDKFontGlyphicons.h>
#import <ActivitiSDK/UIFont+ASDKGlyphicons.h>

// Constants
#import <ActivitiSDK/ASDKNetworkServiceConstants.h>

//! Project version number for ActivitiSDK.
FOUNDATION_EXPORT double ActivitiSDKVersionNumber;

//! Project version string for ActivitiSDK.
FOUNDATION_EXPORT const unsigned char ActivitiSDKVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ActivitiSDK/PublicHeader.h>


