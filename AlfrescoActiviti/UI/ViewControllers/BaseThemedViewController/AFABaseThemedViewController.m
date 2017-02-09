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

#import "AFABaseThemedViewController.h"
#import "AFAUIConstants.h"

@interface AFABaseThemedViewController ()

@end

@implementation AFABaseThemedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


#pragma mark -
#pragma mark Setters

- (void)setNavigationBarTitle:(NSString *)navigationBarTitle {
    if (![_navigationBarTitle isEqualToString:navigationBarTitle]) {
        _navigationBarTitle = navigationBarTitle;
        
        // Update navigation bar title
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = _navigationBarTitle;
        titleLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                          size:17];
        titleLabel.textColor = [UIColor whiteColor];
        [titleLabel sizeToFit];
        self.navigationItem.titleView = titleLabel;
    }
}

- (void)setNavigationBarThemeColor:(UIColor *)navigationBarThemeColor {
    if (_navigationBarThemeColor != navigationBarThemeColor) {
        _navigationBarThemeColor = navigationBarThemeColor;
        
        // Make the color change an animated transition
        [self.navigationController.navigationBar.layer addAnimation:[self fadeTransitionWithDuration:kOverlayAlphaChangeTime]
                                                             forKey:nil];
        [self.navigationController.navigationBar setBarTintColor:_navigationBarThemeColor];
        [self.navigationController.navigationBar setTranslucent:NO];
    }
}

- (CATransition *)fadeTransitionWithDuration:(CGFloat)duration {
    CATransition *transition = [CATransition animation];
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    transition.type = kCATransitionFade;
    transition.duration = duration;
    return transition;
}

@end
