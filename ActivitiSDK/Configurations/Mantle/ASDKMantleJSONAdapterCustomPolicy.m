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

#import "ASDKMantleJSONAdapterCustomPolicy.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKMantleJSONAdapterCustomPolicy

- (NSSet *)serializablePropertyKeys:(NSSet *)propertyKeys
                           forModel:(id<MTLJSONSerializing>)model {
    // Mandatory property
    NSParameterAssert(self.policyBlock);
    
    NSSet *propertyKeysCopy = [propertyKeys copy];
    NSMutableSet *mutablePropertyKeysClone = [propertyKeys mutableCopy];
    NSDictionary *modelDictValue = [model dictionaryValue];
    
    for (NSString *key in propertyKeysCopy) {
        id val = [modelDictValue valueForKey:key];
        
        if (self.policyBlock (val, key)) {
            [mutablePropertyKeysClone removeObject:key];
        }
    }
    return [NSSet setWithSet:mutablePropertyKeysClone];
}

@end
