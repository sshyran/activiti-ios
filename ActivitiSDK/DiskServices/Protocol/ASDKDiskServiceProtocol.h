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

#import <Foundation/Foundation.h>

@class ASDKModelContent;

/**
 *  The purpose of this protocol is to lay down an interface for the concrete 
 *  implementation of a disk service. This service should intermediate disk 
 *  specific operations and checks.
 */

@protocol ASDKDiskServiceProtocol <NSObject>

/**
 *  Returns a download path for a given content object.
 *
 *  @param content  Content object containing information about the destination path
 *
 *  @return         Full download path string for the provided file name
 */
- (NSString *)downloadPathForContent:(ASDKModelContent *)content;

/**
 *  Returns whether content is present at the download path of the mentioned 
 *  content object.
 *
 *  @param content  Content object containing information about the destination path
 *
 *  @return         Whether there is a file at the download path or not
 */
- (BOOL)doesFileAlreadyExistsForContent:(ASDKModelContent *)content;

/**
 *  Returns the size of a file at the provided file path.
 *
 *  @param filePath File path used to asses the content size
 *
 *  @return         Size of the file at the pointed path
 */
- (NSUInteger)sizeOfFileAtPath:(NSString *)filePath;

/**
 *  Returns a string containing a formatted string of the appropiate unit of size per
 *  the provided byte count.
 *
 *  @param byteCount Byte count that will get translated to the string
 *
 *  @return          Formatted string for the byte count
 */
- (NSString *)sizeStringForByteCount:(long long)byteCount;

/**
 *  Returns a string containing a file name representation given a MIME type parameter.
 *  The method will remember previously generated file names and increment a counter to
 *  avoid name collisions.
 *
 *  @param mimeType The MIME type for which the file name should be generated
 *
 *  @return         Collision-free unique file name
 */
+ (NSString *)generateFilenameForFileWithMIMEType:(NSString *)mimeType;

/**
 *  Attempts to guess MIME type given an NSData object
 *
 *  @param data Data for which the MIME type should be guessed
 *
 *  @return     MIME type corresponding to the passed data
 */
+ (NSString *)mimeTypeByGuessingFromData:(NSData *)data;

@end
