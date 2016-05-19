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

@import UIKit;
#import "ASDKIntegrationDataSourceDelegate.h"

@protocol ASDKIntegrationDataSourceProtocol <UITableViewDataSource>

@property (weak, nonatomic) id<ASDKIntegrationDataSourceDelegate> delegate;

/**
 *  Triggers an internal refresh operation on the data source object.
 *  The data source might have to fetch remote data and if that's the case
 *  the status will be updated via the data source delegate implementation.
 */
- (void)refreshDataSourceInformation;

/**
 *  Fetches and returns an item from the date source at a provided index path
 *
 *  @param indexPath Index path for which the items is retrieved
 *
 *  @return Object found at the specified index path
 */
- (id)itemAtIndexPath:(NSIndexPath *)indexPath;

@optional
- (BOOL)isItemAtIndexPathAFolder:(NSIndexPath *)indexPath;
- (NSString *)nodeTitleForIndexPath:(NSIndexPath *)indexPath;

@end
