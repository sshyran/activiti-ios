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

#import "ASDKFormThemedCollectionViewCell.h"

@implementation ASDKFormThemedCollectionViewCell

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.colorSchemeManager = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormColorSchemeManagerProtocol)];
    }
    
    return self;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    // Adjust the cell sizing parameters by constraining with a high priority on the horizontal axis
    // and a lower priority on the vertical axis
    UICollectionViewLayoutAttributes *attributes = [super preferredLayoutAttributesFittingAttributes:layoutAttributes];
    attributes.size = CGSizeMake(layoutAttributes.size.width, attributes.size.height);
    
    return attributes;
}

@end
