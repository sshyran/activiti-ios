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

// Models
#import "ASDKModelBase.h"
#import "ASDKModelFormField.h"
#import "ASDKModelFormOutcome.h"
#import "ASDKFormFieldValueRequestRepresentation.h"

// Cells
#import "ASDKFormHeaderCollectionReusableView.h"
#import "ASDKFormFooterCollectionReusableView.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

@interface ASDKFormCollectionViewController () <ASDKFormRenderEngineValueTransactionsProtocol>

@end

@implementation ASDKFormCollectionViewController


#pragma mark -
#pragma mark Life cycle

- (void)viewDidLoad {
    // Adjust collenction's view estimated item size
    UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *) self.collectionViewLayout;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.estimatedItemSize = CGSizeMake(CGRectGetWidth(self.view.frame), flowLayout.itemSize.height);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSArray *selectedItemsIndexPaths = [self.collectionView indexPathsForSelectedItems];
    for (NSIndexPath *indexPath in selectedItemsIndexPaths) {
        [self.collectionView deselectItemAtIndexPath:indexPath
                                            animated:NO];
        [self refreshContentForCellAtIndexPath:indexPath];
    }
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
    [self.collectionView performBatchUpdates:^{
        // Check for sections to insert
        NSIndexSet *sectionInsertIndexSet = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeInsertSection)];
        if (sectionInsertIndexSet.count) {
            [self.collectionView insertSections:sectionInsertIndexSet];
        }
        
        // Check for sections to delete
        NSIndexSet *sectionDeleteIndexSet = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeRemoveSection)];
        if (sectionDeleteIndexSet.count) {
            [self.collectionView deleteSections:sectionDeleteIndexSet];
        }
        
        // Check for rows to insert
        NSArray *rowsToInsert = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeInsertRow)];
        if (rowsToInsert.count) {
            [self.collectionView insertItemsAtIndexPaths:rowsToInsert];
        }
        
        // Check for rows to delete
        NSArray *rowsToDelete = operationsBatch[@(ASDKFormRenderEngineControllerOperationTypeRemoveRow)];
        if (rowsToDelete.count) {
            [self.collectionView deleteItemsAtIndexPaths:rowsToDelete];
        }
        
    } completion:nil];
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
    
    // Acquire the model object to set up the cell
    ASDKModelBase *modelObject = nil;
    if ([self.dataSource respondsToSelector:@selector(modelForIndexPath:)]) {
        modelObject = [self.dataSource modelForIndexPath:indexPath];
    }
    
    if ([modelObject isKindOfClass:[ASDKModelFormField class]]) {
        [cell setupCellWithFormField:(ASDKModelFormField *)modelObject];
    } else {
        [cell setupCellWithFormOutcome:(ASDKModelFormOutcome *)modelObject
                     enableFormOutcome:self.dataSource.isReadOnlyForm ? NO : [self.dataSource areFormFieldMetadataValuesValid]];
    }
    
    // Link the ASDKFormRenderEngineValueTransactionsProtocol delegate
    if ([cell respondsToSelector:@selector(setDelegate:)]) {
        cell.delegate = self;
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // We first make sure we don't handle cell taps for the outcome section
    // TODO: Adjust the the form outcome index paths after insertions or deletions
    if (![[self.dataSource indexPathsOfFormOutcomes] containsObject:indexPath]) {
        if ([self.navigationDelegate respondsToSelector:@selector(prepareToPresentDetailController:)]) {
            UIViewController<ASDKFormFieldDetailsControllerProtocol> *childController = [self.dataSource childControllerForFormField:(ASDKModelFormField *)[self.dataSource modelForIndexPath:indexPath]];
            // Child controllers will have to delegate changes on model updates using the ASDKFormRenderEngineValueTransactionsProtocol
            childController.valueTransactionDelegate = self;
            
            if ([childController isKindOfClass:ASDKDynamicTableFormFieldDetailsViewController.class]) {
                ASDKDynamicTableFormFieldDetailsViewController *dynamicTableDetailsViewController = (ASDKDynamicTableFormFieldDetailsViewController *) childController;
                dynamicTableDetailsViewController.navigationDelegate = self.navigationDelegate;
            }
            
            // If there is controller assigned to the selected form field notify the delegate
            // that it can begin preparing for presentation
            if (childController) {
                [self.navigationDelegate prepareToPresentDetailController:childController];
            }
        }
    }
}


#pragma mark -
#pragma mark Convenience methods

- (void)refreshContentForCellAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell<ASDKFormCellProtocol> *cell = (UICollectionViewCell<ASDKFormCellProtocol> *)[self.collectionView cellForItemAtIndexPath:indexPath];
    
    ASDKModelBase *modelObject = nil;
    if ([self.dataSource respondsToSelector:@selector(modelForIndexPath:)]) {
        modelObject = [self.dataSource modelForIndexPath:indexPath];
    }

    if ([modelObject isKindOfClass:[ASDKModelFormField class]]) {
        if (modelObject )
        [cell setupCellWithFormField:(ASDKModelFormField *)modelObject];
    } else {
        [cell setupCellWithFormOutcome:(ASDKModelFormOutcome *)modelObject
                     enableFormOutcome:self.dataSource.isReadOnlyForm ? NO : [self.dataSource areFormFieldMetadataValuesValid]];
    }
}
@end
