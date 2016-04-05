/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
 *
 * This file is part of the Alfresco Activiti iOS App.
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

#import "AppDelegate.h"
#import "UIColor+AFATheme.h"
#import "AFALogFormatter.h"
#import "AFAServiceRepository.h"
#import "AFAThumbnailManager.h"
@import HockeySDK;
#import <Lookback/Lookback.h>

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // HockeyApp SDK integration
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"27f3ab835014bff7256377ca7c2a7e03"];
    [[BITHockeyManager sharedHockeyManager] startManager];
    [[BITHockeyManager sharedHockeyManager].authenticator
     authenticateInstallation];
    
    // Cocoa Lumberjack integration
    [[DDASLLogger sharedInstance] setLogFormatter:[AFALogFormatter new]];
    [[DDTTYLogger sharedInstance] setLogFormatter:[AFALogFormatter new]];
    
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // We're enabling debugger colors if you have installed the XCode colors plugin
    // More details here: https://github.com/robbiehanson/XcodeColors
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
    
    // Lookback SDK integration
    [Lookback setupWithAppToken:@"5bSBFKwaFzFHeXMdt"];
    [Lookback sharedLookback].shakeToRecord = YES;
    [Lookback sharedLookback].options.onStartedUpload = ^(NSURL *destinationURL, NSDate *sessionStartedAt) {
        // Copy the link just for recent recordings
        if(fabs([sessionStartedAt timeIntervalSinceNow]) < 60.0f * 60.0f)
            AFALogVerbose(@"The bug reported video's URL has been copied into the clipboard:%@", destinationURL);
            [UIPasteboard generalPasteboard].URL = destinationURL;
    };
    
    application.delegate.window.backgroundColor = [UIColor windowBackgroundColor];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Clean up image cache
    AFAThumbnailManager *thumbnailsManager = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeThumbnailManager];
    [thumbnailsManager cleanupMemoryCache];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
}

@end
