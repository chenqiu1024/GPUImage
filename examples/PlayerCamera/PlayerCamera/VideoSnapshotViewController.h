//
//  VideoSnapshotViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPUImage.h"
#import "GPUImageView.h"
#import <Photos/Photos.h>

@interface VideoSnapshotViewController : UIViewController

@property (nonatomic, copy) void(^completionHandler)(PHAsset*);

@property (nonatomic, copy) NSString* sourceVideoFile;

@end

