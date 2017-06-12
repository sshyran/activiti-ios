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

@import UIKit;

@class AFATableController,
ASDKModelUser,
ASDKModelContent,
ASDKIntegrationNodeContentRequestRepresentation;

typedef NS_ENUM(NSInteger, AFATaskDetailsSectionType) {
    AFATaskDetailsSectionTypeTaskDetails = 0,
    AFATaskDetailsSectionTypeForm,
    AFATaskDetailsSectionTypeChecklist,
    AFATaskDetailsSectionTypeContributors,
    AFATaskDetailsSectionTypeFilesContent,
    AFATaskDetailsSectionTypeComments,
    AFATaskDetailsSectionTypeEnumCount
};

@protocol AFATaskDetailsDataSourceProtocol <NSObject>

@property (strong, nonatomic, readonly) UIColor     *themeColor;
@property (strong, nonatomic, readonly) NSString    *taskID;
@property (strong, nonatomic) NSMutableDictionary   *sectionModels;
@property (strong, nonatomic) AFATableController    *tableController;
@property (strong, nonatomic) NSMutableDictionary   *cellFactories;

- (instancetype)initWithTaskID:(NSString *)taskID
                    themeColor:(UIColor *)themeColor;

- (void)taskDetailsWithCompletionBlock:(void (^)(NSError *error, BOOL registerCellActions))completionBlock;
- (void)updateTaskDueDateWithDate:(NSDate *)dueDate;
- (void)deleteContentForTaskAtIndex:(NSInteger)index
                withCompletionBlock:(void (^)(BOOL isContentDeleted, NSError *error))completionBlock;
- (void)taskContributorsWithCompletionBlock:(void (^)(NSError *error))completionBlock;
- (void)removeInvolvementForUser:(ASDKModelUser *)user
             withCompletionBlock:(void (^)(BOOL isUserInvolved, NSError *error))completionBlock;
- (void)saveTaskForm;
- (void)taskContentWithCompletionBlock:(void (^)(NSError *error))completionBlock;
- (void)taskCommentsWithCompletionBlock:(void (^)(NSError *error))completionBlock;
- (void)taskChecklistWithCompletionBlock:(void (^)(NSError *error))completionBlock;
- (void)updateCurrentTaskDetailsWithCompletionBlock:(void (^)(BOOL isTaskUpdated, NSError *error))completionBlock;
- (void)completeTaskWithCompletionBlock:(void (^)(BOOL isTaskCompleted, NSError *error))completionBlock;
- (void)claimTaskWithCompletionBlock:(void (^)(BOOL isTaskClaimed, NSError *error))completionBlock;
- (void)unclaimTaskWithCompletionBlock:(void (^)(BOOL isTaskClaimed, NSError *error))completionBlock;
- (void)updateChecklistOrderWithCompletionBlock:(void (^)(NSError *error))completionBlock;
- (void)uploadIntegrationContentForNode:(ASDKIntegrationNodeContentRequestRepresentation *)nodeContentRepresentation
                    withCompletionBlock:(void (^)(NSError *error))completionBlock;

- (NSDate *)taskDueDate;
- (ASDKModelUser *)involvedUserAtIndex:(NSInteger)index;
- (ASDKModelContent *)attachedContentAtIndex:(NSInteger)index;

- (id)cellFactoryForSectionType:(AFATaskDetailsSectionType)sectionType;
- (id)reusableTableControllerModelForSectionType:(AFATaskDetailsSectionType)sectionType;
- (void)updateTableControllerForSectionType:(AFATaskDetailsSectionType)sectionType;

@end
