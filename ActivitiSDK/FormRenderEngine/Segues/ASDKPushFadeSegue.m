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

#import "ASDKPushFadeSegue.h"
#import "ASDKFormRenderEngineConstants.h"

@implementation ASDKPushFadeSegue

- (void)perform {
    UIViewController *toViewController = self.destinationViewController;
    UIViewController *fromViewController = self.sourceViewController;
    
    UIView *fromViewControllerView = fromViewController.view;
    fromViewControllerView.layer.shadowColor = [UIColor blackColor].CGColor;
    fromViewControllerView.layer.shadowOffset = CGSizeMake(5.0f,5.0f);
    fromViewControllerView.layer.shadowOpacity = .5f;
    fromViewControllerView.layer.shadowRadius = 5.0f;
    
    CFTimeInterval duration = kModalReplaceAnimationTime;
    CFTimeInterval halfDuration = duration/2;
    
    CATransform3D t1 = [self firstTransform];
    
    [UIView animateKeyframesWithDuration:halfDuration
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeLinear
                              animations:^{
                                  [UIView addKeyframeWithRelativeStartTime:.0f
                                                          relativeDuration:.5f
                                                                animations:^{
                                                                    fromViewController.view.layer.transform = t1;
                                                                }];
                              } completion:nil];
    
    [fromViewController.navigationController pushViewController:toViewController
                                                       animated:YES];
}

- (CATransform3D)firstTransform {
    CATransform3D t1 = CATransform3DIdentity;
    t1 = CATransform3DScale(t1, 0.9f, 0.9f, 1);
    t1 = CATransform3DTranslate(t1, 0, -0.05, 0);
    
    return t1;
}

@end