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

#import "AFAServiceRepository.h"
#import <libkern/OSAtomic.h>
#import "AFALogConfiguration.h"

static const int activitiLogLevel = AFA_LOG_LEVEL_VERBOSE; // | AFA_LOG_FLAG_TRACE;

@interface AFAServiceRepository () {
    OSSpinLock _spinLock;
}

@property (strong, nonatomic) NSMutableDictionary *serviceRepository;
@property (strong, nonatomic) NSArray *serviceDescriptions;

@end

@implementation AFAServiceRepository

#pragma mark -
#pragma mark Singleton

+ (instancetype)sharedRepository {
    static dispatch_once_t onceToken;
    static AFAServiceRepository *sharedRepository = nil;
    
    dispatch_once(&onceToken, ^{
        sharedRepository = [[super alloc] initUniqueInstance];
    });
    
    return sharedRepository;
}


#pragma mark -
#pragma mark Life cycle

- (instancetype)initUniqueInstance {
    self = [super init];
    
    if (self) {
        self.serviceRepository = [NSMutableDictionary dictionary];
        _spinLock = OS_SPINLOCK_INIT;
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)registerServiceObject:(id)serviceObject
                   forPurpose:(AFAServiceObjectType)serviceObjectType {
    NSParameterAssert(serviceObject);
    
    AFALogVerbose(@"Registered service object of type :%@", NSStringFromClass([serviceObject class]));
    
    OSSpinLockLock(&_spinLock);
    [self.serviceRepository setObject:serviceObject
                               forKey:@(serviceObjectType)];
    OSSpinLockUnlock(&_spinLock);
}

- (id)serviceObjectForPurpose:(AFAServiceObjectType)serviceObjectType {
    OSSpinLockLock(&_spinLock);
    id serviceObject = [self.serviceRepository objectForKey:@(serviceObjectType)];
    OSSpinLockUnlock(&_spinLock);
    
    return serviceObject;
}

- (void)removeServiceForPurpose:(AFAServiceObjectType)serviceObjectType {
    AFALogVerbose(@"Removed service object of type:%@", NSStringFromClass([self.serviceRepository[@(serviceObjectType)] class]));
    
    OSSpinLockLock(&_spinLock);
    [self.serviceRepository removeObjectForKey:@(serviceObjectType)];
    OSSpinLockUnlock(&_spinLock);
}

@end
