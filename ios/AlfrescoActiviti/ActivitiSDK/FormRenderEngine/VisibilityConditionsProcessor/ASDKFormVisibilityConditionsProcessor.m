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

#import "ASDKFormVisibilityConditionsProcessor.h"

// Models
#import "ASDKModelFormVisibilityCondition.h"
#import "ASDKModelFormField.h"
#import "ASDKModelFormVariable.h"
#import "ASDKModelFormFieldValue.h"
#import "ASDKModelFormFieldOption.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"
#import "ASDKLogConfiguration.h"
#import "ASDKModelConfiguration.h"

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKFormVisibilityConditionsProcessor ()

/**
 *  Property meant to hold a refference to all the form fields the form engine 
 *  should render
 */
@property (strong, nonatomic) NSArray *formFields;

/**
 *  Property meant to hold a refference to all the form variables defined within
 *  the form description
 */
@property (strong, nonatomic) NSArray *formVariables;

/**
 *  Property meant to hold a refference to a dictionary structure where the key
 *  is represented by the affected field and the value is an array of fields 
 *  that affect it. This will be used to identify the affected field when another
 *  field changes and that operation could impact visibility.
 */
@property (strong, nonatomic) NSMutableDictionary *dependencyDict;

@end

@implementation ASDKFormVisibilityConditionsProcessor


#pragma mark -
#pragma mark Life cycle

- (instancetype)initWithFormFields:(NSArray *)formFieldArr
                     formVariables:(NSArray *)formVariables {
    self = [super init];
    
    if (self) {
        self.formFields = formFieldArr;
        self.formVariables = formVariables;
        self.dependencyDict = [self createFormFieldDependencyDictionaryForList:formFieldArr];
    }
    
    return self;
}


#pragma mark -
#pragma mark Parser methods

- (NSMutableDictionary *)createFormFieldDependencyDictionaryForList:(NSArray *)formFields {
    NSMutableDictionary *dependencyDict = [NSMutableDictionary dictionary];
    
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"visibilityCondition != nil"];
    NSArray *formFieldsWithVisibilityConditions = [formFields filteredArrayUsingPredicate:searchPredicate];
    
    for (ASDKModelFormField *formField in formFieldsWithVisibilityConditions) {
        NSMutableArray *influentialFormFieldsForCurrentFormField = [NSMutableArray array];
        
        ASDKModelFormVisibilityCondition *visibilityCondition = formField.visibilityCondition;
        
        while (visibilityCondition) {
            // If left and / or right form field ID properties aren't emtpy then
            // add the coresponding form field in the influential array of form fields
            if (visibilityCondition.leftFormFieldID.length) {
                [influentialFormFieldsForCurrentFormField addObject:[self formFieldForID:visibilityCondition.leftFormFieldID]];
            }
            
            if (visibilityCondition.rightFormFieldID.length) {
                [influentialFormFieldsForCurrentFormField addObject:[self formFieldForID:visibilityCondition.rightFormFieldID]];
            }
            
            visibilityCondition = visibilityCondition.nextCondition;
        }
        
        [dependencyDict setObject:influentialFormFieldsForCurrentFormField
                           forKey:formField];
    }
    
    return dependencyDict;
}

- (ASDKModelFormField *)formFieldForID:(NSString *)formFieldID {
    // The ID of a form field might contain the appended _LABEL parameter
    // to denote the fact that in the comparison to be made, there should be
    // used the name of an option and not the ID. We scan for the label tag
    // tag in order to isolate the name of the form field within
    BOOL searchForLabelParameter = YES;
    if (kASDKFormFieldLabelParameter.length > formFieldID.length) {
        searchForLabelParameter = NO;
    }
    
    if (searchForLabelParameter) {
        NSRange searchRange = NSMakeRange(formFieldID.length - kASDKFormFieldLabelParameter.length, kASDKFormFieldLabelParameter.length);
        NSRange resultRange = [formFieldID rangeOfString:kASDKFormFieldLabelParameter
                                                 options:NSLiteralSearch
                                                   range:searchRange];
        if (resultRange.location != NSNotFound) {
            formFieldID = [formFieldID stringByReplacingCharactersInRange:resultRange
                                                               withString:@""];
        }
    }
    
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"SELF.instanceID == %@", formFieldID];
    NSArray *formFields = [self.formFields filteredArrayUsingPredicate:searchPredicate];
    
    return formFields.firstObject;
}

- (ASDKModelFormVariable *)formVariableForID:(NSString *)variableID {
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"name == %@", variableID];
    NSArray *filteredResults = [self.formVariables filteredArrayUsingPredicate:searchPredicate];
    ASDKModelFormVariable *formVariable = filteredResults.firstObject;
    
    return formVariable;
}

- (NSArray *)parseVisibilityConditionsForFormField:(ASDKModelFormField *)formField {
    NSMutableArray *conditions = [NSMutableArray array];
    
    if (formField.visibilityCondition) {
        [conditions addObject:formField.visibilityCondition];
        ASDKModelFormVisibilityCondition *nextVisibilityCondition = formField.visibilityCondition.nextCondition;
        
        while (nextVisibilityCondition) {
            [conditions addObject:nextVisibilityCondition];
            nextVisibilityCondition = nextVisibilityCondition.nextCondition;
            
        }
    }
    
    return conditions;
}

- (NSArray *)parseVisibleFormFields {
    NSMutableArray *hiddenFields = [NSMutableArray array];
    
    // Because at init time the dependency dict is created which holds information on the affected
    // form fields, we will use that to iterate over and evaluate conditions
    for (ASDKModelFormField *affectedField in self.dependencyDict.allKeys) {
        NSArray *visibilityConditions = [self parseVisibilityConditionsForFormField:affectedField];
        
        BOOL isFormFieldVisible = NO;
        ASDKModelFormVisibilityConditionNextConditionOperatorType nextConditionOperator = ASDKModelFormVisibilityConditionNextConditionOperatorTypeUndefined;
        for (ASDKModelFormVisibilityCondition *visibilityCondition in visibilityConditions) {
            BOOL evaluationResult = [self isFormFieldVisibleForCondition:visibilityCondition];
            
            if (ASDKModelFormVisibilityConditionNextConditionOperatorTypeUndefined != nextConditionOperator) {
                NSError *error = nil;
                isFormFieldVisible = [self evaluateNextConditionBooleanComparisonBetween:isFormFieldVisible
                                                                                     and:evaluationResult
                                                                             forOperator:nextConditionOperator
                                                                                   error:&error];
                if (error) {
                    ASDKLogError(@"Cannot evaluate correctly the next condition based on the provided operator");
                }
            } else {
                isFormFieldVisible = evaluationResult;
            }
            
            nextConditionOperator = visibilityCondition.nextConditionOperator;
        }
        
        if (!isFormFieldVisible) {
            [hiddenFields addObject:affectedField];
        }
    }
    
    // Make a difference between the set of all the form fields and the hidden form fields
    // to report back the visible ones
    NSMutableSet *allFieldsSet = [NSMutableSet setWithArray:self.formFields];
    NSSet *hiddenFieldsSet = [NSSet setWithArray:hiddenFields];
    [allFieldsSet minusSet:hiddenFieldsSet];
    
    return [allFieldsSet allObjects];
}


#pragma mark -
#pragma mark Variable mapping

- (BOOL)canEvaluateVisibilityCondition:(ASDKModelFormVisibilityCondition *)visibilityCondition {
    BOOL canEvaluateCondition = YES;
    
    if (!visibilityCondition) {
        canEvaluateCondition = NO;
    } else {
        // First check the left side of the condition
        ASDKFormFieldSupportedType leftSideType = [self supportedTypeForLeftSideOfVisibilityCondition:visibilityCondition];
        
        // Then check the right side of the condition
        ASDKFormFieldSupportedType rightSideType = [self supportedTypeForRightSideOfVisibilityCondition:visibilityCondition];
        
        // Check if both sides have the same type to make the comparison
        if (leftSideType != rightSideType) {
            canEvaluateCondition = NO;
        }
    }
    
    return canEvaluateCondition;
}

- (ASDKFormFieldSupportedType)supportedTypeForFormField:(ASDKModelFormField *)formField {
    NSInteger representationType = formField.representationType;
    
    switch (representationType) {
        case ASDKModelFormFieldRepresentationTypeDropdown:
        case ASDKModelFormFieldRepresentationTypeRadio:
        case ASDKModelFormFieldRepresentationTypeMultiline: {
            return ASDKFormFieldSupportedTypeString;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeDate: {
            return ASDKFormFieldSupportedTypeDate;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeBoolean: {
            return ASDKFormFieldSupportedTypeBoolean;
        }
            break;
            
        case ASDKModelFormFieldRepresentationTypeNumerical:
        case ASDKModelFormFieldRepresentationTypeAmount: {
            return ASDKFormFieldSupportedTypeNumber;
        }
            break;
            
        default: {
            return ASDKFormFieldSupportedTypeUndefined;
        }
            
            break;
    }
}

- (ASDKFormFieldSupportedType)supportedTypeForVariableWithID:(NSString *)variableID {
    ASDKModelFormVariable *formVariable = [self formVariableForID:variableID];
    
    switch (formVariable.type) {
        case ASDKModelFormVariableTypeString: {
            return ASDKFormFieldSupportedTypeString;
        }
            break;
            
        case ASDKModelFormVariableTypeInteger: {
            return ASDKFormFieldSupportedTypeNumber;
        }
            break;
            
        case ASDKModelFormVariableTypeBoolean: {
            return ASDKFormFieldSupportedTypeBoolean;
        }
            break;
            
        default: {
            return ASDKFormFieldSupportedTypeUndefined;
        }
            break;
    }
}

- (ASDKFormFieldSupportedType)supportedTypeForValue:(NSString *)stringValue {
    // Try to clasify the string value to a particular base type and if that's not
    // possible fallback to string as default
    
    // First check if the string value is a number
    NSCharacterSet *otherThanDigitsSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if (NSNotFound == [stringValue rangeOfCharacterFromSet:otherThanDigitsSet].location) {
        return ASDKFormFieldSupportedTypeNumber;
    }
    
    // Check if a date can be extracted from the string value
    NSError *dataDetectorError = nil;
    NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate
                                                                   error:&dataDetectorError];
    NSUInteger numberOfDateMatches = [dataDetector numberOfMatchesInString:stringValue
                                                                   options:0
                                                                     range:NSMakeRange(0, stringValue.length)];
    if (numberOfDateMatches) {
        return ASDKFormFieldSupportedTypeDate;
    }
    
    // Check if a boolean can be extracted from the string value
    NSString *whiteSpaceTrimmedString = [stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([whiteSpaceTrimmedString.uppercaseString isEqualToString:kASDKFormFieldTrueStringValue.uppercaseString] ||
        [whiteSpaceTrimmedString.uppercaseString isEqualToString:kASDKFormFieldFalseStringValue.uppercaseString]) {
        return ASDKFormFieldSupportedTypeBoolean;
    }
    
    // Finally fall back to string type
    return ASDKFormFieldSupportedTypeString;
}

- (ASDKFormFieldSupportedType)supportedTypeForLeftSideOfVisibilityCondition:(ASDKModelFormVisibilityCondition *)visibilityCondition {
    ASDKFormFieldSupportedType leftSideType = ASDKFormFieldSupportedTypeUndefined;
    
    // Check if we've a value for the left form field and if so we ignore the leftRestResponseID
    // field
    if (visibilityCondition.leftFormFieldID.length) {
        leftSideType = [self supportedTypeForFormField:[self formFieldForID:visibilityCondition.leftFormFieldID]];
    } else if (visibilityCondition.leftRestResponseID.length) {
        leftSideType = [self supportedTypeForVariableWithID:visibilityCondition.leftRestResponseID];
    }
    
    return leftSideType;
}

- (ASDKFormFieldSupportedType)supportedTypeForRightSideOfVisibilityCondition:(ASDKModelFormVisibilityCondition *)visibilityCondition {
    ASDKFormFieldSupportedType rightSideType = ASDKFormFieldSupportedTypeUndefined;
    
    // For the right side there are 3 checks to be performed regarding type mapping:
    // rightValue field, rightFormFieldID and rightRestResponse ID
    if (visibilityCondition.rightValue.length) {
        rightSideType = [self supportedTypeForValue:visibilityCondition.rightValue];
    } else if (visibilityCondition.rightFormFieldID.length) {
        rightSideType = [self supportedTypeForFormField:[self formFieldForID:visibilityCondition.rightFormFieldID]];
    } else if (visibilityCondition.rightRestResponseID.length) {
        rightSideType = [self supportedTypeForVariableWithID:visibilityCondition.leftRestResponseID];
    }
    
    return rightSideType;
}


#pragma mark -
#pragma mark Condition evaluation

- (BOOL)isFormFieldVisibleForCondition:(ASDKModelFormVisibilityCondition *)visibilityCondition {
    BOOL isVisible = NO;
    
    // First check if the condition can be evaluated and if not then the field will be visible
    if (![self canEvaluateVisibilityCondition:visibilityCondition]) {
        return YES;
    } else {
        // Collect the left value for the comparison
        id leftValue = nil;
        
        // For this we check two properties: leftFormFieldID and leftRestResponseID
        if (visibilityCondition.leftFormFieldID.length) {
            // Check if label refference is used
            BOOL searchForLabelParameter = YES;
            if (kASDKFormFieldLabelParameter.length > visibilityCondition.leftFormFieldID.length) {
                searchForLabelParameter = NO;
            }
        
            if (searchForLabelParameter) {
                NSRange searchRange = NSMakeRange(visibilityCondition.leftFormFieldID.length - kASDKFormFieldLabelParameter.length, kASDKFormFieldLabelParameter.length);
                NSRange resultRange = [visibilityCondition.leftFormFieldID rangeOfString:kASDKFormFieldLabelParameter
                                                                                 options:NSLiteralSearch
                                                                                   range:searchRange];
                if (resultRange.location != NSNotFound) {
                    leftValue = [self labelValueForFormField:[self formFieldForID:visibilityCondition.leftFormFieldID]];
                } else {
                    leftValue = [self valueForFormField:[self formFieldForID:visibilityCondition.leftFormFieldID]];
                }
            } else {
                leftValue = [self valueForFormField:[self formFieldForID:visibilityCondition.leftFormFieldID]];
            }
        } else if (visibilityCondition.leftRestResponseID.length) {
            leftValue = ((ASDKModelFormVariable *)[self formVariableForID:visibilityCondition.leftRestResponseID]).value;
        }
        
        // Collect the right value for the comparison
        id rightValue = nil;
        
        // For this we check three properties: rightFormFieldID, rightRestResponseID and rightValue
        if (visibilityCondition.rightFormFieldID.length) {
            // Check if label refference is used
            BOOL searchForLabelParameter = YES;
            if (kASDKFormFieldLabelParameter.length > visibilityCondition.rightFormFieldID.length) {
                searchForLabelParameter = NO;
            }
            
            if (searchForLabelParameter) {
                NSRange searchRange = NSMakeRange(visibilityCondition.rightFormFieldID.length - kASDKFormFieldLabelParameter.length, kASDKFormFieldLabelParameter.length);
                NSRange resultRange = [visibilityCondition.rightFormFieldID rangeOfString:kASDKFormFieldLabelParameter
                                                                                 options:NSLiteralSearch
                                                                                   range:searchRange];
                if (resultRange.location != NSNotFound) {
                    leftValue = [self labelValueForFormField:[self formFieldForID:visibilityCondition.rightFormFieldID]];
                } else {
                    leftValue = [self valueForFormField:[self formFieldForID:visibilityCondition.rightFormFieldID]];
                }
            } else {
                rightValue = [self valueForFormField:[self formFieldForID:visibilityCondition.rightFormFieldID]];
            }
        } else if (visibilityCondition.rightRestResponseID.length) {
            rightValue = ((ASDKModelFormVariable *)[self formVariableForID:visibilityCondition.rightRestResponseID]).value;
        } else {
            rightValue = visibilityCondition.rightValue;
        }
        
        // Decide which value comparator should be used. Because we passed the canEvaluateVisibilityCondition type
        // this means that both sides of the visibility condition have the same type thus is safe to just get
        // the type for one
        
        ASDKFormFieldSupportedType conditionVariablesType = [self supportedTypeForLeftSideOfVisibilityCondition:visibilityCondition];
        
        // Based on the condition variables type call the specific type method to perform the comparison
        NSError *evaluationError = nil;
        ASDKModelFormVisibilityConditionOperatorType operator = visibilityCondition.operationOperator;
        switch (conditionVariablesType) {
            case ASDKFormFieldSupportedTypeString: {
                isVisible = [self evaluateStringComparisonBetween:leftValue
                                                              and:rightValue
                                                      forOperator:operator
                                                            error:&evaluationError];
                if (evaluationError) {
                    ASDKLogError(@"Could not perform string comparison. Reason:%@", evaluationError.localizedDescription);
                }
            }
                break;
                
            case ASDKFormFieldSupportedTypeNumber: {
                NSNumber *leftNumber = [self numberFromString:leftValue];
                NSNumber *rightNumber = [self numberFromString:rightValue];
                
                isVisible = [self evaluateNumberComparisonBetween:leftNumber
                                                              and:rightNumber
                                                      forOperator:operator
                                                            error:&evaluationError];
                
                if (evaluationError) {
                    ASDKLogError(@"Could not perform number comparison. Reason:%@", evaluationError.localizedDescription);
                }
            }
                break;
                
            case ASDKFormFieldSupportedTypeBoolean: {
                isVisible = [self evaluateBooleanComparisonBetween:leftValue
                                                               and:rightValue
                                                       forOperator:operator
                                                             error:&evaluationError];
                
                if (evaluationError) {
                    ASDKLogError(@"Could not perform boolean comparison. Reason:%@", evaluationError.localizedDescription);
                }
            }
                break;
                
            case ASDKFormFieldSupportedTypeDate: {
                NSDate *leftDate = [self dateFromString:leftValue];
                NSDate *rightDate = [self dateFromString:rightValue];
                
                isVisible = [self evaluateDateComparisonBetween:leftDate
                                                            and:rightDate
                                                    forOperator:operator
                                                          error:&evaluationError];
                
                if (evaluationError) {
                    ASDKLogError(@"Could not perform date comparison. Reason:%@", evaluationError.localizedDescription);
                }
            }
                break;
                
            default:
                break;
        }
    }
    
    return isVisible;
}


#pragma mark -
#pragma mark Value comparators

- (BOOL)evaluateStringComparisonBetween:(NSString *)firstString
                                    and:(NSString *)secondString
                            forOperator:(ASDKModelFormVisibilityConditionOperatorType)operatorType
                                  error:(NSError **)error {
    BOOL result;
    
    switch (operatorType) {
        case ASDKModelFormVisibilityConditionOperatorTypeEqual: {
            result = [firstString isEqualToString:secondString];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEqual: {
            result = ![firstString isEqualToString:secondString];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeEmpty: {
            result = firstString.length ? NO : YES;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEmpty: {
            result = firstString.length ? YES : NO;
        }
            break;
            
        default: {
            *error = [self unsupportedOperatorTypeError];
        }
            break;
    }
    
    return result;
}

- (BOOL)evaluateNumberComparisonBetween:(NSNumber *)firstNumber
                                    and:(NSNumber *)secondNumber
                            forOperator:(ASDKModelFormVisibilityConditionOperatorType)operatorType
                                  error:(NSError **)error {
    BOOL result;
    
    switch (operatorType) {
        case ASDKModelFormVisibilityConditionOperatorTypeEqual: {
            result = [firstNumber isEqualToNumber:secondNumber];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEqual: {
            result = ![firstNumber isEqualToNumber:secondNumber];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeLessThan: {
            result = ([firstNumber compare:secondNumber] == NSOrderedAscending) ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeLessOrEqualThan: {
            NSComparisonResult comparisonResult = [firstNumber compare:secondNumber];
            result = (comparisonResult == NSOrderedSame || comparisonResult == NSOrderedAscending);
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeGreaterThan: {
            result = ([firstNumber compare:secondNumber] == NSOrderedDescending) ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeGreatOrEqualThan: {
            NSComparisonResult comparisonResult = [firstNumber compare:secondNumber];
            result = (comparisonResult == NSOrderedSame || comparisonResult == NSOrderedDescending);
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeEmpty: {
            result = !secondNumber ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEmpty: {
            result = secondNumber ? YES: NO;
        }
            break;
            
        default: {
            *error = [self unsupportedOperatorTypeError];
        }
            break;
    }
    
    return result;
}

- (BOOL)evaluateDateComparisonBetween:(NSDate *)firstDate
                                  and:(NSDate *)secondDate
                          forOperator:(ASDKModelFormVisibilityConditionOperatorType)operatorType
                                error:(NSError **)error {
    BOOL result;
    
    switch (operatorType) {
        case ASDKModelFormVisibilityConditionOperatorTypeEqual: {
            result = [firstDate isEqualToDate:secondDate];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEqual: {
            result = ![firstDate isEqualToDate:secondDate];
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeLessThan: {
            result = ([firstDate compare:secondDate] == NSOrderedAscending) ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeLessOrEqualThan: {
            NSComparisonResult comparisonResult = [firstDate compare:secondDate];
            result = (comparisonResult == NSOrderedSame || comparisonResult == NSOrderedAscending);
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeGreaterThan: {
            result = ([firstDate compare:secondDate] == NSOrderedDescending) ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeGreatOrEqualThan: {
            NSComparisonResult comparisonResult = [firstDate compare:secondDate];
            result = (comparisonResult == NSOrderedSame || comparisonResult == NSOrderedDescending);
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeEmpty: {
            result = !secondDate ? YES : NO;
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEmpty: {
            result = secondDate ? YES: NO;
        }
            break;
            
        default: {
            *error = [self unsupportedOperatorTypeError];
        }
            break;
    }
    
    return result;
}

- (BOOL)evaluateBooleanComparisonBetween:(NSString *)firstBooleanString
                                     and:(NSString *)secondBooleanString
                             forOperator:(ASDKModelFormVisibilityConditionOperatorType)operatorType
                                   error:(NSError **)error {
    BOOL result;
    
    BOOL firstBoolean = [firstBooleanString isEqualToString:kASDKFormFieldTrueStringValue] ? YES : NO;
    BOOL secondBoolean = [secondBooleanString isEqualToString:kASDKFormFieldTrueStringValue] ? YES : NO;
    
    switch (operatorType) {
        case ASDKModelFormVisibilityConditionOperatorTypeEqual: {
            result = (firstBoolean && secondBoolean);
        }
            break;
            
        case ASDKModelFormVisibilityConditionOperatorTypeNotEqual: {
            result = (firstBoolean != secondBoolean);
        }
            break;
            
        default: {
            *error = [self unsupportedOperatorTypeError];
        }
            break;
    }
    
    return result;
}

- (BOOL)evaluateNextConditionBooleanComparisonBetween:(BOOL)firstConditionResult
                                                  and:(BOOL)secondConditionResult
                                          forOperator:(ASDKModelFormVisibilityConditionNextConditionOperatorType)operatorType
                                                error:(NSError **)error {
    BOOL result;
    
    switch (operatorType) {
        case ASDKModelFormVisibilityConditionNextConditionOperatorTypeAnd: {
            result = firstConditionResult && secondConditionResult;
        }
            break;
            
        case ASDKModelFormVisibilityConditionNextConditionOperatorTypeAndNot: {
            result = firstConditionResult && !secondConditionResult;
        }
            break;
            
        case ASDKModelFormVisibilityConditionNextConditionOperatorTypeOr: {
            result = firstConditionResult || secondConditionResult;
        }
            break;
            
        case ASDKModelFormVisibilityConditionNextConditionOperatorTypeOrNot: {
            result = firstConditionResult || !secondConditionResult;
        }
            break;
            
        default: {
            *error = [self unsupportedOperatorTypeError];
        }
            break;
    }
    
    return result;
}


#pragma mark -
#pragma mark Value extraction and conversions

- (NSString *)valueForFormField:(ASDKModelFormField *)formField {
    id valueToReturn = nil;
    
    // Look first inside the metadata that is attached to the form field
    // Look inside the metadata that is attached to the form field
    if (formField.metadataValue.attachedValue) {
        valueToReturn = formField.metadataValue.attachedValue;
    } else if (formField.metadataValue.option.attachedValue) {
        valueToReturn = formField.metadataValue.option.attachedValue;
    } else {
        // Check first if the form was saved and there's a value for the form field values property
        if (formField.values.count) {
            // A value is present, return the first element of the array.
            // Visibility condition evaluations are not supported for form fields that hold multiple
            // value entries like attach fields
            valueToReturn = formField.values.firstObject;
        }
    }
    
    return valueToReturn;
}

- (NSString *)labelValueForFormField:(ASDKModelFormField *)formField {
    NSString *valueToReturn = nil;
    
    // Label values apply for form fields that offer an option list so
    // that narrows the search to saved values and values chosen by
    // the user stored inside the metadataValue field of the form field
    NSString *optionID = nil;
    
    // Check first for saved form options
    if (formField.values.count) {
        // Double check that the saved value is actually an option registered
        // in the form field options
        NSString *savedValue = formField.values.firstObject;
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"instanceID == %@", savedValue];
        optionID = [formField.formFieldOptions filteredArrayUsingPredicate:searchPredicate].firstObject;
    }
    
    if (!optionID) {
        // Otherwise extract information saved by the user
        valueToReturn = formField.metadataValue.option.attachedValue;
    }
    
    // If there was no value chosen by the user, but there are saved ones
    // get the label name from the form field option property
    if (!valueToReturn && optionID) {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"instanceID == %@", optionID];
        valueToReturn = [(ASDKModelFormFieldOption *)[formField.formFieldOptions filteredArrayUsingPredicate:searchPredicate].firstObject name];
    }
    
    return valueToReturn;
}

- (NSNumber *)numberFromString:(NSString *)string {
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    
    return [numberFormatter numberFromString:string];
}

- (NSDate *)dateFromString:(NSString *)string {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = kBaseModelDateFormat;
    
    return [dateFormatter dateFromString:string];
}


#pragma mark -
#pragma mark Error reporting and handling

- (NSError *)unsupportedOperatorTypeError {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey            : @"Unsupported operator type.",
                               NSLocalizedFailureReasonErrorKey     : @"The evaluation cannot be perfomed since the operator type is not supported by the compared objects.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Please check the operator type sent to this evaluation method."
                               };
    return [NSError errorWithDomain:kASDKFormRenderEngineErrorDomain
                               code:kASDKFormVisibilityConditionProcessorErrorCode
                           userInfo:userInfo];
}

@end
