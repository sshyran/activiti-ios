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

#import "ASDKFormCollectionViewController.h"
#import "ASDKDynamicTableFormFieldDetailsViewController.h"

// Constants
#import "ASDKFormRenderEngineConstants.h"

// Protocols
#import "ASDKFormRenderEngineValueTransactionsProtocol.h"
#import "ASDKFormCellProtocol.h"
#import "ASDKFormEngineControllerActionHandlerDelegate.h"

// Models
#import "ASDKModelFormField.h"
#import "ASDKModelFormOutcome.h"
#import "ASDKFormFieldValueRequestRepresentation.h"
#import "ASDKModelFormTab.h"

// Cells
#import "ASDKFormHeaderCollectionReusableView.h"
#import "ASDKFormFooterCollectionReusableView.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKFormCollectionViewController () <ASDKFormRenderEngineValueTransactionsProtocol,
                                                ASDKFormEngineControllerActionHandlerDelegate>

@end

@implementation ASDKFormCollectionViewController


#pragma mark -
#pragma mark Life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Adjust collenction's view estimated item size
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *) self.collectionViewLayout;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.itemSize = CGSizeMake(CGRectGetWidth(self.view.frame), flowLayout.itemSize.height);
    flowLayout.footerReferenceSize = CGSizeMake(flowLayout.footerReferenceSize.width, flowLayout.footerReferenceSize.height - 4);
    
    // If the data source has a form title defined display it
    if ([self.dataSource respondsToSelector:@selector(formTitle)]) {
        NSString *formTitle = self.dataSource.formTitle;
        
        if (formTitle.length) {
            UILabel *titleLabel = [[UILabel alloc] init];
            titleLabel.text = formTitle;
            titleLabel.font = [UIFont fontWithName:@"Avenir-Book"
                                              size:17];
            
            ASDKBootstrap *sdkBootstrap = [ASDKBootstrap sharedInstance];
            ASDKFormColorSchemeManager *colorSchemeManager = [sdkBootstrap.serviceLocator serviceConformingToProtocol:@protocol(ASDKFormColorSchemeManagerProtocol)];
            titleLabel.textColor = colorSchemeManager.navigationBarTitleAndControlsColor;
            
            [titleLabel sizeToFit];
            self.navigationItem.titleView = titleLabel;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Set the action handler to point to the active form controller instance
    self.renderDelegate.actionHandler.dataSourceActionDelegate = (id<ASDKFormEngineDataSourceActionHandlerDelegate>)self.dataSource;
    self.renderDelegate.actionHandler.formControllerActionDelegate = self;
    
    NSArray *selectedItemsIndexPaths = [self.collectionView indexPathsForSelectedItems];
    for (NSIndexPath *indexPath in selectedItemsIndexPaths) {
        [self.collectionView deselectItemAtIndexPath:indexPath
                                            animated:NO];
        [self refreshContentForCellAtIndexPath:indexPath];
    }
    
    [self.collectionViewLayout invalidateLayout];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark Actions

- (IBAction)onTapGesture:(id)sender {
    [self.collectionView endEditing:YES];
}


#pragma mark -
#pragma mark ASDKFormRenderEngineValueTransactionsProtocol

- (void)updatedMetadataValueForFormField:(ASDKModelFormField *)formFieldModel
                                  inCell:(UICollectionViewCell *)cell {
    for (NSIndexPath *indexPath in [self.dataSource indexPathsOfFormOutcomes]) {
        [self refreshContentForCellAtIndexPath:indexPath];
    }
}

- (void)completeFormWithOutcome:(ASDKModelFormOutcome *)formOutcomeModel {
    ASDKFormFieldValueRequestRepresentation *formFieldValuesRequestRepresentation = [ASDKFormFieldValueRequestRepresentation new];
    formFieldValuesRequestRepresentation.formFields = self.dataSource.visibleFormFields;
    formFieldValuesRequestRepresentation.outcome = self.dataSource.formHasUserdefinedOutcomes ? formOutcomeModel.name : nil;
    
    if ([self.renderDelegate respondsToSelector:@selector(completeFormWithFormFieldValueRequestRepresentation:)]) {
        [self.renderDelegate completeFormWithFormFieldValueRequestRepresentation:formFieldValuesRequestRepresentation];
    }
}


#pragma mark -
#pragma mark ASDKFormRenderEngineDataSource Delegate

- (void)requestControllerUpdateWithBatchOfOperations:(NSDictionary *)operationsBatch {
    // First check if there are any updates to perform
    NSIndexSet *sectionInsertIndexSet = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeInsertSection)];
    NSIndexSet *sectionDeleteIndexSet = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeRemoveSection)];
    NSArray *rowsToInsert = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeInsertRow)];
    NSArray *rowsToDelete = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeRemoveRow)];
    
    if (sectionInsertIndexSet.count ||
        sectionDeleteIndexSet.count ||
        rowsToInsert.count ||
        rowsToDelete.count) {
        [self.collectionView performBatchUpdates:^{
            // Check for sections to insert
            if (sectionInsertIndexSet.count) {
                [self.collectionView insertSections:sectionInsertIndexSet];
            }
            
            // Check for sections to delete
            if (sectionDeleteIndexSet.count) {
                [self.collectionView deleteSections:sectionDeleteIndexSet];
            }
            
            // Check for rows to insert
            if (rowsToInsert.count) {
                [self.collectionView insertItemsAtIndexPaths:rowsToInsert];
            }
            
            // Check for rows to delete
            if (rowsToDelete.count) {
                [self.collectionView deleteItemsAtIndexPaths:rowsToDelete];
            }
        } completion:^(BOOL finished) {
            [self.collectionViewLayout invalidateLayout];
        }];
    }
}


#pragma mark -
#pragma mark ASDKFormEngineControllerActionHandlerDelegate 

- (void)saveForm {
    ASDKFormFieldValueRequestRepresentation *formFieldValuesRequestRepresentation = [ASDKFormFieldValueRequestRepresentation new];
    formFieldValuesRequestRepresentation.jsonAdapterType = ASDKRequestRepresentationJSONAdapterTypeExcludeNilValues;
    formFieldValuesRequestRepresentation.formFields = self.dataSource.visibleFormFields;
    
    if ([self.renderDelegate respondsToSelector:@selector(saveFormWithFormFieldValueRequestRepresentation:)]) {
        [self.renderDelegate saveFormWithFormFieldValueRequestRepresentation:formFieldValuesRequestRepresentation];
    }
}


#pragma mark -
#pragma mark UICollectionView DataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    NSInteger numberOfSections = 0;
    
    if ([self.dataSource respondsToSelector:@selector(numberOfSectionsForCurrentFormDescription)]) {
        numberOfSections = [self.dataSource numberOfSectionsForCurrentFormDescription];
    }
    
    return numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    NSInteger numberOfItemsInSection = 0;
    
    if ([self.dataSource respondsToSelector:@selector(numberOfFormFieldsForSection:)]) {
        numberOfItemsInSection = [self.dataSource numberOfFormFieldsForSection:section];
    }
    
    return numberOfItemsInSection;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout*)collectionViewLayout
referenceSizeForHeaderInSection:(NSInteger)section {
    CGSize sectionSize = CGSizeZero;
    
    if ([self.dataSource respondsToSelector:@selector(sectionHeaderTitleForIndexPath:)]) {
        NSString *sectionHeaderTitle =
        [self.dataSource sectionHeaderTitleForIndexPath:[NSIndexPath indexPathForRow:0
                                                                           inSection:section]];
        if (sectionHeaderTitle) {
            sectionSize = ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize;
        }
    }
    
    return sectionSize;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {
    UICollectionReusableView *reusableview = nil;
    
    if ([UICollectionElementKindSectionHeader isEqualToString:kind]) {
        ASDKFormHeaderCollectionReusableView *sectiomHeaderView =
        [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                           withReuseIdentifier:kASDKCellIDFormFieldHeaderRepresentation
                                                  forIndexPath:indexPath];
        if ([self.dataSource respondsToSelector:@selector(sectionHeaderTitleForIndexPath:)]) {
            sectiomHeaderView.headerSectionLabel.text = [self.dataSource sectionHeaderTitleForIndexPath:indexPath];
        }
        
        reusableview = sectiomHeaderView;
    } else if ([UICollectionElementKindSectionFooter isEqualToString:kind]) {
        ASDKFormFooterCollectionReusableView *sectionFooterView =
        [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                           withReuseIdentifier:kASDKCellIDFormFieldFooterRepresentation
                                                  forIndexPath:indexPath];
        
        reusableview = sectionFooterView;
    }
    
    NSParameterAssert(reusableview);
    return reusableview;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *reuseIdentifier = nil;
    
    // Acquire the reuse identifier for the current index path object
    if ([self.dataSource respondsToSelector:@selector(cellIdentifierForIndexPath:)]) {
        reuseIdentifier = [self.dataSource cellIdentifierForIndexPath:indexPath];
    }
    
    UICollectionViewCell<ASDKFormCellProtocol> *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier
                                                                                                 forIndexPath:indexPath];
    [self setupCellWithContent:cell
                  forIndexPath:indexPath];
    
    // Link the ASDKFormRenderEngineValueTransactionsProtocol delegate
    if ([cell respondsToSelector:@selector(setDelegate:)]) {
        cell.delegate = self;
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // We first make sure we don't handle cell taps for the outcome section
    if (![[self.dataSource indexPathsOfFormOutcomes] containsObject:indexPath]) {
        UIViewController *detailController = nil;
        
        if (ASDKFormRenderEngineDataSourceViewModeTabs == self.dataSource.dataSourceViewMode) {
            if ([self.renderDelegate respondsToSelector:@selector(setupWithTabFormDescription:)]) {
                UICollectionViewController<ASDKFormControllerNavigationProtocol> *formFieldsController =
                (UICollectionViewController<ASDKFormControllerNavigationProtocol> *)[self.renderDelegate setupWithTabFormDescription:[self.dataSource formDescriptionForTabAtIndexPath:indexPath]];
                
                formFieldsController.navigationDelegate = self.navigationDelegate;
                
                detailController = formFieldsController;
            }
        } else {
            if ([self.navigationDelegate respondsToSelector:@selector(prepareToPresentDetailController:)]) {
                UIViewController<ASDKFormFieldDetailsControllerProtocol> *childController = [self.dataSource childControllerForFormField:(ASDKModelFormField *)[self.dataSource modelForIndexPath:indexPath]];
                // Child controllers will have to delegate changes on model updates using the ASDKFormRenderEngineValueTransactionsProtocol
                childController.valueTransactionDelegate = self;
                
                if ([childController isKindOfClass:ASDKDynamicTableFormFieldDetailsViewController.class]) {
                    ASDKDynamicTableFormFieldDetailsViewController *dynamicTableDetailsViewController = (ASDKDynamicTableFormFieldDetailsViewController *) childController;
                    dynamicTableDetailsViewController.navigationDelegate = self.navigationDelegate;
                }
                
                detailController = childController;
            }
        }
        
        // If there is controller assigned to the selected form field notify the delegate
        // that it can begin preparing for presentation
        if (detailController) {
            [self.navigationDelegate prepareToPresentDetailController:detailController];
        }
    }
}


#pragma mark -
#pragma mark Convenience methods

- (void)refreshContentForCellAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell<ASDKFormCellProtocol> *cell = (UICollectionViewCell<ASDKFormCellProtocol> *)[self.collectionView cellForItemAtIndexPath:indexPath];
    [self setupCellWithContent:cell
                  forIndexPath:indexPath];
}

- (void)setupCellWithContent:(UICollectionViewCell<ASDKFormCellProtocol> *)cell
                forIndexPath:(NSIndexPath *)indexPath {
    // Acquire the model object to set up the cell
    ASDKModelAttributable *modelObject = nil;
    if ([self.dataSource respondsToSelector:@selector(modelForIndexPath:)]) {
        modelObject = [self.dataSource modelForIndexPath:indexPath];
    }
    
    if ([modelObject isKindOfClass:[ASDKModelFormField class]]) {
        [cell setupCellWithFormField:(ASDKModelFormField *)modelObject];
    } else if ([modelObject isKindOfClass:[ASDKModelFormTab class]]) {
        [cell setupCellWithFormTab:(ASDKModelFormTab *)modelObject];
    } else {
        BOOL isFormOutcomeEnabled = YES;
        
        if (self.dataSource.isReadOnlyForm) {
            isFormOutcomeEnabled = NO;
        } else {
            isFormOutcomeEnabled = [self.dataSource areFormFieldMetadataValuesValid];
        }
        
        [cell setupCellWithFormOutcome:(ASDKModelFormOutcome *)modelObject
                     enableFormOutcome:isFormOutcomeEnabled];
    }
}

@end
