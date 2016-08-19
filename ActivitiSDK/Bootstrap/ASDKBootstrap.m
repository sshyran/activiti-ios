/*******************************************************************************
 * Copyright (C) 2005-2016 Alfresco Software Limited.
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

#import "ASDKBootstrap.h"

// Log component imports
#import "ASDKLogConfiguration.h"
#import "ASDKLogFormatter.h"

// Service locator imports
#import "ASDKServiceLocator.h"

// Network services imports
#import "ASDKNetworkService.h"
#import "ASDKProfileNetworkServices.h"
#import "ASDKTaskNetworkServices.h"
#import "ASDKFilterNetworkServices.h"
#import "ASDKFormNetworkServices.h"
#import "ASDKAppNetworkServices.h"
#import "ASDKProcessInstanceNetworkServices.h"
#import "ASDKProcessDefinitionNetworkServices.h"
#import "ASDKUserNetworkServices.h"
#import "ASDKQuerryNetworkServices.h"
#import "ASDKIntegrationNetworkServices.h"

// Managers imports
#import "ASDKRequestOperationManager.h"
#import "ASDKParserOperationManager.h"
#import "ASDKServicePathFactory.h"
#import "ASDKProfileParserOperationWorker.h"
#import "ASDKTaskDetailsParserOperationWorker.h"
#import "ASDKTaskFormParserOperationWorker.h"
#import "ASDKAppParserOperationWorker.h"
#import "ASDKProcessParserOperationWorker.h"
#import "ASDKUserParserOperationWorker.h"
#import "ASDKIntegrationParserOperationWorker.h"
#import "ASDKDiskServices.h"
#import "ASDKFormRenderEngine.h"
#import "ASDKFormRenderEngineProtocol.h"
#import "ASDKFormColorSchemeManager.h"
#import "ASDKFormColorSchemeManagerProtocol.h"
#import "ASDKCSRFTokenStorage.h"

// Configurations imports
#import "ASDKBasicAuthentificationProvider.h"

// Model imports
#import "ASDKModelServerConfiguration.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

static const int activitiSDKLogLevel = ASDK_LOG_LEVEL_VERBOSE; // | ASDK_LOG_FLAG_TRACE;

@interface ASDKBootstrap ()

@property (strong, nonatomic) ASDKRequestOperationManager   *requestOperationManager;

@end

@implementation ASDKBootstrap

#pragma mark -
#pragma mark Singleton

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static ASDKBootstrap *sharedInstance = nil;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super alloc] initUniqueInstance];
    });
    
    return sharedInstance;
}

- (instancetype)initUniqueInstance {
    self = [super init];
    
    if (self) {
        ASDKLogVerbose(@"Logger component setup...OK");
        
        // Setup service locator component
        _serviceLocator = [ASDKServiceLocator new];
        
        ASDKLogVerbose(@"Service locator component...%@", _serviceLocator ? @"OK" : @"NOT_OK");
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)setupServicesWithServerConfiguration:(ASDKModelServerConfiguration *)serverConfiguration {
    _serverConfiguration = serverConfiguration;
    
    // Register available services with the service locator repository
    ASDKLogVerbose(@"Registering services...");
    
    // Create a service path factory with the passed server configuration
    ASDKServicePathFactory *servicePathFactory =
    [[ASDKServicePathFactory alloc] initWithHostAddress:self.serverConfiguration.hostAddressString
                                    serviceDocumentPath:self.serverConfiguration.serviceDocument
                                                   port:self.serverConfiguration.port
                                        overSecureLayer:self.serverConfiguration.isCommunicationOverSecureLayer];
    
    // Set up the request manager
    ASDKBasicAuthentificationProvider *basicAuthentificationProvider = [[ASDKBasicAuthentificationProvider alloc] initWithUserName:self.serverConfiguration.username
                                                                                                                          password:self.serverConfiguration.password];
    self.requestOperationManager = [[ASDKRequestOperationManager alloc] initWithBaseURL:servicePathFactory.baseURL
                                                                 authenticationProvider:basicAuthentificationProvider];
    // Set up the parser manager and register workers for it
    ASDKParserOperationManager *parserOperationManager = [ASDKParserOperationManager new];
    ASDKProfileParserOperationWorker *profileParserWorker = [ASDKProfileParserOperationWorker new];
    [parserOperationManager registerWorker:profileParserWorker
                               forServices:[profileParserWorker availableServices]];
    ASDKTaskDetailsParserOperationWorker *taskDetailsParserWorker = [ASDKTaskDetailsParserOperationWorker new];
    [parserOperationManager registerWorker:taskDetailsParserWorker
                               forServices:[taskDetailsParserWorker availableServices]];
    ASDKTaskFormParserOperationWorker *taskFormParserWorker = [ASDKTaskFormParserOperationWorker new];
    [parserOperationManager registerWorker:taskFormParserWorker
                               forServices:[taskFormParserWorker availableServices]];
    ASDKAppParserOperationWorker *appParserWorker = [ASDKAppParserOperationWorker new];
    [parserOperationManager registerWorker:appParserWorker
                               forServices:[appParserWorker availableServices]];
    ASDKUserParserOperationWorker *userParserWorker = [ASDKUserParserOperationWorker new];
    [parserOperationManager registerWorker:userParserWorker
                               forServices:[userParserWorker availableServices]];
    ASDKProcessParserOperationWorker *processParserWorker = [ASDKProcessParserOperationWorker new];
    [parserOperationManager registerWorker:processParserWorker
                               forServices:[processParserWorker availableServices]];
    ASDKIntegrationParserOperationWorker *integrationParserWorker = [ASDKIntegrationParserOperationWorker new];
    [parserOperationManager registerWorker:integrationParserWorker
                               forServices:[integrationParserWorker availableServices]];
    
    // Link the processing queues between the request and parser managers
    self.requestOperationManager.completionQueue = parserOperationManager.completionQueue;
    
    // Set up the disk services
    ASDKDiskServices *diskService = [ASDKDiskServices new];
    
    // Set up the CSRF token storage manager
    ASDKCSRFTokenStorage *tokenStorage = [ASDKCSRFTokenStorage new];
    
    // Set up the aplication newtork service
    ASDKAppNetworkServices *applicationNetworkService = [[ASDKAppNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                                 parserManager:parserOperationManager
                                                                                            servicePathFactory:servicePathFactory
                                                                                                  diskServices:diskService
                                                                                                  resultsQueue:nil];
    
    // Check for previously registered services and remove them first
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKAppNetworkServiceProtocol)]) {
        [_serviceLocator removeService:applicationNetworkService];
    }
    [_serviceLocator addService:applicationNetworkService];
    
    ASDKLogVerbose(@"App network services...%@", applicationNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the profile network service
    ASDKProfileNetworkServices *profileNetworkService = [[ASDKProfileNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                                     parserManager:parserOperationManager
                                                                                                servicePathFactory:servicePathFactory
                                                                                                      diskServices:diskService
                                                                                                      resultsQueue:nil];
    [profileNetworkService configureWithCSRFTokenStorage:tokenStorage];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKProfileNetworkServiceProtocol)]) {
        [_serviceLocator removeService:profileNetworkService];
    }
    [_serviceLocator addService:profileNetworkService];
    
    ASDKLogVerbose(@"Profile network services...%@", profileNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the task network service
    ASDKTaskNetworkServices *taskNetworkService = [[ASDKTaskNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                            parserManager:parserOperationManager
                                                                                       servicePathFactory:servicePathFactory
                                                                                             diskServices:diskService
                                                                                             resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKTaskNetworkServiceProtocol)]) {
        [_serviceLocator removeService:taskNetworkService];
    }
    [_serviceLocator addService:taskNetworkService];
    
    ASDKLogVerbose(@"Task network services...%@", taskNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the filter network service
    ASDKFilterNetworkServices *filterNetworkService = [[ASDKFilterNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                                  parserManager:parserOperationManager
                                                                                             servicePathFactory:servicePathFactory
                                                                                                   diskServices:diskService
                                                                                                   resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKFilterNetworkServiceProtocol)]) {
        [_serviceLocator removeService:filterNetworkService];
    }
    [_serviceLocator addService:filterNetworkService];
    
    ASDKLogVerbose(@"Filter network services...%@", filterNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the process instance network service
    
    ASDKProcessInstanceNetworkServices *processInstanceNetworkService =
    [[ASDKProcessInstanceNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                         parserManager:parserOperationManager
                                                    servicePathFactory:servicePathFactory
                                                          diskServices:diskService
                                                          resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKProcessInstanceNetworkServiceProtocol)]) {
        [_serviceLocator removeService:processInstanceNetworkService];
    }
    [_serviceLocator addService:processInstanceNetworkService];
    
    ASDKLogVerbose(@"Process instance network services...%@", processInstanceNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the process definition network service
    
    ASDKProcessDefinitionNetworkServices *processDefinitionNetworkService =
    [[ASDKProcessDefinitionNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                           parserManager:parserOperationManager
                                                      servicePathFactory:servicePathFactory
                                                            diskServices:diskService
                                                            resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKProcessDefinitionNetworkServiceProtocol)]) {
        [_serviceLocator removeService:processDefinitionNetworkService];
    }
    [_serviceLocator addService:processDefinitionNetworkService];
    
    ASDKLogVerbose(@"Process definition network services...%@", processDefinitionNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the user network service
    
    ASDKUserNetworkServices *userNetworkService =
    [[ASDKUserNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                              parserManager:parserOperationManager
                                         servicePathFactory:servicePathFactory
                                               diskServices:diskService
                                               resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKUserNetworkServiceProtocol)]) {
        [_serviceLocator removeService:userNetworkService];
    }
    [_serviceLocator addService:userNetworkService];
    
    ASDKLogVerbose(@"User network services...%@", userNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the form network service
    ASDKFormNetworkServices *formNetworkService = [[ASDKFormNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                            parserManager:parserOperationManager
                                                                                       servicePathFactory:servicePathFactory
                                                                                             diskServices:diskService
                                                                                             resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKFormNetworkServiceProtocol)]) {
        [_serviceLocator removeService:formNetworkService];
    }
    [_serviceLocator addService:formNetworkService];
    
    ASDKLogVerbose(@"Form network services...%@", formNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the query network service
    ASDKQuerryNetworkServices *queryNetworkService = [[ASDKQuerryNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                                                                 parserManager:parserOperationManager
                                                                                            servicePathFactory:servicePathFactory
                                                                                                  diskServices:diskService
                                                                                                  resultsQueue:nil];
    
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKQuerryNetworkServiceProtocol)]) {
        [_serviceLocator removeService:queryNetworkService];
    }
    [_serviceLocator addService:queryNetworkService];
    
    ASDKLogVerbose(@"Query network services...%@", queryNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up integration network service
    ASDKIntegrationNetworkServices *integrationNetworkService =
    [[ASDKIntegrationNetworkServices alloc] initWithRequestManager:self.requestOperationManager
                                                     parserManager:parserOperationManager
                                                servicePathFactory:servicePathFactory
                                                      diskServices:diskService
                                                      resultsQueue:nil];
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKIntegrationNetworkServiceProtocol)]) {
        [_serviceLocator removeService:integrationNetworkService];
    }
    [_serviceLocator addService:integrationNetworkService];
    
    ASDKLogVerbose(@"Integration network services...%@", integrationNetworkService ? @"OK" : @"NOT_OK");
    
    // Set up the form render engine service
    ASDKFormRenderEngine *formRenderEngine = [ASDKFormRenderEngine new];
    formRenderEngine.formNetworkServices = formNetworkService;
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKFormRenderEngineProtocol)]) {
        [_serviceLocator removeService:formRenderEngine];
    }
    [_serviceLocator addService:formRenderEngine];
    
    ASDKLogVerbose(@"Form render engine services...%@", formRenderEngine ? @"OK" : @"NOT_OK");
    
    // Set up the form color scheme manager
    ASDKFormColorSchemeManager *colorSchemeManager = [ASDKFormColorSchemeManager new];
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKFormColorSchemeManagerProtocol)]) {
        [_serviceLocator removeService:colorSchemeManager];
    }
    [_serviceLocator addService:colorSchemeManager];
    
    ASDKLogVerbose(@"Form color scheme manager...%@", colorSchemeManager ? @"OK" : @"NOT_OK");
    
    // Register the csrf token storage manager
    if ([_serviceLocator isServiceRegisteredForProtocol:@protocol(ASDKCSRFTokenStorageProtocol)]) {
        [_serviceLocator removeService:tokenStorage];
    }
    [_serviceLocator addService:tokenStorage];
    
    ASDKLogVerbose(@"CSRF token storage manager...%@", tokenStorage ? @"OK" : @"NOT_OK");
}

- (void)updateServerConfigurationCredentialsForUsername:(NSString *)username
                                               password:(NSString *)password {
    _serverConfiguration.username = username;
    _serverConfiguration.password = password;
    
    ASDKBasicAuthentificationProvider *authenticationProvider =
    [[ASDKBasicAuthentificationProvider alloc] initWithUserName:username
                                                       password:password];
    [self.requestOperationManager replaceAuthenticationProvider:authenticationProvider];
}

@end
