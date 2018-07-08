//
//  VideoSnapshotViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import "VideoSnapshotViewController.h"
#import "IJKGPUImageMovie.h"
#import "IFlyFaceDetectResultParser.h"
#import "SnapshotEditorViewController.h"
#import "UINavigationBar+Translucent.h"
#import "SubtitleAndAudioSelectionViewController.h"
#import "FilterCollectionView.h"
#import "WeiXinConstant.h"
#import "UIImage+Share.h"
#import "WXApiRequestHandler.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/ALAssetsLibrary.h>

#define VideoSource_IJKGPUImageMovie_VideoPlay 2

#define VideoSource VideoSource_IJKGPUImageMovie_VideoPlay

#pragma mark    VideoSnapshotViewController
@interface VideoSnapshotViewController () <IJKGPUImageMovieDelegate, UIGestureRecognizerDelegate>
{
    BOOL _isProgressSliderBeingDragged;
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

@property (nonatomic, weak) IBOutlet FilterCollectionView* filterCollectionView;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* filterButtonItem;

@property (nonatomic, strong) GPUImageFilter* filter;
@property (nonatomic, strong) GPUImageView* filterView;
@property (nonatomic, strong) IJKGPUImageMovie* ijkMovie;

-(IBAction)onFilterButtonPressed:(id)sender;

-(IBAction)onClickOverlay:(id)sender;

-(IBAction)didSliderTouchDown:(id)sender;
-(IBAction)didSliderTouchUpInside:(id)sender;
-(IBAction)didSliderTouchUpOutside:(id)sender;
-(IBAction)didSliderTouchCancel:(id)sender;
-(IBAction)didSliderValueChanged:(id)sender;

-(IBAction)onClickPlayOrPause:(id)sender;

@end

@implementation VideoSnapshotViewController

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
    self.playOrPauseButton.hidden = hidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void) hideControls {
    [self setControlsHidden:YES];
}

-(IBAction)onClickOverlay:(id)sender {
    if (self.controlPanelView.isHidden)
    {
        [self setControlsHidden:NO];
        [self refreshMediaControl];
        [self performSelector:@selector(hideControls) withObject:nil afterDelay:5.0f];
    }
    else
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControls) object:nil];
        [self hideControls];
    }
}

-(IBAction)didSliderTouchDown:(id)sender {
    _isProgressSliderBeingDragged = YES;
}

-(IBAction)didSliderTouchUpInside:(id)sender {
    _ijkMovie.currentPlaybackTime = self.progressSlider.value;
    _isProgressSliderBeingDragged = NO;
}

-(IBAction)didSliderTouchUpOutside:(id)sender {
    _isProgressSliderBeingDragged = NO;
}

-(IBAction)didSliderTouchCancel:(id)sender {
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
    {
        [_ijkMovie pause];
        [self setPlayOrPauseButtonState:NO];
    }
    else
    {
        [_ijkMovie play];
        [self setPlayOrPauseButtonState:YES];
    }
}

#pragma mark - View lifecycle

-(void) applicationDidBecomeActive:(id)sender {
}

-(void) applicationWillResignActive:(id)sender {
}

-(void) dealloc {
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
    [_ijkMovie shutdown];
    [self removeMovieNotificationObservers];
    [self dismissViewControllerAnimated:YES completion:nil];
    _ijkMovie = nil;
}

-(void) takeSnapshot {
    __weak typeof(self) wSelf = self;
    self.filterView.snapshotCompletion = ^(UIImage* image) {
        if (!image)
            return;
        
        AudioServicesPlaySystemSound(1108);
        
        __strong typeof(self) pSelf = wSelf;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CGFloat contentScale = pSelf.overlayView.layer.contentsScale;
            CGSize layerSize = CGSizeMake(contentScale * pSelf.overlayView.bounds.size.width,
                                          contentScale * pSelf.overlayView.bounds.size.height);
            CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
            CGContextRef imageContext = CGBitmapContextCreate(NULL, (int)layerSize.width, (int)layerSize.height, 8, (int)layerSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
            
            CGContextDrawImage(imageContext, CGRectMake(0, 0, layerSize.width, layerSize.height), image.CGImage);
            
            CGContextScaleCTM(imageContext, contentScale, contentScale);
            [pSelf.overlayView.layer renderInContext:imageContext];
            
            UIImage* snapshot = [UIImage imageWithCGImage:CGBitmapContextCreateImage(imageContext) scale:1.0f orientation:UIImageOrientationDownMirrored];
            snapshot = [snapshot imageScaledToFitMaxSize:CGSizeMake(MaxWidthOfImageToShare, MaxHeightOfImageToShare) orientation:UIImageOrientationDownMirrored];
            NSData* data = UIImageJPEGRepresentation(snapshot, 1.0f);
            NSString* fileName = [NSString stringWithFormat:@"snapshot_%f.jpg", [[NSDate date] timeIntervalSince1970]];
            NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
            [data writeToFile:path atomically:YES];
            
            UIImage* thumbImage = [snapshot imageScaledToFitMaxSize:CGSizeMake(snapshot.size.width/2, snapshot.size.height/2) orientation:UIImageOrientationUp];
            ///dispatch_async(dispatch_get_main_queue(), ^{
            BOOL succ = [WXApiRequestHandler sendImageData:data
                                                   TagName:kImageTagName
                                                MessageExt:kMessageExt
                                                    Action:kMessageAction
                                                ThumbImage:thumbImage
                                                   InScene:WXSceneTimeline];//WXSceneSession
            NSLog(@"#WX# Send message succ = %d", succ);
            /*
             NSArray *activityItems = @[data0, data1];
             UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
             [self presentViewController:activityVC animated:TRUE completion:nil];
             //*/
            ///});
            
            CGContextRelease(imageContext);
            CGColorSpaceRelease(genericRGBColorspace);
        });
    };
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"sPLVC Next VC begin to load");
    //UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(dismissSelf)];
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    UIBarButtonItem* snapshotButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_more"] style:UIBarButtonItemStylePlain target:self action:@selector(takeSnapshot)];
    self.navItem.rightBarButtonItem = snapshotButtonItem;
    self.navItem.title = [self.sourceVideoFile lastPathComponent];
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];

    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
//    self.navigationController.navigationBarHidden = YES;
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //_filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    [self.view addSubview:_filterView];
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    [self.view bringSubviewToFront:self.overlayView];
    [self.view bringSubviewToFront:self.controlPanelView];
    
    _isProgressSliderBeingDragged = NO;
    self.playOrPauseButton.tag = 100;
    
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
    [_ijkMovie addTarget:_filterView];
    [_ijkMovie prepareToPlay];
    [self refreshMediaControl];
    
    _filter = nil;
    __weak typeof(self) wSelf = self;
    self.filterCollectionView.filterSelectedHandler = ^(GPUImageFilter* filter) {
        __strong typeof(self) pSelf = wSelf;
        if (!pSelf.filter)
        {
            [pSelf.ijkMovie removeTarget:pSelf.filterView];
        }
        else
        {
            [pSelf.filter removeTarget:pSelf.filterView];
            [pSelf.ijkMovie removeTarget:pSelf.filter];
        }
        
        if (filter)
        {
            [pSelf.ijkMovie addTarget:filter];
            [filter addTarget:pSelf.filterView];
        }
        else
        {
            [pSelf.ijkMovie addTarget:pSelf.filterView];
        }
        ///[pSelf.ijkMovie render];
        pSelf.filter = filter;
    };
    
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
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES; // Support all orientations.
}

-(void) onDoubleTapRecognized:(UITapGestureRecognizer*)pan {
    [_filter useNextFrameForImageCapture];
    ///[_ijkMovie render];
    UIImage* image = [_filter imageFromCurrentFramebuffer];
    if (image)
    {
        [_ijkMovie pause];
        //*
        [self performSegueWithIdentifier:@"ShowEditor" sender:image];
        /*/
        SnapshotEditorViewController* editorVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"SnapshotEditor"];
        editorVC.image = image;
        [self presentViewController:editorVC animated:YES completion:nil];
        //*/
    }
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
    /*
    if (hasAnythingToSelect)
    {
        UIBarButtonItem* moreButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_more"] style:UIBarButtonItemStylePlain target:self action:@selector(showSubtitleAndAudioSelector)];
        self.navItem.rightBarButtonItem = moreButtonItem;
    }
    else
    {
        self.navItem.rightBarButtonItem = nil;
    }//*/
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
}

#pragma mark    Filters

-(IBAction)onFilterButtonPressed:(id)sender {
    if (self.filterCollectionView.hidden)
    {
        self.filterCollectionView.hidden = NO;
        self.filterButtonItem.tintColor = [UIColor blueColor];
    }
    else
    {
        self.filterCollectionView.hidden = YES;
        self.filterButtonItem.tintColor = [UIColor whiteColor];
    }
}

@end
