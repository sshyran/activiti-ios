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

#import <Foundation/Foundation.h>
#import "AFABaseModel.h"
#import "AFAProfileServices.h"

typedef NS_ENUM(NSUInteger, AFALoginViewModelAuthentificationState) {
    AFALoginViewModelAuthentificationStatePreparing,
    AFALoginViewModelAuthentificationStateInProgress,
    AFALoginViewModelAuthentificationStateAuthorized,
    AFALoginViewModelAuthentificationStateFailed,
    AFALoginViewModelAuthentificationStateCanceled,
    AFALoginViewModelAuthentificationStateLoggedOut
};

@interface AFALoginModel : AFABaseModel

@property (strong, nonatomic) NSAttributedString *usernameAttributedPlaceholderText;
@property (strong, nonatomic) NSAttributedString *passwordAttributedPlaceholderText;
@property (strong, nonatomic) NSAttributedString *hostnameAttributedPlaceholderText;
@property (assign, nonatomic) BOOL isCredentialInputInProgress;
@property (assign, nonatomic) AFALoginViewModelAuthentificationState authState;

- (void)updateHostNameEntry:(NSString *)hostname;
- (void)updateUserNameEntry:(NSString *)username;
- (void)updatePasswordEntry:(NSString *)password;
- (void)updateRememberCredentials:(BOOL)rememberCredentials;
- (void)updateCommunicationOverSecureLayer:(BOOL)secureLayer;

- (BOOL)canUserSignIn;
- (void)requestLoginWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock;
- (void)requestLogoutWithCompletionBlock:(AFAProfileServicesLoginCompletionBlock)completionBlock;
- (void)cancelLoginRequest;

@end
