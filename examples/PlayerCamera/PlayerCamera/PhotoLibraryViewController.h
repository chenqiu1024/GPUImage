//
//  PhotoLibraryViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/6.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface PhotoLibrarySelectionItem : NSObject

@property (nonatomic, assign) PHAssetMediaType mediaType;
@property (nonatomic, strong) id resultOject;

@end

typedef void(^PhotoLibrarySelectCompletion)(NSArray<PhotoLibrarySelectionItem* >* selectedItems);

@interface PhotoLibraryViewController : UIViewController

@property (nonatomic, copy) PhotoLibrarySelectCompletion selectCompletion;

@property (nonatomic, strong) NSArray<NSNumber* >* allowedMediaTypes;

@property (nonatomic, assign) NSUInteger maxSelectionCount;

-(void) dismissSelf;

@end
