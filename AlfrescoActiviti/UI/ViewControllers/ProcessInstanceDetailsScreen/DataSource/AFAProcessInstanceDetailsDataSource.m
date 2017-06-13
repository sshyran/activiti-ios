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

#import "AFAProcessInstanceDetailsDataSource.h"

// Models
#import "AFATableControllerProcessInstanceDetailsModel.h"
#import "AFATableControllerProcessInstanceTasksModel.h"
#import "AFATableControllerProcessInstanceContentModel.h"
#import "AFATableControllerCommentModel.h"
#import "AFAGenericFilterModel.h"

// Cell factories
#import "AFATableControllerProcessInstanceDetailsCellFactory.h"
#import "AFATableControllerProcessInstanceTasksCellFactory.h"
#import "AFATableControllerContentCellFactory.h"
#import "AFATableControllerCommentCellFactory.h"

// Managers
#import "AFAProcessServices.h"
#import "AFAServiceRepository.h"
#import "AFAQueryServices.h"

@implementation AFAProcessInstanceDetailsDataSource

- (instancetype)initWithProcessInstanceID:(NSString *)processInstanceID
                               themeColor:(UIColor *)themeColor {
    self = [super init];
    
    if (self) {
        _processInstanceID = processInstanceID;
        _themeColor = themeColor;
        _sectionModels = [NSMutableDictionary dictionary];
        _cellFactories = [NSMutableDictionary dictionary];
        _tableController = [AFATableController new];
        
        [self setUpCellFactoriesWithThemeColor:themeColor];
        
        // Set the default cell factory to process instace details
        self.tableController.cellFactory = [self cellFactoryForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
    }
    
    return self;
}


#pragma mark -
#pragma mark Public interface

- (void)processInstanceDetailsWithCompletionBlock:(void (^)(NSError *error, BOOL registerCellActions))completionBlock {
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices requestProcessInstanceDetailsForID:self.processInstanceID
                                        completionBlock:^(ASDKModelProcessInstance *processInstance, NSError *error) {
                                            __strong typeof(self) strongSelf = weakSelf;
                                            
                                            BOOL registerCellActions = NO;
                                            
                                            if (!error) {
                                                AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [AFATableControllerProcessInstanceDetailsModel new];
                                                processInstanceDetailsModel.currentProcessInstance = processInstance;
                                                
                                                if (!strongSelf.sectionModels[@(AFAProcessInstanceDetailsSectionTypeDetails)]) {
                                                    registerCellActions = YES;
                                                }
                                                
                                                strongSelf.sectionModels[@(AFAProcessInstanceDetailsSectionTypeDetails)] = processInstanceDetailsModel;
                                                [strongSelf updateTableControllerForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
                                            }
                                            
                                            if (completionBlock) {
                                                completionBlock(error, registerCellActions);
                                            }
                                        }];
}

- (void)processInstanceActiveAndCompletedTasksWithCompletionBlock:(void (^)(NSError *error))completionBlock {
    AFAQueryServices *queryServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeQueryServices];
    
    dispatch_group_t activeAndCompletedTasksGroup = dispatch_group_create();
    
    AFAGenericFilterModel *activeTasksFilter = [AFAGenericFilterModel new];
    activeTasksFilter.processInstanceID = self.processInstanceID;
    
    AFATableControllerProcessInstanceTasksModel *processInstanceTasksModel = [AFATableControllerProcessInstanceTasksModel new];
    AFATableControllerProcessInstanceDetailsModel *processInstanceDetailsModel = [self reusableTableControllerModelForSectionType:AFAProcessInstanceDetailsSectionTypeDetails];
    processInstanceTasksModel.isStartFormDefined = processInstanceDetailsModel.currentProcessInstance.isStartFormDefined;
    
    __block BOOL hadEncounteredAnError = NO;
    dispatch_group_enter(activeAndCompletedTasksGroup);
    [queryServices requestTaskListWithFilter:activeTasksFilter
                             completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                 if (hadEncounteredAnError) {
                                     return;
                                 } else {
                                     hadEncounteredAnError = error ? YES : NO;
                                     if (!hadEncounteredAnError) {
                                         processInstanceTasksModel.activeTasks = taskList;
                                     } else {
                                         if (completionBlock) {
                                             completionBlock(error);
                                         }
                                     }
                                     dispatch_group_leave(activeAndCompletedTasksGroup);
                                 }
                             }];
    
    dispatch_group_enter(activeAndCompletedTasksGroup);
    
    AFAGenericFilterModel *completedTasksFilter = [AFAGenericFilterModel new];
    completedTasksFilter.processInstanceID = self.processInstanceID;
    completedTasksFilter.state = AFAGenericFilterStateTypeCompleted;
    
    [queryServices requestTaskListWithFilter:completedTasksFilter
                             completionBlock:^(NSArray *taskList, NSError *error, ASDKModelPaging *paging) {
                                 if (hadEncounteredAnError) {
                                     return;
                                 } else {
                                     hadEncounteredAnError = error ? YES : NO;
                                     if (!hadEncounteredAnError) {
                                         processInstanceTasksModel.completedTasks = taskList;
                                     } else {
                                         if (completionBlock) {
                                             completionBlock(error);
                                         }
                                     }
                                     dispatch_group_leave(activeAndCompletedTasksGroup);
                                 }
                             }];
    
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(activeAndCompletedTasksGroup, dispatch_get_main_queue(),^{
        __strong typeof(self) strongSelf = weakSelf;
        if (!hadEncounteredAnError) {
            strongSelf.sectionModels[@(AFAProcessInstanceDetailsSectionTypeTaskStatus)] = processInstanceTasksModel;
            [strongSelf updateTableControllerForSectionType:AFAProcessInstanceDetailsSectionTypeTaskStatus];
        }
        
        if (completionBlock) {
            completionBlock(nil);
        }
    });
}

- (void)processInstanceContentWithCompletionBlock:(void (^)(NSError *error))completionBlock {
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices
     requestProcessInstanceContentForProcessInstanceID:self.processInstanceID
     completionBlock:^(NSArray *contentList, NSError *error) {
         __strong typeof(self) strongSelf = weakSelf;
         
         if (!error) {
             AFATableControllerProcessInstanceContentModel *processInstanceContentModel = [AFATableControllerProcessInstanceContentModel new];
             processInstanceContentModel.attachedContentArr = contentList;
             strongSelf.sectionModels[@(AFAProcessInstanceDetailsSectionTypeContent)] = processInstanceContentModel;
             [strongSelf updateTableControllerForSectionType:AFAProcessInstanceDetailsSectionTypeContent];
             strongSelf.tableController.isEditable = NO;
         }
         
         if (completionBlock) {
             completionBlock(error);
         }
         
     }];
}

- (void)processInstanceCommentsWithCompletionBlock:(void (^)(NSError *error))completionBlock {
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    
    __weak typeof(self) weakSelf = self;
    [processServices
     requestProcessInstanceCommentsForID:self.processInstanceID
     withCompletionBlock:^(NSArray *commentList, NSError *error, ASDKModelPaging *paging) {
         __strong typeof(self) strongSelf = weakSelf;
         
         if (!error) {
             // Extract the updated result
             AFATableControllerCommentModel *processInstanceCommentModel = [AFATableControllerCommentModel new];
             
             NSSortDescriptor *newestCommentsSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(creationDate))
                                                                                            ascending:NO];
             processInstanceCommentModel.commentListArr = [commentList sortedArrayUsingDescriptors:@[newestCommentsSortDescriptor]];
             processInstanceCommentModel.paging = paging;
             
             strongSelf.sectionModels[@(AFAProcessInstanceDetailsSectionTypeComments)] = processInstanceCommentModel;
             [strongSelf updateTableControllerForSectionType:AFAProcessInstanceDetailsSectionTypeComments];
         }
         
         if (completionBlock) {
             completionBlock(error);
         }
     }];
}

- (void)deleteCurrentProcessInstanceWithCompletionBlock:(void (^)(NSError *error))completionBlock {
    AFAProcessServices *processServices = [[AFAServiceRepository sharedRepository] serviceObjectForPurpose:AFAServiceObjectTypeProcessServices];
    [processServices requestDeleteProcessInstanceWithID:self.processInstanceID
                                        completionBlock:^(BOOL isProcessInstanceDeleted, NSError *error) {
                                            if (completionBlock) {
                                                completionBlock(error);
                                            }
                                        }];
}

- (id)cellFactoryForSectionType:(AFAProcessInstanceDetailsSectionType)sectionType {
    return self.cellFactories[@(sectionType)];
}

- (id)reusableTableControllerModelForSectionType:(AFAProcessInstanceDetailsSectionType)sectionType {
    id reusableObject = nil;
    
    reusableObject = self.sectionModels[@(sectionType)];
    if (!reusableObject) {
        switch (sectionType) {
            case AFAProcessInstanceDetailsSectionTypeDetails: {
                reusableObject = [AFATableControllerProcessInstanceDetailsModel new];
            }
                break;
            case AFAProcessInstanceDetailsSectionTypeTaskStatus: {
                reusableObject = [AFATableControllerProcessInstanceTasksModel new];
            }
                break;
                
            case AFAProcessInstanceDetailsSectionTypeContent: {
                reusableObject = [AFATableControllerProcessInstanceContentModel new];
            }
                break;
                
            case AFAProcessInstanceDetailsSectionTypeComments: {
                reusableObject = [AFATableControllerCommentModel new];
            }
                
            default:
                break;
        }
    }
    
    return reusableObject;
}

- (void)updateTableControllerForSectionType:(AFAProcessInstanceDetailsSectionType)sectionType {
    self.tableController.model = [self reusableTableControllerModelForSectionType:sectionType];
    self.tableController.cellFactory = [self cellFactoryForSectionType:sectionType];
}


#pragma mark -
#pragma mark Private interface

- (void)setUpCellFactoriesWithThemeColor:(UIColor *)themeColor {
    // Register process instance details cell factory
    AFATableControllerProcessInstanceDetailsCellFactory *processInstanceDetailsCellFactory = [AFATableControllerProcessInstanceDetailsCellFactory new];
    processInstanceDetailsCellFactory.appThemeColor = themeColor;
    
    // Register process instance task status cell factory
    AFATableControllerProcessInstanceTasksCellFactory *processInstanceTasksCellFactory = [AFATableControllerProcessInstanceTasksCellFactory new];
    processInstanceTasksCellFactory.appThemeColor = themeColor;
    
    // Register process instance content cell factory
    AFATableControllerContentCellFactory *processInstanceContentCellFactory = [AFATableControllerContentCellFactory new];
    processInstanceContentCellFactory.appThemeColor = themeColor;
    
    // Register process instance comments cell factory
    AFATableControllerCommentCellFactory *processInstanceDetailsCommentCellFactory = [AFATableControllerCommentCellFactory new];
    
    self.cellFactories[@(AFAProcessInstanceDetailsSectionTypeDetails)] = processInstanceDetailsCellFactory;
    self.cellFactories[@(AFAProcessInstanceDetailsSectionTypeTaskStatus)] = processInstanceTasksCellFactory;
    self.cellFactories[@(AFAProcessInstanceDetailsSectionTypeContent)] = processInstanceContentCellFactory;
    self.cellFactories[@(AFAProcessInstanceDetailsSectionTypeComments)] = processInstanceDetailsCommentCellFactory;
}

@end
