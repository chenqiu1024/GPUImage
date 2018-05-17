//
//  ViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPUImage.h"
#import "GPUImageView.h"

@interface ViewController : UIViewController

@property (nonatomic, strong) IBOutlet GPUImageView* gpuImageView;

- (IBAction)updateSliderValue:(id)sender;

@end

