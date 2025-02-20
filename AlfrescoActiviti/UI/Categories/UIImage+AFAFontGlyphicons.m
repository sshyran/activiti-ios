/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import "UIImage+AFAFontGlyphicons.h"

@implementation UIImage (AFAFontGlyphicons)

+ (UIImage *)imageWithIcon:(ASDKGlyphIconType)iconType
                 iconColor:(UIColor *)iconColor
                  fontSize:(CGFloat)fontSize {
    if (!iconColor) {
        iconColor = [UIColor clearColor];
    }
    
    NSString *glyphIconString = [NSString iconStringForIconType:iconType];
    UIFont *font = [UIFont glyphiconFontWithSize:fontSize];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *textAttributes = @{NSFontAttributeName : font,
                                     NSForegroundColorAttributeName : iconColor,
                                     NSParagraphStyleAttributeName : paragraphStyle};
    
    // Adjust edge insets
    CGSize textSize = [glyphIconString sizeWithAttributes:@{NSFontAttributeName : font,
                                                            NSForegroundColorAttributeName : iconColor,
                                                            NSParagraphStyleAttributeName : paragraphStyle}];
    textSize = CGSizeMake(textSize.width * 1.1f, textSize.height * 1.05f);
    
    CGRect textRect = CGRectZero;
    textRect.size = textSize;
    
    CGPoint origin = CGPointMake(textSize.width * .05f, textSize.height * .025f);
    
    UIGraphicsBeginImageContextWithOptions(textSize, NO, .0f);
    
    // Draw text
    [glyphIconString drawAtPoint:origin
                  withAttributes:textAttributes];
    
    // Create image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
