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

#import <UIKit/UIKit.h>

@class AFALoginModel;

// Enumerations
typedef NS_ENUM(NSInteger, AFALoginCredentialsType) {
    AFALoginCredentialsTypeCloud,
    AFALoginCredentialsTypePremise
};

typedef NS_ENUM(NSInteger, AFACloudLoginSectionType) {
    AFACloudLoginSectionTypeAccountDetails,
    AFACloudLoginSectionTypeSignIn,
    AFACloudLoginSectionTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFAPremiseLoginSectionType) {
    AFAPremiseLoginSectionTypeAccountDetails = 0,
    AFAPremiseLoginSectionTypeAdvanced,
    AFAPremiseLoginSectionTypeSignIn,
    AFAPremiseLoginSectionTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFACloudLoginCredentialsCellType) {
    AFACloudLoginCredentialsCellTypeEmail = 0,
    AFACloudLoginCredentialsCellTypePassword,
    AFACloudLoginCredentialsCellTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFAPremiseLoginCredentialsCellType) {
    AFAPremiseLoginCredentialsCellTypeEmail = 0,
    AFAPremiseLoginCredentialsCellTypePassword,
    AFAPremiseLoginCredentialsCellTypeHostname,
    AFAPremiseLoginCredentialsCellTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFAPremiseLoginAdvancedCredentialsCellType) {
    AFAPremiseLoginAdvancedCredentialsCellTypeSecurityLayer = 0,
    AFAPremiseLoginAdvancedCredentialsCellTypePort,
    AFAPremiseLoginAdvancedCredentialsCellTypeServiceDocument,
    AFAPremiseLoginAdvancedCredentialsCellTypeEnumCount
};

typedef NS_ENUM(NSInteger, AFASignInSectionCellType) {
    AFASignInSectionCellTypeRememberCredentials = 0,
    AFASignInSectionCellTypeSignIn,
    AFASignInSectionCellTypeEnumCount
};

typedef NS_OPTIONS(NSUInteger, AFALoginCredentialEditing) {
    AFALoginCredentialEditingFirstField  = 1<<0,
    AFALoginCredentialEditingSecondField = 1<<1,
};

typedef NS_ENUM(NSInteger, AFALoginCredentialsFocusFieldOrder) {
    AFALoginCredentialsFocusFieldOrderUsername = 0,
    AFALoginCredentialsFocusFieldOrderPassword,
    AFALoginCredentialsFocusFieldOrderHostname,
    AFALoginCredentialsFocusFieldOrderPort,
    AFALoginCredentialsFocusFieldOrderServiceDocument
};

@interface AFALoginCredentialsViewController : UIViewController

@property (assign, nonatomic) AFALoginCredentialsType        loginType;
@property (strong, nonatomic) AFALoginModel                  *loginModel;

@end
