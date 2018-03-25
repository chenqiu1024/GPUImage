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

#import "NSString+IJKMedia.h"
#import "ijkioapplication.h"

@class IJKNotificationManager;
@class IJKMediaUrlOpenData;

#include <stdio.h>
#include <assert.h>
#include <string.h>

#pragma mark    IJKGPUImageMovie()

@interface IJKGPUImageMovie()
{
    CGSize _framebufferSize;
    float _FPS;
    
    NSUInteger _currentFrame;
    
    IjkMediaPlayer* _ijkMediaPlayer;
    //    IJKSDLGLView *_glView;
    IJKFFMoviePlayerMessagePool *_msgPool;
    NSString *_urlString;
    
    NSInteger _videoWidth;
    NSInteger _videoHeight;
    NSInteger _sampleAspectRatioNumerator;
    NSInteger _sampleAspectRatioDenominator;
    
    BOOL      _seeking;
    NSInteger _bufferingTime;
    NSInteger _bufferingPosition;
    
    BOOL _keepScreenOnWhilePlaying;
    BOOL _pauseInBackground;
    BOOL _isVideoToolboxOpen;
    BOOL _playingBeforeInterruption;
    
    IJKNotificationManager *_notificationManager;
    
    AVAppAsyncStatistic _asyncStat;
    IjkIOAppCacheStatistic _cacheStat;
    BOOL _shouldShowHudView;
    NSTimer *_hudTimer;
}

@property (nonatomic, strong) NSTimer* tickTimer;
@property (nonatomic, assign) AVAppAsyncStatistic asyncStat;
@property (nonatomic, assign) IjkIOAppCacheStatistic cacheStat;

@end

#pragma mark    ijkgpuplayer

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

#pragma mark av_format_control_message

static int onInjectIOControl(IJKGPUImageMovie* ijkgpuMovie, id<IJKMediaUrlOpenDelegate> delegate, int type, void* data, size_t data_size)
{
    AVAppIOControl* realData = data;
    assert(realData);
    assert(sizeof(AVAppIOControl) == data_size);
    realData->is_handled     = NO;
    realData->is_url_changed = NO;
    
    if (delegate == nil)
        return 0;
    
    NSString* urlString = [NSString stringWithUTF8String:realData->url];
    
    IJKMediaUrlOpenData* openData = [[IJKMediaUrlOpenData alloc] initWithUrl:urlString event:(IJKMediaEvent)type segmentIndex:realData->segment_index retryCounter:realData->retry_counter];
    if ([delegate respondsToSelector:@selector(willOpenUrl:)])
    {
        [delegate willOpenUrl:openData];
    }
    if (openData.error < 0)
        return -1;
    
    if (openData.isHandled)
    {
        realData->is_handled = YES;
        if (openData.isUrlChanged && openData.url != nil)
        {
            realData->is_url_changed = YES;
            const char *newUrlUTF8 = [openData.url UTF8String];
            strlcpy(realData->url, newUrlUTF8, sizeof(realData->url));
            realData->url[sizeof(realData->url) - 1] = 0;
        }
    }
    
    return 0;
}

static int onInjectTcpIOControl(IJKGPUImageMovie* ijkgpuMovie, id<IJKMediaUrlOpenDelegate> delegate, int type, void *data, size_t data_size)
{
    AVAppTcpIOControl *realData = data;
    assert(realData);
    assert(sizeof(AVAppTcpIOControl) == data_size);
    
    switch (type) {
        case IJKMediaCtrl_WillTcpOpen:
            
            break;
        case IJKMediaCtrl_DidTcpOpen:
            ijkgpuMovie.monitor.tcpError = realData->error;
            ijkgpuMovie.monitor.remoteIp = [NSString stringWithUTF8String:realData->ip];
//            [ijkgpuMovie.glView setHudValue: ijkgpuMovie.monitor.remoteIp forKey:@"ip"];
            break;
        default:
            assert(!"unexcepted type for tcp io control");
            break;
    }
    
    if (delegate == nil)
        return 0;
    
    NSString* urlString = [NSString stringWithUTF8String:realData->ip];
    
    IJKMediaUrlOpenData* openData =
    [[IJKMediaUrlOpenData alloc] initWithUrl:urlString
                                       event:(IJKMediaEvent)type
                                segmentIndex:0
                                retryCounter:0];
    openData.fd = realData->fd;
    
    [delegate willOpenUrl:openData];
    if (openData.error < 0)
        return -1;
//    [ijkgpuMovie.glView setHudValue: [NSString stringWithFormat:@"fd:%d %@", openData.fd, openData.msg?:@"unknown"] forKey:@"tcp-info"];
    return 0;
}

static int onInjectAsyncStatistic(IJKGPUImageMovie* ijkgpuMovie, int type, void *data, size_t data_size)
{
    AVAppAsyncStatistic* realData = data;
    assert(realData);
    assert(sizeof(AVAppAsyncStatistic) == data_size);
    
    ijkgpuMovie.asyncStat = *realData;
    return 0;
}

static int onInectIJKIOStatistic(IJKGPUImageMovie* ijkgpuMovie, int type, void *data, size_t data_size)
{
    IjkIOAppCacheStatistic* realData = data;
    assert(realData);
    assert(sizeof(IjkIOAppCacheStatistic) == data_size);
    
    ijkgpuMovie.cacheStat = *realData;
    return 0;
}

static int64_t calculateElapsed(int64_t begin, int64_t end)
{
    if (begin <= 0)
        return -1;
    
    if (end < begin)
        return -1;
    
    return end - begin;
}

static int onInjectOnHttpEvent(IJKGPUImageMovie* ijkgpuMovie, int type, void* data, size_t data_size)
{
    AVAppHttpEvent* realData = data;
    assert(realData);
    assert(sizeof(AVAppHttpEvent) == data_size);
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSURL        *nsurl   = nil;
    IJKFFMonitor *monitor = ijkgpuMovie.monitor;
    NSString     *url  = monitor.httpUrl;
    NSString     *host = monitor.httpHost;
    int64_t       elapsed = 0;
    
    id<IJKMediaNativeInvokeDelegate> delegate = ijkgpuMovie.nativeInvokeDelegate;
    
    switch (type)
    {
        case AVAPP_EVENT_WILL_HTTP_OPEN:
            url   = [NSString stringWithUTF8String:realData->url];
            nsurl = [NSURL URLWithString:url];
            host  = nsurl.host;
            
            monitor.httpUrl      = url;
            monitor.httpHost     = host;
            monitor.httpOpenTick = SDL_GetTickHR();
//            [ijkgpuMovie setHudUrl:url];
            
            if (delegate != nil)
            {
                dict[IJKMediaEventAttrKey_host]         = [NSString ijk_stringBeEmptyIfNil:host];
                dict[IJKMediaEventAttrKey_url]          = [NSString ijk_stringBeEmptyIfNil:monitor.httpUrl];
                [delegate invoke:type attributes:dict];
            }
            break;
        case AVAPP_EVENT_DID_HTTP_OPEN:
            elapsed = calculateElapsed(monitor.httpOpenTick, SDL_GetTickHR());
            monitor.httpError = realData->error;
            monitor.httpCode  = realData->http_code;
            monitor.httpOpenCount++;
            monitor.httpOpenTick = 0;
            monitor.lastHttpOpenDuration = elapsed;
//            [ijkgpuMovie.glView setHudValue:@(realData->http_code).stringValue forKey:@"http"];
            
            if (delegate != nil)
            {
                dict[IJKMediaEventAttrKey_time_of_event]    = @(elapsed).stringValue;
                dict[IJKMediaEventAttrKey_url]              = [NSString ijk_stringBeEmptyIfNil:monitor.httpUrl];
                dict[IJKMediaEventAttrKey_host]             = [NSString ijk_stringBeEmptyIfNil:host];
                dict[IJKMediaEventAttrKey_error]            = @(realData->error).stringValue;
                dict[IJKMediaEventAttrKey_http_code]        = @(realData->http_code).stringValue;
                [delegate invoke:type attributes:dict];
            }
            break;
        case AVAPP_EVENT_WILL_HTTP_SEEK:
            monitor.httpSeekTick = SDL_GetTickHR();
            
            if (delegate != nil)
            {
                dict[IJKMediaEventAttrKey_host]         = [NSString ijk_stringBeEmptyIfNil:host];
                dict[IJKMediaEventAttrKey_offset]       = @(realData->offset).stringValue;
                [delegate invoke:type attributes:dict];
            }
            break;
        case AVAPP_EVENT_DID_HTTP_SEEK:
            elapsed = calculateElapsed(monitor.httpSeekTick, SDL_GetTickHR());
            monitor.httpError = realData->error;
            monitor.httpCode  = realData->http_code;
            monitor.httpSeekCount++;
            monitor.httpSeekTick = 0;
            monitor.lastHttpSeekDuration = elapsed;
//            [ijkgpuMovie.glView setHudValue:@(realData->http_code).stringValue forKey:@"http"];
            
            if (delegate != nil)
            {
                dict[IJKMediaEventAttrKey_time_of_event]    = @(elapsed).stringValue;
                dict[IJKMediaEventAttrKey_url]              = [NSString ijk_stringBeEmptyIfNil:monitor.httpUrl];
                dict[IJKMediaEventAttrKey_host]             = [NSString ijk_stringBeEmptyIfNil:host];
                dict[IJKMediaEventAttrKey_offset]           = @(realData->offset).stringValue;
                dict[IJKMediaEventAttrKey_error]            = @(realData->error).stringValue;
                dict[IJKMediaEventAttrKey_http_code]        = @(realData->http_code).stringValue;
                [delegate invoke:type attributes:dict];
            }
            break;
    }
    
    return 0;
}

// NOTE: could be called from multiple thread
static int ijkff_inject_callback(void* opaque, int message, void* data, size_t data_size)
{
    IJKWeakHolder* weakHolder = (__bridge IJKWeakHolder*)opaque;
    IJKGPUImageMovie* ijkgpuMovie = weakHolder.object;
    if (!ijkgpuMovie)
        return 0;
    
    switch (message)
    {
        case AVAPP_CTRL_WILL_CONCAT_SEGMENT_OPEN:
            return onInjectIOControl(ijkgpuMovie, ijkgpuMovie.segmentOpenDelegate, message, data, data_size);
        case AVAPP_CTRL_WILL_TCP_OPEN:
            return onInjectTcpIOControl(ijkgpuMovie, ijkgpuMovie.tcpOpenDelegate, message, data, data_size);
        case AVAPP_CTRL_WILL_HTTP_OPEN:
            return onInjectIOControl(ijkgpuMovie, ijkgpuMovie.httpOpenDelegate, message, data, data_size);
        case AVAPP_CTRL_WILL_LIVE_OPEN:
            return onInjectIOControl(ijkgpuMovie, ijkgpuMovie.liveOpenDelegate, message, data, data_size);
        case AVAPP_EVENT_ASYNC_STATISTIC:
            return onInjectAsyncStatistic(ijkgpuMovie, message, data, data_size);
        case IJKIOAPP_EVENT_CACHE_STATISTIC:
            return onInectIJKIOStatistic(ijkgpuMovie, message, data, data_size);
        case AVAPP_CTRL_DID_TCP_OPEN:
            return onInjectTcpIOControl(ijkgpuMovie, ijkgpuMovie.tcpOpenDelegate, message, data, data_size);
        case AVAPP_EVENT_WILL_HTTP_OPEN:
        case AVAPP_EVENT_DID_HTTP_OPEN:
        case AVAPP_EVENT_WILL_HTTP_SEEK:
        case AVAPP_EVENT_DID_HTTP_SEEK:
            return onInjectOnHttpEvent(ijkgpuMovie, message, data, data_size);
        default: {
            return 0;
        }
    }
}

#pragma mark    IJKGPUImageMovie

@implementation IJKGPUImageMovie

@synthesize view = _view;
@synthesize currentPlaybackTime;
@synthesize duration;
@synthesize playableDuration;
@synthesize bufferingProgress = _bufferingProgress;

@synthesize numberOfBytesTransferred = _numberOfBytesTransferred;

@synthesize isPreparedToPlay = _isPreparedToPlay;
@synthesize playbackState = _playbackState;
@synthesize loadState = _loadState;

@synthesize naturalSize = _naturalSize;
@synthesize scalingMode = _scalingMode;
@synthesize shouldAutoplay = _shouldAutoplay;

@synthesize allowsMediaAirPlay = _allowsMediaAirPlay;
@synthesize airPlayMediaActive = _airPlayMediaActive;

@synthesize isDanmakuMediaAirPlay = _isDanmakuMediaAirPlay;

@synthesize monitor = _monitor;

@synthesize asyncStat = _asyncStat;
@synthesize cacheStat = _cacheStat;

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
