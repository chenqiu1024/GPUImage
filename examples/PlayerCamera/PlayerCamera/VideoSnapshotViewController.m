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
#import <iflyMSC/IFlyMSC.h>
#import "ISRDataHelper.h"
#import "UINavigationBar+Translucent.h"
#import "PhotoLibraryHelper.h"
#import "TextEditViewController.h"
#import "UIViewController+Extensions.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/ALAssetsLibrary.h>

#define DictateLabelBottomMargin 6.0f

#pragma mark    VideoSnapshotViewController
@interface VideoSnapshotViewController () <IJKGPUImageMovieDelegate, UIGestureRecognizerDelegate, IFlySpeechRecognizerDelegate>
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

@property (nonatomic, weak) IBOutlet UIToolbar* toolbar;
@property (nonatomic, weak) IBOutlet FilterCollectionView* filterCollectionView;

@property (nonatomic, weak) IBOutlet UILabel* dictateLabel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* dictateButtonItem;

@property (nonatomic, assign) CGSize snapshotScreenSize;

@property (nonatomic, strong) GPUImageFilter* filter;
@property (nonatomic, weak) IBOutlet GPUImageView* filterView;
@property (nonatomic, strong) IJKGPUImageMovie* ijkMovie;

@property (nonatomic, strong) IFlySpeechRecognizer* speechRecognizer;
@property (nonatomic, copy) NSString* speechRecognizerResultString;

-(IBAction)onDictateButtonPressed:(id)sender;

-(IBAction)onTypeButtonPressed:(id)sender;

-(IBAction)onClickOverlay:(id)sender;

-(IBAction)didSliderTouchDown:(id)sender;
-(IBAction)didSliderTouchUpInside:(id)sender;
-(IBAction)didSliderTouchUpOutside:(id)sender;
-(IBAction)didSliderTouchCancel:(id)sender;
-(IBAction)didSliderValueChanged:(id)sender;

-(IBAction)onClickPlayOrPause:(id)sender;

-(void) initSpeechRecognizer;
-(BOOL) startSpeechRecognizer;
-(void) stopSpeechRecognizer;
-(void) releaseSpeechRecognizer;

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
    self.toolbar.hidden = hidden;
    self.filterCollectionView.hidden = hidden;
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
    if (self.dictateButtonItem.tag == 1)
    {
        [self initSpeechRecognizer];
        [self startSpeechRecognizer];
    }
}

-(void) applicationWillResignActive:(id)sender {
    if (self.dictateButtonItem.tag == 1)
    {
        [self stopSpeechRecognizer];
        [self releaseSpeechRecognizer];
    }
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeMovieNotificationObservers];
}

- (BOOL) prefersStatusBarHidden {
    return NO;///!!!self.navBar.hidden;
}

-(UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

-(void) dismissSelf:(PHAsset*)phAsset {
    [self stopSpeechRecognizer];
    [self releaseSpeechRecognizer];
    [_ijkMovie shutdown];
    [self removeMovieNotificationObservers];
    [self dismissViewControllerAnimated:YES completion:nil];
    _ijkMovie = nil;
    if (self.completionHandler)
    {
        self.completionHandler(phAsset);
    }
}

-(void) dismissSelf {
    [self dismissSelf:nil];
}

-(void) takeSnapshot {
    [self stopSpeechRecognizer];
    [self releaseSpeechRecognizer];
    
    __weak typeof(self) wSelf = self;
    self.filterView.snapshotCompletion = ^(UIImage* image) {
        if (!image)
            return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) pSelf = wSelf;
            [pSelf hideControls];
            AudioServicesPlaySystemSound(1108);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                CGFloat contentScale = pSelf.overlayView.layer.contentsScale;
                //            CGSize layerSize = CGSizeMake(contentScale * pSelf.overlayView.bounds.size.width,
                //                                          contentScale * pSelf.overlayView.bounds.size.height);
                CGSize layerSize = CGSizeMake(contentScale * pSelf.snapshotScreenSize.width,
                                              contentScale * pSelf.snapshotScreenSize.height);
                CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
                CGContextRef imageContext = CGBitmapContextCreate(NULL, (int)layerSize.width, (int)layerSize.height, 8, (int)layerSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
                
                CGContextScaleCTM(imageContext, contentScale, -contentScale);
                if (pSelf.snapshotScreenSize.width < pSelf.overlayView.bounds.size.width)
                {
                    CGContextTranslateCTM(imageContext, (pSelf.snapshotScreenSize.width - pSelf.overlayView.bounds.size.width) * contentScale / 2, -pSelf.overlayView.bounds.size.height * contentScale);
                }
                else
                {
                    CGContextTranslateCTM(imageContext, 0.f, -(pSelf.snapshotScreenSize.height + pSelf.overlayView.bounds.size.height) * contentScale / 2);
                }
                CGContextDrawImage(imageContext, CGRectMake(0, 0, pSelf.overlayView.bounds.size.width, pSelf.overlayView.bounds.size.height), image.CGImage);
                [pSelf.overlayView.layer renderInContext:imageContext];
                
                UIImage* snapshot = [UIImage imageWithCGImage:CGBitmapContextCreateImage(imageContext) scale:1.0f orientation:UIImageOrientationUp];
                snapshot = [snapshot imageScaledToFitMaxSize:CGSizeMake(MaxWidthOfImageToShare, MaxHeightOfImageToShare) orientation:UIImageOrientationUp];
                NSData* data = UIImageJPEGRepresentation(snapshot, 1.0f);
                NSString* fileName = [NSString stringWithFormat:@"snapshot_%f.jpg", [[NSDate date] timeIntervalSince1970]];
                NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
                [data writeToFile:path atomically:YES];
                
                CGContextRelease(imageContext);
                CGColorSpaceRelease(genericRGBColorspace);
                
                [PhotoLibraryHelper saveImageWithUrl:[NSURL fileURLWithPath:path] collectionTitle:@"CartoonShow" completionHandler:^(BOOL success, NSError* error, NSString* assetId) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                    PHAsset* asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil].firstObject;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [pSelf dismissSelf:asset];
                    });
                }];
                //            UIImage* thumbImage = [snapshot imageScaledToFitMaxSize:CGSizeMake(snapshot.size.width/2, snapshot.size.height/2) orientation:UIImageOrientationUp];
                //            BOOL succ = [WXApiRequestHandler sendImageData:data
                //                                                   TagName:kImageTagName
                //                                                MessageExt:kMessageExt
                //                                                    Action:kMessageAction
                //                                                ThumbImage:thumbImage
                //                                                   InScene:WXSceneTimeline];//WXSceneSession
                //            NSLog(@"#WX# Send message succ = %d", succ);
                /*
                 NSArray *activityItems = @[data0, data1];
                 UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
                 [self presentViewController:activityVC animated:TRUE completion:nil];
                 //*/
            });
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
    _snapshotScreenSize = CGSizeZero;
    //UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(dismissSelf)];
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    UIBarButtonItem* snapshotButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_more"] style:UIBarButtonItemStylePlain target:self action:@selector(takeSnapshot)];
    self.navItem.rightBarButtonItem = snapshotButtonItem;
    self.navItem.title = @"Take Video Snapshot";
    
    [self.navBar makeTranslucent];
    //[self.navBar setBackgroundAndShadowColor:[UIColor blackColor]];
    //[self.navBar setBackgroundColor:[UIColor blackColor]];
    //[self.navBar setBarTintColor:[UIColor blackColor]];
    //self.navBar.opaque = YES;
    //[self.navBar setTintColor:[UIColor blackColor]];
    [self setNeedsStatusBarAppearanceUpdate];

    [self.toolbar makeTranslucent];
    //[self.toolbar setBackgroundAndShadowColor:[UIColor blackColor]];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
//    self.navigationController.navigationBarHidden = YES;
    
    //_filterView = [[GPUImageView alloc] initWithFrame:self.overlayView.bounds];
    //_filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //_filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    //[self.overlayView addSubview:_filterView];
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    [self.view bringSubviewToFront:self.overlayView];
    //_filterView.userInteractionEnabled = YES;
    //[self.overlayView sendSubviewToBack:_filterView];
    
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
    
    self.speechRecognizerResultString = @"";
    [self initSpeechRecognizer];
    [self startSpeechRecognizer];
    
    self.dictateLabel.translatesAutoresizingMaskIntoConstraints = YES;
    
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
    if (_snapshotScreenSize.width == 0.f && _snapshotScreenSize.height == 0.f)
    {
        CGSize videoSize = _ijkMovie.inputVideoSize;
        if (kGPUImageFillModeStretch == _filterView.fillMode || kGPUImageFillModePreserveAspectRatioAndFill == _filterView.fillMode)
        {
            _snapshotScreenSize = _filterView.bounds.size;
        }
        else if (kGPUImageFillModePreserveAspectRatio == _filterView.fillMode)
        {
            if (videoSize.height * _filterView.bounds.size.width / videoSize.width <= _filterView.bounds.size.height)
            {
                _snapshotScreenSize = CGSizeMake(_filterView.bounds.size.width, videoSize.height * _filterView.bounds.size.width / videoSize.width);
            }
            else
            {
                _snapshotScreenSize = CGSizeMake(videoSize.width * _filterView.bounds.size.height / videoSize.height, _filterView.bounds.size.height);
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.dictateLabel sizeToFit];
            self.dictateLabel.frame = CGRectMake(0, (self.overlayView.bounds.size.height + _snapshotScreenSize.height) / 2 - self.dictateLabel.frame.size.height - DictateLabelBottomMargin, self.overlayView.bounds.size.width, self.dictateLabel.frame.size.height);
        });
    }
}

-(void) ijkGIMovieDidRecognizeSpeech:(IJKGPUImageMovie *)ijkgpuMovie result:(NSString *)result {
    
}

-(void) ijkGIMovieDidDetectFaces:(IJKGPUImageMovie *)ijkgpuMovie result:(NSArray *)result {
    if (!result || result.count == 0) return;
}

#pragma mark    Filters

#pragma mark    IFLY
-(void) updateDictateLabelText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dictateLabel.text = self.speechRecognizerResultString;
        //        self.dictateLabel.text = @"Dictate Text Label Test";
        [self.dictateLabel sizeToFit];
        self.dictateLabel.frame = CGRectMake(0, (self.overlayView.bounds.size.height + _snapshotScreenSize.height) / 2 - self.dictateLabel.frame.size.height - DictateLabelBottomMargin, self.overlayView.bounds.size.width, self.dictateLabel.frame.size.height);
    });
}

-(IBAction)onDictateButtonPressed:(id)sender {
    if (self.dictateButtonItem.tag == 1)
    {
        [self stopSpeechRecognizer];
        [self releaseSpeechRecognizer];
        
        self.dictateButtonItem.tintColor = [UIColor whiteColor];
        self.dictateButtonItem.tag = 0;
    }
    else
    {
        [self initSpeechRecognizer];
        [self startSpeechRecognizer];
        
        self.dictateButtonItem.tintColor = [UIColor blueColor];
        self.dictateButtonItem.tag = 1;
    }
}

-(void)onTypeButtonPressed:(id)sender {
    self.dictateButtonItem.tag = 1;
    [self onDictateButtonPressed:self.dictateButtonItem];
    //*
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Edit Text" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.placeholder = @"Enter text:";
        textField.text = self.speechRecognizerResultString;
        textField.secureTextEntry = NO;
        textField.frame = CGRectMake(0, 0, 600, 400);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        self.speechRecognizerResultString = alert.textFields[0].text;
        [self updateDictateLabelText];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    /*/
    TextEditViewController* vc = [[TextEditViewController alloc] initWithText:self.speechRecognizerResultString];
    vc.completionHandler = ^(NSString* text) {
        self.speechRecognizerResultString = text;
        self.dictateLabel.text = text;
    };
    [self setPresentationStyle:vc];
    [self presentViewController:vc animated:YES completion:nil];
    //*/
}

-(void) initSpeechRecognizer
{
    //recognition singleton without view
    _speechRecognizer = [IFlySpeechRecognizer sharedInstance];
    
    [_speechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    
    //set recognition domain
    [_speechRecognizer setParameter:@"iat" forKey:[IFlySpeechConstant IFLY_DOMAIN]];
    
    _speechRecognizer.delegate = self;
    
    if (_speechRecognizer != nil) {
        //set timeout of recording
        [_speechRecognizer setParameter:@"30000" forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
        //set VAD timeout of end of speech(EOS)
        [_speechRecognizer setParameter:@"3000" forKey:[IFlySpeechConstant VAD_EOS]];
        //set VAD timeout of beginning of speech(BOS)
        [_speechRecognizer setParameter:@"3000" forKey:[IFlySpeechConstant VAD_BOS]];
        //set network timeout
        [_speechRecognizer setParameter:@"20000" forKey:[IFlySpeechConstant NET_TIMEOUT]];
        
        //set sample rate, 16K as a recommended option
        [_speechRecognizer setParameter:@"16000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
        
        //set language
        [_speechRecognizer setParameter:@"zh_cn" forKey:[IFlySpeechConstant LANGUAGE]];
        //set accent
        [_speechRecognizer setParameter:@"mandarin" forKey:[IFlySpeechConstant ACCENT]];
        
        //set whether or not to show punctuation in recognition results
        [_speechRecognizer setParameter:@"1" forKey:[IFlySpeechConstant ASR_PTT]];
        
    }
}

-(void) releaseSpeechRecognizer {
    [_speechRecognizer cancel];
    [_speechRecognizer setDelegate:nil];
    [_speechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    _speechRecognizer = nil;
}

-(BOOL) startSpeechRecognizer {
    if(_speechRecognizer == nil)
    {
        [self initSpeechRecognizer];
    }
    
    [_speechRecognizer cancel];
    
    //Set microphone as audio source
    [_speechRecognizer setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    
    //Set result type
    [_speechRecognizer setParameter:@"json" forKey:[IFlySpeechConstant RESULT_TYPE]];
    
    //Set the audio name of saved recording file while is generated in the local storage path of SDK,by default in library/cache.
    [_speechRecognizer setParameter:@"asr.pcm" forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
    
    [_speechRecognizer setDelegate:self];
    
    BOOL ret = [_speechRecognizer startListening];
    return ret;
}

-(void) stopSpeechRecognizer {
    [_speechRecognizer stopListening];
}

/**
 recognition session completion, which will be invoked no matter whether it exits error.
 error.errorCode =
 0     success
 other fail
 **/
- (void) onCompleted:(IFlySpeechError *) error
{
    NSString* text = [NSString stringWithFormat:@"Error：%d %@", error.errorCode,error.errorDesc];
    NSLog(@"#IFLY# onCompleted :%@",text);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startSpeechRecognizer];
    });
}

/**
 result callback of recognition without view
 results：recognition results
 isLast：whether or not this is the last result
 **/
- (void) onResults:(NSArray *) results isLast:(BOOL)isLast
{
    NSMutableString* resultString = [[NSMutableString alloc] init];
    NSDictionary* dic = results[0];
    
    for(NSString* key in dic)
    {
        [resultString appendFormat:@"%@",key];
    }
    
    NSString* resultFromJson = [ISRDataHelper stringFromJson:resultString];
    
    self.speechRecognizerResultString = [NSString stringWithFormat:@"%@%@", self.speechRecognizerResultString, resultFromJson];
    //    NSLog(@"#IFLY# resultFromJson=%@",resultFromJson);
    NSLog(@"#IFLY# onResults isLast=%d,_textView.text=%@",isLast, self.speechRecognizerResultString);
    [self updateDictateLabelText];
}

-(void) onError:(IFlySpeechError*)errorCode {
    NSLog(@"#IFLY# onError %@", errorCode.errorDesc);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startSpeechRecognizer];
    });
    
}

-(void) onVolumeChanged:(int)volume {
    //NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onBeginOfSpeech {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onEndOfSpeech {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onCancel {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

@end
