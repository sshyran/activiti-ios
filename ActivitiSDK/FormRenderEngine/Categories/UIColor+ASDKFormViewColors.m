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

#import "UIColor+ASDKFormViewColors.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation UIColor (ASDKFormViewColors)

+ (UIColor *)formViewInvalidValueColor {
    return [UIColor colorWithRed:255 / 255.0f green:102 / 255.0f blue:102 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewValidValueColor {
    return [UIColor blackColor];
}

+ (UIColor *)formViewOutcomeEnabledColor {
    return [self generalTintColor];
}

+ (UIColor *)formViewOutcomeDisabledColor {
    return [UIColor colorWithRed:198 / 255.0f green:200 / 255.0f blue:200 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewDatePickerToolbarRemoveButtonColor {
    return [UIColor colorWithRed:15 / 255.0f green:16 / 255.0f blue:17 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewDatePickerToolbarDoneButtonColor {
    return [UIColor colorWithRed:60 / 255.0f green:150 / 255.0f blue:202 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewAmountFieldBorderColor {
    return [UIColor colorWithRed:227 / 255.0f green:227 / 255.0f blue:227 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewFieldPlaceholderColor {
    return [UIColor colorWithRed:203 / 255.0f green:203 / 255.0f blue:208 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewTextFieldDisabledColor {
    return [UIColor colorWithRed:248 / 255.0f green:248 / 255.0f blue:249 / 255.0f alpha:1.0f];
}

+ (UIColor *)generalTintColor {
    return [UIColor colorWithRed:40 / 255.0f green:150 / 255.0f blue:185 / 255.0f alpha:1.0f];
}

+ (UIColor *)formFieldCellHighlightColor {
    return [UIColor colorWithRed:198 / 255.0f green:200 / 255.0f blue:200 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewAmountFieldSymbolColor {
    return [UIColor lightGrayColor];
}

+ (UIColor *)distructiveOperationBackgroundColor {
    return [UIColor colorWithRed:250 / 255.0f green:128 / 255.0f blue:114 / 255.0f alpha:1.0f];
}

+ (UIColor *)formViewCompletedValueColor {
    return [UIColor grayColor];
}

@end
