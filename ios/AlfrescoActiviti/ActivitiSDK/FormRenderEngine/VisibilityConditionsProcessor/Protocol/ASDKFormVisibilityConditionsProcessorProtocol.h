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

#import <Foundation/Foundation.h>

@protocol ASDKFormVisibilityConditionsProcessorProtocol <NSObject>

/**
 *  Designated set up method for the visibility condition processor when it is used
 *  to determine which of the provided form fields are visible and which should 
 *  become or be hidden depending on the input of the user.
 *
 *  @param formFieldArr Form fields to be parsed for visibility conditions
 *
 *  @return Instance of the visibility conditions processor
 */
- (instancetype)initWithFormFields:(NSArray *)formFieldArr;

@end
