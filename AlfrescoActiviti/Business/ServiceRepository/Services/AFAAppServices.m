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

#import "AFAAppServices.h"
@import ActivitiSDK;

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAAppServices ()

@property (strong, nonatomic) dispatch_queue_t          appUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKAppNetworkServices    *appNetworkService;

@end

@implementation AFAAppServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.appUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.appNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKAppNetworkServiceProtocol)];
        self.appNetworkService.resultsQueue = self.appUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestRuntimeAppDefinitionsWithCompletionBlock:(AFAAppServicesRuntimeAppDefinitionsCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.appNetworkService fetchRuntimeAppDefinitionsWithCompletionBlock:
     ^(NSArray *runtimeAppDefinitions, NSError *error, ASDKModelPaging *paging) {
        if (!error && runtimeAppDefinitions) {
            AFALogVerbose(@"Fetched %lu runtime app definitions.", (unsigned long)runtimeAppDefinitions.count);
            
            // Filter any unused values from the application list i.e. apps that should
            // not be visible to the user
            NSPredicate *userApplicationsPredicate = [NSPredicate predicateWithFormat:@"SELF.deploymentID != nil"];
            NSArray *userApplicationsArr = [runtimeAppDefinitions filteredArrayUsingPredicate:userApplicationsPredicate];
            
            AFALogVerbose(@"Filtered out the app list to :%lu elements.", (unsigned long)userApplicationsArr.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(userApplicationsArr, nil, paging);
            });
        } else {
            AFALogError(@"An error occured while the user tried to fetch the runtime app definitions. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error, nil);
            });
        }
    }];
}

- (void)cancellAppNetworkRequests {
    [self.appNetworkService cancelAllAppNetworkOperations];
}

@end
