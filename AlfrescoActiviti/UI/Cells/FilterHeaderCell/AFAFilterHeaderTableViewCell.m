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

#import "AFAFilterHeaderTableViewCell.h"
#import "AFALocalizationConstants.h"
@import ActivitiSDK;

@implementation AFAFilterHeaderTableViewCell

- (void)awakeFromNib {
    self.headerIconLabel.font = [UIFont glyphiconFontWithSize:17];
    [self.clearButton setTitle:NSLocalizedString(kLocalizationListScreenClearAllButtonTitleText, @"Clear all")
                      forState:UIControlStateNormal];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


#pragma mark -
#pragma mark Public interface

- (void)setUpForFilterList {
    self.headerIconLabel.text = [NSString iconStringForIconType:ASDKGlyphIconTypeFilter];
    self.headerTitleLabel.text = NSLocalizedString(kLocalizationListScreenFilterByText, @"Filter by");
    self.clearButton.hidden = NO;

}

- (void)setUpForSortList {
    self.headerIconLabel.text = [NSString iconStringForIconType:ASDKGlyphIconTypeSortByAttributesAlt];
    self.headerTitleLabel.text = NSLocalizedString(kLocalizationListScreenSortByText, @"Sort by");
    self.clearButton.hidden = YES;
}


#pragma mark -
#pragma mark Actions

- (IBAction)onClear:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(didClearAll:)]) {
        [self.delegate didClearAll:self];
    }
}


@end
