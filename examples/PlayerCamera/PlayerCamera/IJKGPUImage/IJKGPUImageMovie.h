//
//  IJKGPUImageMovie.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/3/11.
//  Copyright © 2018年 DOM QIU. All rights reserved.
//

//#import "IJKMediaFramework/IJKMediaFramework.h"
#import "IJKMediaPlayback.h"
#import "IJKFFMoviePlayerDef.h"
#import "IJKNotificationManager.h"
#import "IJKFFOptions.h"
#import "IJKFFMonitor.h"

#import <GPUImage.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// media meta
#define k_IJKM_KEY_FORMAT         @"format"
#define k_IJKM_KEY_DURATION_US    @"duration_us"
#define k_IJKM_KEY_START_US       @"start_us"
#define k_IJKM_KEY_BITRATE        @"bitrate"

// stream meta
#define k_IJKM_KEY_TYPE           @"type"
#define k_IJKM_KEY_LANGUAGE       @"language"
#define k_IJKM_KEY_TITLE          @"title"
#define k_IJKM_VAL_TYPE__VIDEO    @"video"
#define k_IJKM_VAL_TYPE__AUDIO    @"audio"
#define k_IJKM_VAL_TYPE__UNKNOWN  @"unknown"

#define k_IJKM_KEY_CODEC_NAME      @"codec_name"
#define k_IJKM_KEY_CODEC_PROFILE   @"codec_profile"
#define k_IJKM_KEY_CODEC_LONG_NAME @"codec_long_name"

// stream: video
#define k_IJKM_KEY_WIDTH          @"width"
#define k_IJKM_KEY_HEIGHT         @"height"
#define k_IJKM_KEY_FPS_NUM        @"fps_num"
#define k_IJKM_KEY_FPS_DEN        @"fps_den"
#define k_IJKM_KEY_TBR_NUM        @"tbr_num"
#define k_IJKM_KEY_TBR_DEN        @"tbr_den"
#define k_IJKM_KEY_SAR_NUM        @"sar_num"
#define k_IJKM_KEY_SAR_DEN        @"sar_den"
// stream: audio
#define k_IJKM_KEY_SAMPLE_RATE    @"sample_rate"
#define k_IJKM_KEY_CHANNEL_LAYOUT @"channel_layout"

#define kk_IJKM_KEY_STREAMS       @"streams"

typedef enum IJKLogLevel {
    k_IJK_LOG_UNKNOWN = 0,
    k_IJK_LOG_DEFAULT = 1,
    
    k_IJK_LOG_VERBOSE = 2,
    k_IJK_LOG_DEBUG   = 3,
    k_IJK_LOG_INFO    = 4,
    k_IJK_LOG_WARN    = 5,
    k_IJK_LOG_ERROR   = 6,
    k_IJK_LOG_FATAL   = 7,
    k_IJK_LOG_SILENT  = 8,
} IJKLogLevel;

typedef void(^SnapshotCompletionHandler)(UIImage*);

@class IJKGPUImageMovie;
@protocol IJKGPUImageMovieDelegate <NSObject>

-(void) ijkGPUImageMovieRenderedOneFrame:(IJKGPUImageMovie*)ijkgpuMovie;

@end

@interface IJKGPUImageMovie : GPUImageOutput<IJKMediaPlayback>

//@property (nonatomic, readonly) BOOL isUsedForSnapshot;

+(IJKGPUImageMovie*) takeImageOfVideo:(NSString*)videoURL atTime:(CMTime)videoTime completionHandler:(SnapshotCompletionHandler)completionHandler;

+(UIImage*) imageOfVideo:(NSString*)videoURL atTime:(CMTime)videoTime;

+(void) imageOfVideo:(NSString*)videoURL atTime:(CMTime)videoTime completionHandler:(SnapshotCompletionHandler)completionHandler;

-(instancetype) initWithSize:(CGSize)size FPS:(float)FPS;

-(void) startPlay;
-(void) stopPlay;

- (void)shutdownWaitStop:(IJKGPUImageMovie*)mySelf;

- (void)shutdownClose:(IJKGPUImageMovie*)mySelf;

-(void) shutdownSynchronously;

- (id)initWithContentURL:(NSURL *)aUrl
             withOptions:(IJKFFOptions *)options;

- (id)initWithContentURLString:(NSString *)aUrlString
                   withOptions:(IJKFFOptions *)options;

- (id)initWithContentURLString:(NSString *)aUrlString
                   withOptions:(IJKFFOptions *)options
                         muted:(BOOL)muted;

- (id)initWithContentURL:(NSURL *)aUrl;

- (id)initWithContentURLString:(NSString *)aUrlString;

-(void) render:(SDL_VoutOverlay*)overlay;
-(void) render:(SDL_VoutOverlay*)overlay frameRenderedCallback:(void(^)())frameRenderedCallback;

- (void)prepareToPlay;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)isPlaying;
- (int64_t)trafficStatistic;
- (float)dropFrameRate;

- (void)setPauseInBackground:(BOOL)pause;
- (BOOL)isVideoToolboxOpen;

//+ (void)setLogReport:(BOOL)preferLogReport;
//+ (void)setLogLevel:(IJKLogLevel)logLevel;
+ (BOOL)checkIfFFmpegVersionMatch:(BOOL)showAlert;
+ (BOOL)checkIfPlayerVersionMatch:(BOOL)showAlert
                          version:(NSString *)version;

@property(nonatomic, readonly) CGFloat fpsInMeta;
@property(nonatomic, readonly) CGFloat fpsAtOutput;
@property(nonatomic) BOOL shouldShowHudView;

@property(nonatomic, strong) id<IJKGPUImageMovieDelegate> delegate;

- (void)setOptionValue:(NSString *)value
                forKey:(NSString *)key
            ofCategory:(IJKFFOptionCategory)category;

- (void)setOptionIntValue:(int64_t)value
                   forKey:(NSString *)key
               ofCategory:(IJKFFOptionCategory)category;



- (void)setFormatOptionValue:       (NSString *)value forKey:(NSString *)key;
- (void)setCodecOptionValue:        (NSString *)value forKey:(NSString *)key;
- (void)setSwsOptionValue:          (NSString *)value forKey:(NSString *)key;
- (void)setPlayerOptionValue:       (NSString *)value forKey:(NSString *)key;

- (void)setFormatOptionIntValue:    (int64_t)value forKey:(NSString *)key;
- (void)setCodecOptionIntValue:     (int64_t)value forKey:(NSString *)key;
- (void)setSwsOptionIntValue:       (int64_t)value forKey:(NSString *)key;
- (void)setPlayerOptionIntValue:    (int64_t)value forKey:(NSString *)key;

@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> segmentOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> tcpOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> httpOpenDelegate;
@property (nonatomic, retain) id<IJKMediaUrlOpenDelegate> liveOpenDelegate;

@property (nonatomic, retain) id<IJKMediaNativeInvokeDelegate> nativeInvokeDelegate;

- (void)didShutdown;

-(UIImage*) snapshotImage;

#pragma mark KVO properties
@property (nonatomic, readonly) IJKFFMonitor *monitor;

@end
