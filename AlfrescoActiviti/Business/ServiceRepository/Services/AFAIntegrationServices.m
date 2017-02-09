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

#import "AFAIntegrationServices.h"
@import ActivitiSDK;

// Configurations
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAIntegrationServices ()

@property (strong, nonatomic) dispatch_queue_t                  integrationUpdatesProcessingQueue;
@property (strong, nonatomic) ASDKIntegrationNetworkServices    *integrationNetworkService;

@end

@implementation AFAIntegrationServices


#pragma mark -
#pragma mark Life cycle

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.integrationUpdatesProcessingQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.`%@ProcessingQueue", [NSBundle mainBundle].bundleIdentifier, NSStringFromClass([self class])] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // Acquire and set up the app network service
        ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
        self.integrationNetworkService = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKIntegrationNetworkServiceProtocol)];
        self.integrationNetworkService.resultsQueue = self.integrationUpdatesProcessingQueue;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)requestIntegrationAccountsWithCompletionBlock:(AFAIntegrationAccountListCompletionBlock)completionBlock {
    NSParameterAssert(completionBlock);
    
    [self.integrationNetworkService fetchIntegrationAccountsWithCompletionBlock:^(NSArray *accounts, NSError *error, ASDKModelPaging *paging) {
        if (!error && accounts) {
            AFALogVerbose(@"Fetched %lu integration account entries", (unsigned long)accounts.count);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock (accounts, nil, paging);
            });
        } else {
            AFALogError(@"An error occured while fetching the integration accounts list. Reason:%@", error.localizedDescription);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(nil, error, nil);
            });
        }
    }];
}

- (void)requestUploadIntegrationContentForTaskID:(NSString *)taskID
                              withRepresentation:(ASDKIntegrationNodeContentRequestRepresentation *)nodeContentRepresentation
                                  completionBloc:(AFAIntegrationContentUploadCompletionBlock)completionBlock {
    NSParameterAssert(taskID);
    NSParameterAssert(nodeContentRepresentation);
    NSParameterAssert(completionBlock);
    
    nodeContentRepresentation.isLink = NO;
    [self.integrationNetworkService uploadIntegrationContentForTaskID:taskID
                                                   withRepresentation:nodeContentRepresentation
                                                      completionBlock:^(ASDKModelContent *contentModel, NSError *error) {
                                                          if (!error) {
                                                              AFALogVerbose(@"Successfully uploaded integration content for task with ID:%@", taskID);
                                                              
                                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                                  completionBlock(contentModel, nil);
                                                              });
                                                          } else {
                                                              AFALogError(@"An error occured while uploading integration content. Rason::%@", error.localizedDescription);
                                                              
                                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                                  completionBlock(nil, error);
                                                              });
                                                          }
                                                      }];
}


@end
