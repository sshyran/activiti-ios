/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import <Foundation/Foundation.h>
#import "AFABaseModel.h"

@class ASDKModelServerConfiguration;

@interface AFACredentialModel : AFABaseModel

@property (strong, nonatomic) NSString *hostname;
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@property (strong, nonatomic) NSString *port;
@property (strong, nonatomic) NSString *serviceDocument;
@property (assign, nonatomic) BOOL     rememberCredentials;
@property (assign, nonatomic) BOOL     isCommunicationOverSecureLayer;
@property (strong, nonatomic) ASDKModelServerConfiguration *serverConfiguration;

@end
