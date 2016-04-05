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

#import "AFAModalReplaceSegue.h"
#import "AFAUIConstants.h"

@implementation AFAModalReplaceSegue

- (void)perform {
    UIView *inView = [UIApplication sharedApplication].keyWindow;
    UIViewController *toViewController = self.destinationViewController;
    toViewController.navigationController.navigationBarHidden = NO;
    UIViewController *fromViewController = self.sourceViewController;
    
    UIView *fromViewControllerView = fromViewController.view;
    fromViewControllerView.layer.shadowColor = [UIColor blackColor].CGColor;
    fromViewControllerView.layer.shadowOffset = CGSizeMake(5.0f,5.0f);
    fromViewControllerView.layer.shadowOpacity = .5f;
    fromViewControllerView.layer.shadowRadius = 5.0f;
    
    CGRect offScreenFrame = inView.frame;
    offScreenFrame.origin.y = CGRectGetHeight(inView.frame);
    toViewController.view.frame = offScreenFrame;
    
    [inView insertSubview:toViewController.view
             aboveSubview:fromViewController.view];
    
    CFTimeInterval duration = kModalReplaceAnimationTime;
    CFTimeInterval halfDuration = duration/2;
    
    CATransform3D t1 = [self firstTransform];
    CATransform3D t2 = [self secondTransformWithView:fromViewController.view];
    
    [UIView animateKeyframesWithDuration:halfDuration
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeLinear
                              animations:^{
                                  [UIView addKeyframeWithRelativeStartTime:0.0f
                                                          relativeDuration:0.5f
                                                                animations:^{
                                                                    fromViewController.view.layer.transform = t1;
                                                                    fromViewController.view.alpha = 0.6;
                                                                }];
                                  
                                  [UIView addKeyframeWithRelativeStartTime:0.5f
                                                          relativeDuration:0.5f
                                                                animations:^{
                                                                    fromViewController.view.layer.transform = t2;
                                                                }];
                              } completion:nil];
    
    [UIView animateWithDuration:duration
                          delay:(halfDuration - (0.3 * halfDuration))
         usingSpringWithDamping:3.0f
          initialSpringVelocity:7.0f
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         toViewController.view.frame = inView.frame;
                     } completion:^(BOOL finished) {
                         [fromViewController.navigationController presentViewController:toViewController
                                                                               animated:NO
                                                                             completion:nil];
                     }];
}

- (CATransform3D)firstTransform {
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0 / -900;
    t1 = CATransform3DScale(t1, 0.95, 0.95, 1);
    t1 = CATransform3DRotate(t1, 15.0f * M_PI / 180.0f, 1, 0, 0);
    
    return t1;
}

- (CATransform3D)secondTransformWithView:(UIView*)view {
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = [self firstTransform].m34;
    t2 = CATransform3DTranslate(t2, 0, view.frame.size.height * -0.08, 0);
    t2 = CATransform3DScale(t2, 0.8, 0.8, 1);
    
    return t2;
}

@end
