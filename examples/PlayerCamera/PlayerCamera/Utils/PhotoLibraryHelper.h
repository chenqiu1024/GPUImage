//
//  PhotoLibraryHelper.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/6.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

@interface PhotoLibraryHelper : NSObject

typedef void(^PhotoLibraryCreationCompletionHandler)(BOOL success, NSError* error, NSString* assetId);

+(PHAssetCollection*)getCollectionWithTitle:(NSString *)title;

+(void)saveVideoWithUrl:(NSURL *)videoUrl collectionTitle:(NSString *)collectionTitle completionHandler:(PhotoLibraryCreationCompletionHandler)completionHandler;
+(void)saveImageWithUrl:(NSURL *)imageUrl collectionTitle:(NSString *)collectionTitle completionHandler:(PhotoLibraryCreationCompletionHandler)completionHandler;

@end
