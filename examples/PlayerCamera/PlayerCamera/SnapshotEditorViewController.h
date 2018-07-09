//
//  SnapshotEditorViewController.h
//  GijkPlayer
//
//  Created by DOM QIU on 2018/7/2.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface SnapshotEditorViewController : UIViewController

@property (nonatomic, copy) void(^completionHandler)(PHAsset*);

@property (nonatomic, strong) UIImage* image;

@end
