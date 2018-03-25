//
//  IJKGPUImageMovie.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/3/11.
//  Copyright © 2018年 DOM QIU. All rights reserved.
//

#import <GPUImage.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface IJKGPUImageMovie : GPUImageOutput

-(instancetype) initWithSize:(CGSize)size FPS:(float)FPS;

-(void) startPlay;
-(void) stopPlay;

@end
