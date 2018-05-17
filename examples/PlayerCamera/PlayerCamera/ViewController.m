//
//  ViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import "ViewController.h"
#import "IJKGPUImageMovie.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

#define VideoSource_Camera 0
#define VideoSource_IJKGPUImageMovie_RandomColor 1
#define VideoSource_IJKGPUImageMovie_VideoPlay 2

#define VideoSource VideoSource_IJKGPUImageMovie_VideoPlay

@interface ViewController () <IJKGPUImageMovieDelegate>
{
    GPUImageVideoCamera* _videoCamera;
    GPUImageOutput<GPUImageInput>* _filter;
    //    GPUImageMovieWriter *movieWriter;
    
    IJKGPUImageMovie* _ijkMovie;
//    UIImageView* _imageView;
    
    GPUImageView* _filterView;
    GPUImageMovieWriter* _movieWriter;
}

-(void)removeMovieNotificationObservers;
-(void)installMovieNotificationObservers;

@end

@implementation ViewController

#define SourceVideoFileName @"I.Am.Legend.2007.iPhone-YYeTs.mp4"
//#define SourceVideoFileName @"https://tzn8.com/bunnies.mp4"
//#define SourceVideoFileName @"VID_20170220_182639AA.MP4"
//#define SourceVideoFileName @"testin.mp4"

- (void) startRecordingVideoSegment {
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
#if VideoSource == VideoSource_Camera
    [_videoCamera addTarget:_filter];
#elif VideoSource == VideoSource_IJKGPUImageMovie_RandomColor
    _ijkMovie = [[IJKGPUImageMovie alloc] initWithSize:CGSizeMake(640, 480) FPS:2.f];
    [_ijkMovie addTarget:_filter];
#elif VideoSource == VideoSource_IJKGPUImageMovie_VideoPlay
    [self installMovieNotificationObservers];
    NSString* docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    if ([SourceVideoFileName hasPrefix:@"http"])
    {
        _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:SourceVideoFileName];
    }
    else
    {
        _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:[docPath stringByAppendingPathComponent:SourceVideoFileName]];
    }
    _ijkMovie.delegate = self;
    [_ijkMovie addTarget:_filter];
    [_ijkMovie prepareToPlay];
#endif
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_hhmmss";
    NSString* fileName = [NSString stringWithFormat:@"MOV_%@.mp4", [formatter stringFromDate:[NSDate date]]];
    NSString* pathToMovie = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(480.0, 640.0)];
    _movieWriter.encodingLiveVideo = YES;
    //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(640.0, 480.0)];
    //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(720.0, 1280.0)];
    //    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(1080.0, 1920.0)];
    ///!!![_filter addTarget:_movieWriter];
    [_videoCamera addTarget:_movieWriter];
    [_filter addTarget:_filterView];
    
    double delayToStartRecording = 0.5;
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, delayToStartRecording * NSEC_PER_SEC);
    dispatch_after(startTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"Start recording");

#if VideoSource == VideoSource_IJKGPUImageMovie_RandomColor
        [_ijkMovie startPlay];
#elif VideoSource == VideoSource_IJKGPUImageMovie_VideoPlay
        ///!!![_ijkMovie play];
#elif VideoSource == VideoSource_Camera
        
#endif
        _videoCamera.audioEncodingTarget = _movieWriter;
        [_videoCamera startCameraCapture];
        
        [_movieWriter startRecording];
        
        //        NSError *error = nil;
        //        if (![_videoCamera.inputCamera lockForConfiguration:&error])
        //        {
        //            NSLog(@"Error locking for configuration: %@", error);
        //        }
        //        [_videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOn];
        //        [_videoCamera.inputCamera unlockForConfiguration];
#if VideoSource != VideoSource_IJKGPUImageMovie_VideoPlay
        double delayInSeconds = 15.0;
        dispatch_time_t stopTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(stopTime, dispatch_get_main_queue(), ^(void){
            [_filter removeTarget:_movieWriter];

            _videoCamera.audioEncodingTarget = nil;
            [_videoCamera stopCameraCapture];

            //*/
            [_movieWriter finishRecording];
            NSLog(@"Movie completed");
            [_filter removeAllTargets];
            /*
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:movieURL])
            {
                [library writeVideoAtPathToSavedPhotosAlbum:movieURL completionBlock:^(NSURL *assetURL, NSError *error)
                 {
                     dispatch_async(dispatch_get_main_queue(), ^{
                         
                         if (error) {
                             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                            delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                             [alert show];
                         } else {
//                             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
//                                                                            delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                             [alert show];
                         }
                         remove(pathToMovie.UTF8String);
                     });
                     [self startRecordingVideoSegment];
                 }];
            }
            /*/
            [self startRecordingVideoSegment];
            //*/
            
            //            [_videoCamera.inputCamera lockForConfiguration:nil];
            //            [_videoCamera.inputCamera setTorchMode:AVCaptureTorchModeOff];
            //            [_videoCamera.inputCamera unlockForConfiguration];
        });
#endif //#if VideoSource != VideoSource_IJKGPUImageMovie_VideoPlay
    });
}

#pragma mark - View lifecycle

-(void) applicationDidBecomeActive:(id)sender {
    [_videoCamera resumeCameraCapture];
    [_movieWriter setPaused:NO];
}

-(void) applicationWillResignActive:(id)sender {
    [_movieWriter setPaused:YES];
    [_videoCamera pauseCameraCapture];
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeMovieNotificationObservers];
}

- (BOOL) prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    self.navigationController.navigationBarHidden = YES;
    
//    return;
    _filter = [[GPUImageSepiaFilter alloc] init];
    [(GPUImageSepiaFilter*)_filter setIntensity:0.f];
    
    //    _filter = [[GPUImageTiltShiftFilter alloc] init];
    //    [(GPUImageTiltShiftFilter *)_filter setTopFocusLevel:0.65];
    //    [(GPUImageTiltShiftFilter *)_filter setBottomFocusLevel:0.85];
    //    [(GPUImageTiltShiftFilter *)_filter setBlurSize:1.5];
    //    [(GPUImageTiltShiftFilter *)_filter setFocusFallOffRate:0.2];
    
    //    _filter = [[GPUImageSketchFilter alloc] init];
    //    _filter = [[GPUImageColorInvertFilter alloc] init];
    //    _filter = [[GPUImageSmoothToonFilter alloc] init];
    //    GPUImageRotationFilter *rotationFilter = [[GPUImageRotationFilter alloc] initWithRotation:kGPUImageRotateRightFlipVertical];

    //GPUImageView *filterView = (GPUImageView *)self.gpuImageView;
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    [self.view addSubview:_filterView];
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    [_filter addTarget:_filterView];
#if VideoSource == VideoSource_IJKGPUImageMovie_VideoPlay
    /*///!!!For Debug:
    _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _imageView.backgroundColor = [UIColor greenColor];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_imageView];
    //*/
#endif
    
    // Record a movie for 10 s and store it in /Documents, visible via iTunes file sharing
    [self startRecordingVideoSegment];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    // Map UIDeviceOrientation to UIInterfaceOrientation.
    UIInterfaceOrientation orient = UIInterfaceOrientationPortrait;
    switch ([[UIDevice currentDevice] orientation])
    {
        case UIDeviceOrientationLandscapeLeft:
            orient = UIInterfaceOrientationLandscapeLeft;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            orient = UIInterfaceOrientationLandscapeRight;
            break;
            
        case UIDeviceOrientationPortrait:
            orient = UIInterfaceOrientationPortrait;
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            orient = UIInterfaceOrientationPortraitUpsideDown;
            break;
            
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            // When in doubt, stay the same.
            orient = fromInterfaceOrientation;
            break;
    }
    _videoCamera.outputImageOrientation = orient;
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES; // Support all orientations.
}

- (IBAction)updateSliderValue:(id)sender
{
    [(GPUImageSepiaFilter *)_filter setIntensity:[(UISlider *)sender value]];
}

#pragma mark    Immitated from IJKMoviePlayerViewController

- (void)loadStateDidChange:(NSNotification*)notification
{
    //    MPMovieLoadStateUnknown        = 0,
    //    MPMovieLoadStatePlayable       = 1 << 0,
    //    MPMovieLoadStatePlaythroughOK  = 1 << 1, // Playback will be automatically started in this state when shouldAutoplay is YES
    //    MPMovieLoadStateStalled        = 1 << 2, // Playback will be automatically paused in this state, if started
    
    IJKMPMovieLoadState loadState = _ijkMovie.loadState;
    
    if ((loadState & IJKMPMovieLoadStatePlaythroughOK) != 0) {
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStatePlaythroughOK: %d\n", (int)loadState);
    } else if ((loadState & IJKMPMovieLoadStateStalled) != 0) {
        NSLog(@"loadStateDidChange: IJKMPMovieLoadStateStalled: %d\n", (int)loadState);
    } else {
        NSLog(@"loadStateDidChange: ???: %d\n", (int)loadState);
    }
}

- (void)moviePlayBackDidFinish:(NSNotification*)notification
{
    //    MPMovieFinishReasonPlaybackEnded,
    //    MPMovieFinishReasonPlaybackError,
    //    MPMovieFinishReasonUserExited
    int reason = [[[notification userInfo] valueForKey:IJKMPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    
    switch (reason)
    {
        case IJKMPMovieFinishReasonPlaybackEnded:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackEnded: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonUserExited:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonUserExited: %d\n", reason);
            break;
            
        case IJKMPMovieFinishReasonPlaybackError:
            NSLog(@"playbackStateDidChange: IJKMPMovieFinishReasonPlaybackError: %d\n", reason);
            break;
            
        default:
            NSLog(@"playbackPlayBackDidFinish: ???: %d\n", reason);
            break;
    }
}

- (void)mediaIsPreparedToPlayDidChange:(NSNotification*)notification
{
    NSLog(@"mediaIsPreparedToPlayDidChange\n");
}

- (void)moviePlayBackStateDidChange:(NSNotification*)notification
{
    //    MPMoviePlaybackStateStopped,
    //    MPMoviePlaybackStatePlaying,
    //    MPMoviePlaybackStatePaused,
    //    MPMoviePlaybackStateInterrupted,
    //    MPMoviePlaybackStateSeekingForward,
    //    MPMoviePlaybackStateSeekingBackward
    
    switch (_ijkMovie.playbackState)
    {
        case IJKMPMoviePlaybackStateStopped: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped#0", (int)_ijkMovie.playbackState);
            [_ijkMovie shutdownClose:_ijkMovie];
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: stoped#1", (int)_ijkMovie.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePlaying: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: playing", (int)_ijkMovie.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStatePaused: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: paused", (int)_ijkMovie.playbackState);
#if VideoSource == VideoSource_IJKGPUImageMovie_VideoPlay
            ///!!![_ijkMovie play];
#endif
            break;
        }
        case IJKMPMoviePlaybackStateInterrupted: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: interrupted", (int)_ijkMovie.playbackState);
            break;
        }
        case IJKMPMoviePlaybackStateSeekingForward:
        case IJKMPMoviePlaybackStateSeekingBackward: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: seeking", (int)_ijkMovie.playbackState);
            break;
        }
        default: {
            NSLog(@"IJKMPMoviePlayBackStateDidChange %d: unknown", (int)_ijkMovie.playbackState);
            break;
        }
    }
}

#pragma mark Install Movie Notifications

/* Register observers for the various movie object notifications. */
-(void)installMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadStateDidChange:)
                                                 name:IJKMPMoviePlayerLoadStateDidChangeNotification
                                               object:_ijkMovie];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
                                               object:_ijkMovie];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mediaIsPreparedToPlayDidChange:)
                                                 name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification
                                               object:_ijkMovie];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:IJKMPMoviePlayerPlaybackStateDidChangeNotification
                                               object:_ijkMovie];
}

#pragma mark Remove Movie Notification Handlers

/* Remove the movie notification observers from the movie object. */
-(void)removeMovieNotificationObservers
{
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_ijkMovie];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_ijkMovie];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_ijkMovie];
    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_ijkMovie];
}

#pragma mark IJKGPUImageMovieDelegate
-(void) ijkGPUImageMovieRenderedOneFrame:(id)ijkgpuMovie {
//    UIImage* image = [ijkgpuMovie snapshotImage];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        _imageView.image = image;
//        NSLog(@"#ImageView# image.size=(%f,%f)", image.size.width, image.size.height);
//    });
}

@end
