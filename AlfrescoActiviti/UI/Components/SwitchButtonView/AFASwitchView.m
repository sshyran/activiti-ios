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

#import "AFASwitchView.h"

@interface AFASwitchView ()

@property (strong, nonatomic) UIView    *buttonView;
@property (strong, nonatomic) UIButton  *onButton;
@property (strong, nonatomic) UIButton  *offButton;
@property (strong, nonatomic) UILabel   *onLabel;
@property (strong, nonatomic) UILabel   *offLabel;

@end

@implementation AFASwitchView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.isOff = NO;
}

- (void)drawRect:(CGRect)rect {
    // Setup background view
    UIView *backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    backgroundView.backgroundColor = self.backgroundViewColor;
    backgroundView.layer.cornerRadius = 4.0;
    [self addSubview:backgroundView];
    
    // Setup button view
    self.buttonView = [[UIView alloc] initWithFrame:CGRectMake(.0f, .0f, self.bounds.size.width / 2.0f, self.bounds.size.height)];
    self.buttonView.backgroundColor = self.buttonViewColor;
    self.buttonView.layer.cornerRadius = self.buttonViewCornerRadius;
    [self addSubview:self.buttonView];
    
    // Setup toggle buttons
    self.onButton = [[UIButton alloc] initWithFrame:CGRectMake(.0f, .0f, self.bounds.size.width / 2.0f, self.bounds.size.height)];
    self.onButton.backgroundColor = [UIColor clearColor];
    self.onButton.enabled = NO;
    [self.onButton addTarget:self
                      action:@selector(onToggle:)
            forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.onButton];
    
    self.offButton = [[UIButton alloc] initWithFrame:CGRectMake(self.bounds.size.width / 2.0f, .0f, self.bounds.size.width / 2.0f, self.bounds.size.height)];
    self.offButton.backgroundColor = [UIColor clearColor];
    self.offButton.enabled = YES;
    [self.offButton addTarget:self
                       action:@selector(onToggle:)
             forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.offButton];
    
    // Setup ON / OFF labels
    CGFloat marginPadding = (AFASwitchViewOnOffLabelPositionMargin == self.onOffLabelPosition) ? 10.0f : .0f;
    NSTextAlignment onTextAlignment = (AFASwitchViewOnOffLabelPositionMargin == self.onOffLabelPosition) ? NSTextAlignmentLeft : NSTextAlignmentCenter;
    NSTextAlignment offTextAlignment = (AFASwitchViewOnOffLabelPositionMargin == self.onOffLabelPosition) ? NSTextAlignmentRight : NSTextAlignmentCenter;
    
    self.onLabel = [[UILabel alloc] initWithFrame:CGRectMake(marginPadding, (self.bounds.size.height / 2.0f) - 25, self.bounds.size.width / 2.0f, 50)];
#if TARGET_INTERFACE_BUILDER
    self.onLabel.text = @"ON";
#else
    self.onLabel.text = self.onLabelText;
#endif
    self.onLabel.textAlignment = onTextAlignment;
    self.onLabel.textColor = self.onLabelTextColor;
    self.onLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.onButton addSubview:self.onLabel];
    
    self.offLabel = [[UILabel alloc] initWithFrame:CGRectMake(-marginPadding / 2.0f, (self.bounds.size.height / 2.0f) - 25, self.bounds.size.width / 2.0f, 50)];
#if TARGET_INTERFACE_BUILDER
    self.offLabel.text = @"OFF";
#else
    self.offLabel.text = self.offLabelText;
#endif
    self.offLabel.textAlignment = offTextAlignment;
    self.offLabel.textColor = self.offLabelTextColor;
    self.offLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.offButton addSubview:self.offLabel];
    
    // Setup description label
    if (self.switchDescriptionText) {
        UIFont *descriptionTextFont = [UIFont systemFontOfSize:10];
        CGFloat widthOfDescriptionText = [self widthOfString:self.switchDescriptionText
                                                  withFont:descriptionTextFont];
        // Add extra padding
        widthOfDescriptionText += 10;
        
        UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.bounds.size.width / 2.0f) - (widthOfDescriptionText / 2.0f), (self.bounds.size.height / 2.0) - 10, widthOfDescriptionText, 20)];
        descriptionLabel.text = self.switchDescriptionText;
        descriptionLabel.textAlignment = NSTextAlignmentCenter;
        descriptionLabel.textColor = self.descriptionTextColor;
        descriptionLabel.font = descriptionTextFont;
        descriptionLabel.backgroundColor = self.descriptionBackgroundColor;
        descriptionLabel.layer.cornerRadius = 5.0f;
        descriptionLabel.clipsToBounds = YES;
        [self addSubview:descriptionLabel];
    }
}


#pragma mark -
#pragma mark Actions

- (void)onToggle:(UIButton *)sender {
    [self switchFromCurrentState:!self.isOff];
}


#pragma mark -
#pragma mark Animations

- (void)switchFromCurrentState:(BOOL)on {
    if (on == self.isOff) {
        return;
    }
    self.isOff = on;
    
    [UIView animateWithDuration:.4f
                          delay:.0f
         usingSpringWithDamping:.8f
          initialSpringVelocity:14.0f
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         CGRect adjustedButtonViewFrame = self.buttonView.frame;
                         adjustedButtonViewFrame.origin.x += self.frame.size.width / 2.0f * (on ? 1 : -1);
                         self.buttonView.frame = adjustedButtonViewFrame;
                     } completion:nil];
    
    [self animateLabelText:self.offLabel
                   toColor:(on ? self.onLabelTextColor : self.offLabelTextColor)];
    [self animateLabelText:self.onLabel
                   toColor:(on ? self.offLabelTextColor : self.onLabelTextColor)];
    
    self.onButton.enabled = !self.onButton.enabled;
    self.offButton.enabled = !self.offButton.enabled;
}

- (void)animateLabelText:(UILabel *)label
                 toColor:(UIColor *)color {
    [UIView transitionWithView:label
                      duration:.4f
                       options:UIViewAnimationOptionCurveEaseOut |
                               UIViewAnimationOptionTransitionCrossDissolve |
                               UIViewAnimationOptionBeginFromCurrentState
                    animations:^{
                        label.textColor = color;
                    } completion:nil];
    
}


#pragma mark - 
#pragma mark Utilities

- (CGFloat)widthOfString:(NSString *)string
                withFont:(UIFont *)font {
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:string
                                            attributes:attributes] size].width;
}

@end
