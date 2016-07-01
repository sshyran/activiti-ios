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

#import "ASDKModelUser.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@implementation ASDKModelUser

#pragma mark -
#pragma mark MTLJSONSerializing Delegate

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSMutableDictionary *inheretedPropertyKeys = [[NSMutableDictionary alloc] init];
    
        [inheretedPropertyKeys addEntriesFromDictionary:@{//Objc property       JSON property
                                                          @"userID"             : @"id",
                                                          @"userFirstName"      : @"firstName",
                                                          @"userLastName"       : @"lastName",
                                                          @"email"              : @"email",
                                                          @"externalID"         : @"externalId",
                                                          @"pictureID"          : @"pictureId"
                                                          }];

    
    return inheretedPropertyKeys;
}

#pragma mark -
#pragma mark Value transformations

+ (NSValueTransformer *)userIDJSONTransformer {
    return self.valueTransformerForIDs;
}


#pragma mark -
#pragma mark Convenience methods

- (NSString *)normalisedName {
    NSString *contributorName = nil;
    if (self.userFirstName.length) {
        contributorName = self.userFirstName;
    }
    
    if (self.userLastName.length) {
        if (contributorName.length) {
            contributorName = [contributorName stringByAppendingFormat:@" %@", self.userLastName];
        } else {
            contributorName = self.userLastName;
        }
    }
    
    return contributorName;
}


@end
