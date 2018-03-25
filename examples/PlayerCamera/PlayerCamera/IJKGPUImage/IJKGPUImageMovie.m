//
//  IJKGPUImageMovie.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/3/11.
//  Copyright © 2018年 DOM QIU. All rights reserved.
//

#import "IJKGPUImageMovie.h"

#import "ijkplayer_ios.h"
#import "ijksdl/ios/ijksdl_ios.h"

#import "ijkplayer/ff_fferror.h"
#import "ijkplayer/ff_ffplay.h"
#import "ijkplayer/ijkplayer_internal.h"
#import "ijkplayer/pipeline/ffpipeline_ffplay.h"
#import "pipeline/ffpipeline_ios.h"
#import "../IJKFFOptions.h"

//#import "IJKFFMoviePlayerDef.h"
//#import "IJKMediaPlayback.h"
//#import "IJKMediaModule.h"
//#import "IJKAudioKit.h"
//#import "IJKNotificationManager.h"
//#import "NSString+IJKMedia.h"
#import "ijkioapplication.h"

#include <stdio.h>
#include <assert.h>
#include <string.h>

IjkMediaPlayer* ijkgpuplayer_create(int (*msg_loop)(void*))
{
    IjkMediaPlayer *mp = ijkmp_create(msg_loop);
    if (!mp)
        goto fail;
    
    mp->ffplayer->vout = SDL_VoutIos_CreateForGLES2();
    if (!mp->ffplayer->vout)
        goto fail;
    
    mp->ffplayer->pipeline = ffpipeline_create_from_ios(mp->ffplayer);
    if (!mp->ffplayer->pipeline)
        goto fail;
    
    return mp;
    
fail:
    ijkmp_dec_ref_p(&mp);
    return NULL;
}

void ijkgpuplayer_set_glview_l(IjkMediaPlayer *mp, IJKSDLGLView *glView)
{
    assert(mp);
    assert(mp->ffplayer);
    assert(mp->ffplayer->vout);
    
    SDL_VoutIos_SetGLView(mp->ffplayer->vout, glView);
}

void ijkgpuplayer_set_glview(IjkMediaPlayer *mp, IJKSDLGLView *glView)
{
    assert(mp);
    MPTRACE("ijkmp_ios_set_view(glView=%p)\n", (__bridge void*)glView);
    pthread_mutex_lock(&mp->mutex);
    ijkgpuplayer_set_glview_l(mp, glView);
    pthread_mutex_unlock(&mp->mutex);
    MPTRACE("ijkmp_ios_set_view(glView=%p)=void\n", (__bridge void*)glView);
}

bool ijkgpuplayer_is_videotoolbox_open_l(IjkMediaPlayer *mp)
{
    assert(mp);
    assert(mp->ffplayer);
    
    return false;
}

bool ijkgpuplayer_is_videotoolbox_open(IjkMediaPlayer *mp)
{
    assert(mp);
    MPTRACE("%s()\n", __func__);
    pthread_mutex_lock(&mp->mutex);
    bool ret = ijkgpuplayer_is_videotoolbox_open_l(mp);
    pthread_mutex_unlock(&mp->mutex);
    MPTRACE("%s()=%d\n", __func__, ret ? 1 : 0);
    return ret;
}

@interface IJKGPUImageMovie()
{
    CGSize _framebufferSize;
    float _FPS;
    
    NSUInteger _currentFrame;
    
    IjkMediaPlayer* _ijkMediaPlayer;
}

@property (nonatomic, strong) NSTimer* tickTimer;

@end

@implementation IJKGPUImageMovie

- (id)initWithContentURLString:(NSString *)aUrlString
                   withOptions:(IJKFFOptions *)options
{
    if (aUrlString == nil)
        return nil;
    
    self = [super init];
    if (self) {
        ijkmp_global_init();
        ijkmp_global_set_inject_callback(ijkff_inject_callback);
        
        [IJKFFMoviePlayerController checkIfFFmpegVersionMatch:NO];
        
        if (options == nil)
            options = [IJKFFOptions optionsByDefault];
        
        // IJKFFIOStatRegister(IJKFFIOStatDebugCallback);
        // IJKFFIOStatCompleteRegister(IJKFFIOStatCompleteDebugCallback);
        
        // init fields
        _scalingMode = IJKMPMovieScalingModeAspectFit;
        _shouldAutoplay = YES;
        memset(&_asyncStat, 0, sizeof(_asyncStat));
        memset(&_cacheStat, 0, sizeof(_cacheStat));
        _monitor = [[IJKFFMonitor alloc] init];
        
        // init media resource
        _urlString = aUrlString;
        
        // init player
        _mediaPlayer = ijkmp_ios_create(media_player_msg_loop);
        _msgPool = [[IJKFFMoviePlayerMessagePool alloc] init];
        IJKWeakHolder *weakHolder = [IJKWeakHolder new];
        weakHolder.object = self;
        
        ijkmp_set_weak_thiz(_mediaPlayer, (__bridge_retained void *) self);
        ijkmp_set_inject_opaque(_mediaPlayer, (__bridge_retained void *) weakHolder);
        ijkmp_set_ijkio_inject_opaque(_mediaPlayer, (__bridge_retained void *)weakHolder);
        ijkmp_set_option_int(_mediaPlayer, IJKMP_OPT_CATEGORY_PLAYER, "start-on-prepared", _shouldAutoplay ? 1 : 0);
        
        // init video sink
        _glView = [[IJKSDLGLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        _glView.shouldShowHudView = NO;
        _view   = _glView;
        [_glView setHudValue:nil forKey:@"scheme"];
        [_glView setHudValue:nil forKey:@"host"];
        [_glView setHudValue:nil forKey:@"path"];
        [_glView setHudValue:nil forKey:@"ip"];
        [_glView setHudValue:nil forKey:@"tcp-info"];
        [_glView setHudValue:nil forKey:@"http"];
        [_glView setHudValue:nil forKey:@"tcp-spd"];
        [_glView setHudValue:nil forKey:@"t-prepared"];
        [_glView setHudValue:nil forKey:@"t-render"];
        [_glView setHudValue:nil forKey:@"t-preroll"];
        [_glView setHudValue:nil forKey:@"t-http-open"];
        [_glView setHudValue:nil forKey:@"t-http-seek"];
        
        self.shouldShowHudView = options.showHudView;
        
        ijkmp_ios_set_glview(_mediaPlayer, _glView);
        ijkmp_set_option(_mediaPlayer, IJKMP_OPT_CATEGORY_PLAYER, "overlay-format", "fcc-_es2");
#ifdef DEBUG
        [IJKFFMoviePlayerController setLogLevel:k_IJK_LOG_DEBUG];
#else
        [IJKFFMoviePlayerController setLogLevel:k_IJK_LOG_SILENT];
#endif
        // init audio sink
        [[IJKAudioKit sharedInstance] setupAudioSession];
        
        [options applyTo:_mediaPlayer];
        _pauseInBackground = NO;
        
        // init extra
        _keepScreenOnWhilePlaying = YES;
        [self setScreenOn:YES];
        
        _notificationManager = [[IJKNotificationManager alloc] init];
        [self registerApplicationObservers];
    }
    return self;
}

-(instancetype) initWithSize:(CGSize)size FPS:(float)FPS {
    if (self = [super init])
    {
        _framebufferSize = size;
        _FPS = FPS;
    }
    return self;
}

-(void) startPlay {
    _currentFrame = 0;
    self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:1.f/_FPS repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self processOneFrame];
        _currentFrame++;
    }];
    [[NSRunLoop currentRunLoop] addTimer:self.tickTimer forMode:NSDefaultRunLoopMode];
}

-(void) stopPlay {
    [self.tickTimer invalidate];
}

-(void) processOneFrame {
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:_framebufferSize onlyTexture:NO];
        [outputFramebuffer activateFramebuffer];
        
        float R = (rand() % 256) / 255.f;
        float G = (rand() % 256) / 255.f;
        float B = (rand() % 256) / 255.f;
        glClearColor(R, G, B, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget setInputSize:_framebufferSize atIndex:targetTextureIndex];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:targetTextureIndex];
        }
        
        [outputFramebuffer unlock];
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger targetTextureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:CMTimeMake(_currentFrame, _FPS) atIndex:targetTextureIndex];
        }
    }
}

@end
