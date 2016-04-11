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

#import "ASDKModelBase.h"

typedef NS_ENUM(NSInteger, ASDKModelFormVisibilityConditionOperatorType) {
    ASDKModelFormVisibilityConditionOperatorTypeEqual,
    ASDKModelFormVisibilityConditionOperatorTypeNotEqual,
    ASDKModelFormVisibilityConditionOperatorTypeLessThan,
    ASDKModelFormVisibilityConditionOperatorTypeLessOrEqualThan,
    ASDKModelFormVisibilityConditionOperatorTypeGreaterThan,
    ASDKModelFormVisibilityConditionOperatorTypeGreatOrEqualThan,
    ASDKModelFormVisibilityConditionOperatorTypeEmpty,
    ASDKModelFormVisibilityConditionOperatorTypeNotEmpty
};

@interface ASDKModelFormVisibilityCondition : ASDKModelBase

@property (strong, nonatomic) NSString *leftFormFieldID;
@property (strong, nonatomic) NSString *leftRestResponseID;
@property (assign, nonatomic) ASDKModelFormVisibilityConditionOperatorType operationOperator;
@property (strong, nonatomic) NSString *rightValue;
@property (strong, nonatomic) NSString *rightFormFieldID;
@property (strong, nonatomic) NSString *rightRestResponseID;
@property (strong, nonatomic) NSString *nextConditionOperator;
@property (strong, nonatomic) ASDKModelFormVisibilityCondition *nextCondition;

@end
