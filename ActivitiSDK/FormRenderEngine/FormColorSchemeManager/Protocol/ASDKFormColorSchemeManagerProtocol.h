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

@import UIKit;

/**
 *  The purpose of classes implementing this protocol is to serve as color picker
 *  containers providing the means of customizing form related colors from outside
 *  the ActivitiSDK.
 */

@protocol ASDKFormColorSchemeManagerProtocol <NSObject>

/**
 *  Property meant to hold a reference for navigation bar tint color of form
 *  child controllers.
 */
@property (strong, nonatomic) UIColor *navigationBarThemeColor;

/**
 *  Property meant to hold a refference for the navigation bar title and other
 *  bar buttons that might exist on the navigation bar.
 */
@property (strong, nonatomic) UIColor *navigationBarTitleAndControlsColor;

@end
