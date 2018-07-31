//
//  CameraPlayerViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import "CameraPlayerViewController.h"
#import "IJKGPUImageMovie.h"
#import "IFlyFaceDetectResultParser.h"
#import "SnapshotEditorViewController.h"
#import "UINavigationBar+Translucent.h"
#import "SubtitleAndAudioSelectionViewController.h"
#import <LogManager.h>
#import <AssetsLibrary/ALAssetsLibrary.h>

#define VideoSource_IJKGPUImageMovie_VideoPlay 2

#define VideoSource VideoSource_IJKGPUImageMovie_VideoPlay

#pragma mark    AccessoriesView

@interface AccessoriesView : UIView
{
    CGContextRef context;
}

@property (nonatomic, strong) NSArray* arrPersons;

@end

@implementation AccessoriesView

-(instancetype) initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame])
    {
    }
    return self;
}

-(void) drawPointWithPoints:(NSArray*)arrPersons{
    context = UIGraphicsGetCurrentContext();
    if (context)
    {
        CGContextSetRGBFillColor(context, 0.f, 0.75f, 0.25f, 1.f);
        CGContextClearRect(context, self.bounds);
    }
    for (NSDictionary* dicPerson in self.arrPersons)
    {
        if ([dicPerson objectForKey:KCIFlyFaceResultPointsKey])
        {
            for (NSString* strPoints in [dicPerson objectForKey:KCIFlyFaceResultPointsKey])
            {
                CGPoint p = CGPointFromString(strPoints) ;
                CGContextAddEllipseInRect(context, CGRectMake(p.x - 1 , p.y - 1 , 2 , 2));
            }
        }

        BOOL isOriRect = NO;
        if ([dicPerson objectForKey:KCIFlyFaceResultRectOri])
        {
            isOriRect=[[dicPerson objectForKey:KCIFlyFaceResultRectOri] boolValue];
        }

        if ([dicPerson objectForKey:KCIFlyFaceResultRectKey])
        {
            CGRect rect = CGRectFromString([dicPerson objectForKey:KCIFlyFaceResultRectKey]);
            if (isOriRect)
            {//完整矩形
                CGContextAddRect(context,rect);
            }
            else
            { //只画四角
                // 左上
                CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height/8);
                CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y);

                //右上
                CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height/8);

                //左下
                CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height*7/8);
                CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y+rect.size.height);


                //右下
                CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height*7/8);
            }
        }
    }
    [[UIColor greenColor] set];
    CGContextSetLineWidth(context, 2);
    CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)rect {
    [self drawPointWithPoints:self.arrPersons] ;
}

@end

#pragma mark    CameraPlayerViewController
@interface CameraPlayerViewController () <IJKGPUImageMovieDelegate, UIGestureRecognizerDelegate>
{
    GPUImageVideoCamera* _videoCamera;
    GPUImageOutput<GPUImageInput>* _filter;
    //    GPUImageMovieWriter *movieWriter;
    
    IJKGPUImageMovie* _ijkMovie;
//    UIImageView* _imageView;
    
    GPUImageView* _filterView;
    GPUImageMovieWriter* _movieWriter;
    
    BOOL _isProgressSliderBeingDragged;
    
    NSTimeInterval _fastSeekStartTime;
}

-(void)removeMovieNotificationObservers;
-(void)installMovieNotificationObservers;

@property (nonatomic, weak) IBOutlet UIView* overlayView;
@property (nonatomic, weak) IBOutlet UIView* controlPanelView;
@property (nonatomic, weak) IBOutlet UIButton* playOrPauseButton;
@property (nonatomic, weak) IBOutlet UISlider* progressSlider;
@property (nonatomic, weak) IBOutlet UILabel* durationLabel;
@property (nonatomic, weak) IBOutlet UILabel* currentTimeLabel;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UILabel* fastSeekLabel;

@property (nonatomic, strong) AccessoriesView* accessoriesView;

-(IBAction)onClickOverlay:(id)sender;
-(IBAction)onClickControlPanel:(id)sender;

-(IBAction)didSliderTouchDown:(id)sender;
-(IBAction)didSliderTouchUpInside:(id)sender;
-(IBAction)didSliderTouchUpOutside:(id)sender;
-(IBAction)didSliderTouchCancel:(id)sender;
-(IBAction)didSliderValueChanged:(id)sender;

-(IBAction)onClickPlayOrPause:(id)sender;

@end

@implementation CameraPlayerViewController

//#define SourceVideoFileName @"玩命直播BD1280高清中英双字.MP4"
//#define SourceVideoFileName @"https://tzn8.com/bunnies.mp4"
//#define SourceVideoFileName @"VID_20170220_182639AA.MP4"
//#define SourceVideoFileName @"testin.mp4"

-(void) setPlayOrPauseButtonState:(BOOL)isPlaying {
    NSUInteger newTag = isPlaying ? 1 : 0;
    if (newTag == self.playOrPauseButton.tag)
        return;
    self.playOrPauseButton.tag = newTag;
    [self.playOrPauseButton setImage:[UIImage imageNamed:(isPlaying? @"btn_player_pause.png" : @"btn_player_play.png")] forState:UIControlStateNormal];
}

-(void) refreshMediaControl {
    NSTimeInterval duration = _ijkMovie.duration;
    int minutes = floorf(duration / 60.f);
    int seconds = roundf(duration - minutes * 60);
    if (duration > 0)
    {
        self.progressSlider.maximumValue = duration;
        self.durationLabel.text = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    }
    else
    {
        self.progressSlider.maximumValue = 1.0f;
        self.durationLabel.text = @"--:--";
    }
    
    NSTimeInterval position;
    if (_isProgressSliderBeingDragged)
        position = self.progressSlider.value;
    else if (_fastSeekStartTime != 0.f)
        position = _fastSeekStartTime;
    else
        position = _ijkMovie.currentPlaybackTime;
    minutes = floorf(position / 60.f);
    seconds = roundf(position - minutes * 60);
    self.progressSlider.value = (position > 0) ? position : 0.0f;
    self.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    
    [self setPlayOrPauseButtonState:_ijkMovie.isPlaying];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMediaControl) object:nil];
    if (!self.controlPanelView.hidden)
    {
        [self performSelector:@selector(refreshMediaControl) withObject:nil afterDelay:0.5];
    }
}

-(void) setControlsHidden:(BOOL)hidden {
    self.controlPanelView.hidden = hidden;
    self.navBar.hidden = hidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void) hideControls {
    [self setControlsHidden:YES];
}

-(IBAction)onClickOverlay:(id)sender {
    if (self.controlPanelView.isHidden)
    {DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
        [self setControlsHidden:NO];
        [self refreshMediaControl];
        [self performSelector:@selector(hideControls) withObject:nil afterDelay:5.0f];
    }
    else
    {DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls) object:nil];
        [self hideControls];
    }
}

-(IBAction)onClickControlPanel:(id)sender {
    
}

-(IBAction)didSliderTouchDown:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    _isProgressSliderBeingDragged = YES;
}

-(IBAction)didSliderTouchUpInside:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    _ijkMovie.currentPlaybackTime = self.progressSlider.value;
    _isProgressSliderBeingDragged = NO;
}

-(IBAction)didSliderTouchUpOutside:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    _isProgressSliderBeingDragged = NO;
}

-(IBAction)didSliderTouchCancel:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    _isProgressSliderBeingDragged = NO;
}

-(IBAction)didSliderValueChanged:(id)sender {
    if (_isProgressSliderBeingDragged)
    {
        [self refreshMediaControl];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class] && [touch.view isKindOfClass:UISlider.class])
    {
        return NO;
    }
    return YES;
}

-(IBAction)onClickPlayOrPause:(id)sender {
    if (_ijkMovie.isPlaying)
    {DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
        [_ijkMovie pause];
        [self setPlayOrPauseButtonState:NO];
    }
    else
    {DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
        [_ijkMovie play];
        [self setPlayOrPauseButtonState:YES];
    }
}

-(void) stopAndReleaseMovieWriter {
    if (!_movieWriter)
        return;
    
    [_movieWriter finishRecording];
    _movieWriter = nil;
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
     //*/
}

-(void) disassembleMovieWriter {
    [_videoCamera removeTarget:_movieWriter];
    ///!!!_videoCamera.audioEncodingTarget = nil;
    [self stopAndReleaseMovieWriter];
}

-(void) initMovieWriterWithDateTime:(NSDate*)dateTime size:(CGSize)size {
    if (_movieWriter)
    {
        [self stopAndReleaseMovieWriter];
    }
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_hhmmss";
    NSString* fileName = [NSString stringWithFormat:@"MOV_%@.mp4", [formatter stringFromDate:dateTime]];
    NSString* pathToMovie = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:VideoDirectory] stringByAppendingPathComponent:fileName];
    //NSString* pathToMovie = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL* movieURL = [NSURL fileURLWithPath:pathToMovie];
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:size];
    _movieWriter.encodingLiveVideo = YES;
}

-(void) setupMovieWriter {
    [self initMovieWriterWithDateTime:[NSDate date] size:CGSizeMake(480.0, 640.0)];
    [_videoCamera addTarget:_movieWriter];
    _videoCamera.audioEncodingTarget = _movieWriter;
    ///[_ijkMovie addTarget:_movieWriter];
}

-(void) startMovieWriteRecording {
    [_movieWriter startRecording];
}

#pragma mark - View lifecycle

-(void) applicationDidBecomeActive:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    [self setupMovieWriter];
    [self startMovieWriteRecording];
    [_videoCamera resumeCameraCapture];
}

-(void) applicationWillResignActive:(id)sender {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    [self disassembleMovieWriter];
    [_videoCamera pauseCameraCapture];
}

-(void) dealloc {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeMovieNotificationObservers];
}

- (BOOL) prefersStatusBarHidden {
    return self.navBar.hidden;
}

-(UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

-(void) dismissSelf {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    [_ijkMovie shutdown];
    [self disassembleMovieWriter];
    [_videoCamera stopCameraCapture];
    [self removeMovieNotificationObservers];
    [self dismissViewControllerAnimated:YES completion:nil];
    _ijkMovie = nil;
}

-(void) showSubtitleAndAudioSelector {
    SubtitleAndAudioSelectionViewController* vc = [[SubtitleAndAudioSelectionViewController alloc] initWithStyle:UITableViewStyleGrouped dataSource:_ijkMovie.monitor.mediaMeta selectedAudioStream:_ijkMovie.currentAudioStream selectedSubtitleStream:_ijkMovie.currentSubtitleStream selectedHandler:^(NSInteger selectedStream) {
        NSLog(@"SubtitleAndAudioSelectionViewController selectedStream=%ld", selectedStream);
        [_ijkMovie selectStream:(int)selectedStream];
    } completion:^() {
        _ijkMovie.currentPlaybackTime = _ijkMovie.currentPlaybackTime - 0.1f;
        [_ijkMovie play];
    }];
    [self presentViewController:vc animated:NO completion:^() {
        [_ijkMovie pause];
    }];
}

-(void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _filterView.frame = self.overlayView.frame;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"sPLVC Next VC begin to load");
    //UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(dismissSelf)];
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    self.navItem.title = [self.sourceVideoFile lastPathComponent];
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];

    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
//    self.navigationController.navigationBarHidden = YES;

    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.overlayView.frame];
    _filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //_filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    [self.view addSubview:_filterView];
    _filterView.translatesAutoresizingMaskIntoConstraints = NO;
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    [self.view bringSubviewToFront:self.overlayView];
    [self.overlayView bringSubviewToFront:self.controlPanelView];
    
    UITapGestureRecognizer* tapRecognizer= [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTapRecognized:)];
    tapRecognizer.numberOfTapsRequired = 2;
    [self.overlayView addGestureRecognizer:tapRecognizer];
    
    UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanRecognized:)];
    panRecognizer.minimumNumberOfTouches = 1;
    panRecognizer.delegate = self;
    [self.overlayView addGestureRecognizer:panRecognizer];
    _fastSeekStartTime = 0.f;
    
    _isProgressSliderBeingDragged = NO;
    self.playOrPauseButton.tag = 100;
    
    _filter = [[GPUImageSepiaFilter alloc] init];
    [(GPUImageSepiaFilter*)_filter setIntensity:0.f];
//*
    _accessoriesView = [[AccessoriesView alloc] initWithFrame:_filterView.bounds];
    _accessoriesView.backgroundColor = [UIColor clearColor];
    _accessoriesView.layer.backgroundColor = [UIColor clearColor].CGColor;
    
    GPUImageUIElement* uiElement = [[GPUImageUIElement alloc] initWithView:_accessoriesView];
    GPUImageAlphaBlendFilter* blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    blendFilter.mix = 1.0f;
    [_filter addTarget:blendFilter];
    [uiElement addTarget:blendFilter];
    [blendFilter addTarget:_filterView];
    
    __weak typeof(self) wSelf = self;
    [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime) {
        __strong typeof(self) sSelf = wSelf;
        [sSelf.accessoriesView setNeedsDisplay];
        [uiElement update];
    }];
 /*/
    [_filter addTarget:_filterView];
//*/
    
    [self installMovieNotificationObservers];
#ifdef SourceVideoFileName
    _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:SourceVideoFileName]];
#else
    _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:self.sourceVideoFile muted:NO];
    //_ijkMovie.withSpeechRecognition = YES;
    //_ijkMovie.withFaceDetect = YES;
#endif
    _ijkMovie.delegate = self;
    [_ijkMovie setPauseInBackground:YES];
    [_ijkMovie addTarget:_filter];
    [_ijkMovie prepareToPlay];
    [self refreshMediaControl];
    
    [self setupMovieWriter];
    [self startMovieWriteRecording];
    [_videoCamera startCameraCapture];
    [_videoCamera resumeCameraCapture];
    NSLog(@"sPLVC Next VC finished load");
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowEditor"])
    {
        SnapshotEditorViewController* destVC = (SnapshotEditorViewController*)segue.destinationViewController;
        destVC.image = (UIImage*)sender;
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
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

-(void) onDoubleTapRecognized:(UITapGestureRecognizer*)pan {
    DoctorLog(@"#VideoCapture# %s @ line%d", __FUNCTION__, __LINE__);
    [_filter useNextFrameForImageCapture];
    UIImage* image = [_filter imageFromCurrentFramebuffer];
    if (image)
    {
        /*
        [_ijkMovie pause];
        [self performSegueWithIdentifier:@"ShowEditor" sender:image];
        //SnapshotEditorViewController* editorVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"SnapshotEditor"];
        //editorVC.image = image;
        //[self presentViewController:editorVC animated:YES completion:nil];
        /*/
        //[self onClickPlayOrPause:self.playOrPauseButton];
        static NSTimer* tickTimer = nil;
        /*static dispatch_once_t predicate;
        dispatch_once(&predicate, ^{
            tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:YES block:^(NSTimer * _Nonnull timer) {
                _ijkMovie.currentPlaybackTime = _ijkMovie.currentPlaybackTime - 0.033f;
            }];
        });//*/
        if (!tickTimer)
        {
            //[_ijkMovie pause];
            tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f repeats:YES block:^(NSTimer * _Nonnull timer) {
                _ijkMovie.currentPlaybackTime = _ijkMovie.currentPlaybackTime - 0.033f;
            }];
            //[[NSRunLoop currentRunLoop] addTimer:tickTimer forMode:NSDefaultRunLoopMode];
            [_ijkMovie setPlaybackRate:-1.f];
        }
        else
        {
            [tickTimer invalidate];
            tickTimer = nil;
            [_ijkMovie setPlaybackRate:1.f];
        }
        //*/
    }
}

-(void) onPanRecognized:(UIPanGestureRecognizer*)pan {
    CGPoint translation = [pan translationInView:pan.view];
    float offsetSeconds = 300.f * translation.x / pan.view.frame.size.width;
    
    if (UIGestureRecognizerStateBegan == pan.state)
    {
        _fastSeekStartTime = _ijkMovie.currentPlaybackTime;
    }
    float destTime = _fastSeekStartTime + offsetSeconds;
    int hours = roundf(destTime);
    int seconds = hours % 60;
    hours /= 60;
    int minutes = hours % 60;
    hours /= 60;
    
    switch (pan.state)
    {
        case UIGestureRecognizerStateBegan:
            DoctorLog(@"#VideoCapture# %s UIGestureRecognizerStateBegan @ line%d", __FUNCTION__, __LINE__);
            self.fastSeekLabel.hidden = NO;
            break;
        case UIGestureRecognizerStateChanged:
            [self setControlsHidden:NO];
            [self refreshMediaControl];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            DoctorLog(@"#VideoCapture# %s UIGestureRecognizerStateEnded @ line%d", __FUNCTION__, __LINE__);
            self.fastSeekLabel.hidden = YES;
            _ijkMovie.currentPlaybackTime = destTime;
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls) object:nil];
            [self performSelector:@selector(hideControls) withObject:nil afterDelay:5.0f];
            _fastSeekStartTime = 0.f;
            break;
        default:
            break;
    }
    self.fastSeekLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
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
    BOOL hasAnythingToSelect = NO;
    NSArray<NSDictionary* >* streams = [_ijkMovie.monitor.mediaMeta objectForKey:kk_IJKM_KEY_STREAMS];
    NSLog(@"#Decoder# streams = %@", streams);
    NSInteger streamIndex = 0;
    for (NSDictionary* stream in streams)
    {
        NSString* type = [stream objectForKey:k_IJKM_KEY_TYPE];
        NSString* title = [stream objectForKey:k_IJKM_KEY_TITLE];
        if ([type isEqualToString:@IJKM_VAL_TYPE__AUDIO] && title)
        {
            hasAnythingToSelect = YES;
            break;
        }
        if ([type isEqualToString:@IJKM_VAL_TYPE__TIMEDTEXT] && title)
        {
            hasAnythingToSelect = YES;
            break;
        }
        streamIndex++;
    }
    
    if (hasAnythingToSelect)
    {
        UIBarButtonItem* moreButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_more"] style:UIBarButtonItemStylePlain target:self action:@selector(showSubtitleAndAudioSelector)];
        self.navItem.rightBarButtonItem = moreButtonItem;
    }
    else
    {
        self.navItem.rightBarButtonItem = nil;
    }
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_ijkMovie];
}

#pragma mark IJKGPUImageMovieDelegate
-(void) ijkGIMovieRenderedOneFrame:(id)ijkgpuMovie {
//    UIImage* image = [ijkgpuMovie snapshotImage];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        _imageView.image = image;
//        NSLog(@"#ImageView# image.size=(%f,%f)", image.size.width, image.size.height);
//    });
}

-(void) ijkGIMovieDidRecognizeSpeech:(IJKGPUImageMovie *)ijkgpuMovie result:(NSString *)result {
    
}

-(void) ijkGIMovieDidDetectFaces:(IJKGPUImageMovie *)ijkgpuMovie result:(NSArray *)result {
    if (!result || result.count == 0) return;
    _accessoriesView.arrPersons = result;
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [_accessoriesView setNeedsDisplay];
//    });
}

@end
