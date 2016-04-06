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

#import <UIKit/UIKit.h>

@class ASDKModelFormDescription,
ASDKModelBase,
ASDKModelFormField,
ASDKFormVisibilityConditionsProcessor;

typedef NS_ENUM(NSInteger, ASDKFormRenderEngineDataSourceType) {
    ASDKFormRenderEngineDataSourceTypeTask = 0,
    ASDKFormRenderEngineDataSourceTypeProcessDefinition,
};

@protocol ASDKFormRenderEngineDataSourceProtocol <NSObject>

/**
 *  Property meant to indicate the type of the data source, whether the form
 *  description has been provided from a task or from a process definition 
 *  i.e. process start forms.
 */
@property (assign, nonatomic) ASDKFormRenderEngineDataSourceType dataSourceType;

/**
 *  Property meant to hold a refference to visible form field objects
 *  organized per section and strip from the collection container-like
 *  objects that don't have a visual representation.
 *
 *  Convention: The index of the section represents the key
 */
@property (strong, nonatomic) NSDictionary *visibleFormFields;

/**
 *  Property meant to indicate whether the form is read only or not. Setting
 *  this property to true  will disable the outcome buttons. Form fields will
 *  be taken care of by interpreting the server representation.
 */
@property (assign, nonatomic) BOOL isReadOnlyForm;

/**
 *  Property meant to indicate whether the form has user defined outcomes.
 *  This is used when no user defined outcomes are defined yet the form
 *  still has to display a default outcome that will allow the user to
 *  end it.
 */
@property (assign, nonatomic) BOOL formHasUserdefinedOutcomes;

/**
 *  Property meant to hold a refference to the visibility condition processor.
 *  It's purpose is to determine based on form field visibility conditions which
 *  fields are to be displayed or hidden. 
 */
@property (strong, nonatomic) ASDKFormVisibilityConditionsProcessor *visibilityConditionsProcessor;

/**
 *  Designated initializer method for the collection view controller datasource.
 *
 *  @param formDescription Description containing the form field objects to be
 *                         displayed
 *
 *  @return                Instance of the data source object
 */
- (instancetype)initWithFormDescription:(ASDKModelFormDescription *)formDescription
                         dataSourceType:(ASDKFormRenderEngineDataSourceType)dataSourceType;

/**
 *  Returns the number of sections available for the current form description.
 *
 *  @return Integer value with number of sections
 */
- (NSInteger)numberOfSectionsForCurrentFormDescription;

/**
 *  Returns the number of form fields available in the current form description
 *  for a given section.
 *
 *  @param section The section for which the number of form fields is required
 *
 *  @return        Integer value with the number of form fields
 */
- (NSInteger)numberOfFormFieldsForSection:(NSInteger)section;

/**
 *  Returns the cell identifier used to dequeue the appropiate cell by the
 *  collection view controller for a provided index path.
 *
 *  @param indexPath Index path for which the cell identifier needs to be provided
 *
 *  @return          String containing the cell identifier value
 */
- (NSString *)cellIdentifierForIndexPath:(NSIndexPath *)indexPath;

/**
 *  Method returns an array of index paths corresponding to the form outcomes indexes
 *  This is useful when a refresh in needed but just for the form outcome section.
 *
 *  @return Array containing NSIndesPath obects corresponding to the form outcome cells
 */
- (NSArray *)indexPathsOfFormOutcomes;

/**
 *  Method returns the associated model object for the provided index path whether 
 *  it's a form field model object or a form outcome model object.
 *
 *  @param indexPath Index path for which the model needs to be returned
 *
 *  @return          Model object associated with the passed index path
 */
- (ASDKModelBase *)modelForIndexPath:(NSIndexPath *)indexPath;

/**
 *  Method returns the section header title string for the provided index path if
 *  that exists.
 *
 *  @param indexPath Index path for which the section header title is requested
 *
 *  @return String object containing the header title value or nil if there is no
 *          available entry
 */
- (NSString *)sectionHeaderTitleForIndexPath:(NSIndexPath *)indexPath;

/**
 *  Method returns whether or not form field metadata information is present or not
 *  on required form field objects.
 *
 *  @return YES if metadata is present on all required fields and NO, otherwise
 */
- (BOOL)areFormFieldMetadataValuesValid;

/**
 *  This method checks whether there is a view controller class associated with a
 *  particular form field and returns an initialized instance for that particular 
 *  type of form field. 
 *  Discussion: That UIViewController instance represents the child contex of that 
 *  form field and should be presented as a detail view.
 *
 *  @param formField Form field object for which the associated controller check is
 *                   performed
 *
 *  @return UIViewController initialized instance to be presented
 */
- (UIViewController *)childControllerForFormField:(ASDKModelFormField *)formField;

@end
