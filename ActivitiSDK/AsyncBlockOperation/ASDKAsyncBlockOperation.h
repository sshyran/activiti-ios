/*******************************************************************************
 * Copyright (C) 2005-2018 Alfresco Software Limited.
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

#import <Foundation/Foundation.h>

@class ASDKAsyncBlockOperation;
typedef void (^ASDKAsyncBlock)(ASDKAsyncBlockOperation * _Nonnull);

@interface ASDKAsyncBlockOperation : NSOperation

@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, strong, nullable) ASDKAsyncBlock block;
@property (strong, nonatomic) id _Nullable result;

- (nonnull instancetype)initWithBlock:(nonnull ASDKAsyncBlock)block;
+ (nonnull instancetype)blockOperationWithBlock:(nonnull ASDKAsyncBlock)block;
- (void)complete;

@end
