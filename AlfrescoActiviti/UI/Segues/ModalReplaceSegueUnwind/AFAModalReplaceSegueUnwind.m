/*******************************************************************************
 * Copyright (C) 2005-2017 Alfresco Software Limited.
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

#import "AFAModalReplaceSegueUnwind.h"
#import "AFAUIConstants.h"

@implementation AFAModalReplaceSegueUnwind

- (void)perform {
    UIView *inView = [UIApplication sharedApplication].keyWindow;
    UIViewController *toViewController = self.destinationViewController;
    
    // If not get the sourceViewController's view directly
    UIView *fromView = ((UIViewController *)self.sourceViewController).view;
    
    toViewController.view.frame = inView.frame;
    CATransform3D scale = CATransform3DIdentity;
    toViewController.view.layer.transform = CATransform3DScale(scale, .6f, .6f, 1.0f);
    toViewController.view.alpha = .0f;
    
    [inView insertSubview:toViewController.view
             belowSubview:fromView];
    
    CGRect frameOffScreen = inView.frame;
    frameOffScreen.origin.y = CGRectGetHeight(inView.frame);
    
    NSTimeInterval duration = kModalReplaceAnimationTime;
    NSTimeInterval halfDuration = duration / 2.0f;
    
    CATransform3D t1 = [self firstTransform];
    
    [UIView animateKeyframesWithDuration:halfDuration
                                   delay:halfDuration - (.5f * halfDuration)
                                 options:UIViewKeyframeAnimationOptionCalculationModeLinear
                              animations:^{
                                  [UIView addKeyframeWithRelativeStartTime:.0f
                                                          relativeDuration:.5f
                                                                animations:^{
                                                                    toViewController.view.layer.transform = t1;
                                                                    toViewController.view.alpha = 1.0f;
                                                                }];
                                  [UIView addKeyframeWithRelativeStartTime:.5f
                                                          relativeDuration:.5f
                                                                animations:^{
                                                                    toViewController.view.layer.transform = CATransform3DIdentity;
                                                                }];
                              } completion:^(BOOL finished) {
                                  [toViewController dismissViewControllerAnimated:NO
                                                                       completion:nil];
                              }];
    [UIView animateWithDuration:halfDuration
                     animations:^{
                         fromView.frame = frameOffScreen;
                     } completion:^(BOOL finished) {
                         toViewController.view.layer.shadowOpacity = .0f;
                     }];
}

- (CATransform3D)firstTransform {
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0 / -900;
    t1 = CATransform3DScale(t1, .95, .95, 1);
    t1 = CATransform3DRotate(t1, 15.0f * M_PI / 180.0f, 1, 0, 0);
    
    return t1;
}

@end
