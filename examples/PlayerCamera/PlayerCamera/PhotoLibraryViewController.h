//
//  PhotoLibraryViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/6.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

typedef void(^PhotoLibrarySelectCompletion)(id resultObject, PHAssetMediaType mediaType);

@interface PhotoLibraryViewController : UIViewController

@property (nonatomic, copy) PhotoLibrarySelectCompletion selectCompletion;

@end
