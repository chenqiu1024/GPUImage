//
//  CameraPlayerViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2017/5/25.
//  Copyright © 2017年 DOM QIU. All rights reserved.
//

#import "CameraPlayerViewController.h"
#import "IJKGPUImageMovie.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

#define VideoSource_IJKGPUImageMovie_VideoPlay 2

#define VideoSource VideoSource_IJKGPUImageMovie_VideoPlay

static NSString* SelectionTableViewHeaderIdentifier = @"SelectionTableViewHeaderIdentifier";
static NSString* SelectionTableViewCellIdentifier = @"SelectionTableViewCellIdentifier";
static NSString* SelectionTableViewButtonCellIdentifier = @"SelectionTableViewButtonCellIdentifier";

@interface SubtitleAndAudioSelectionViewController : UITableViewController
{
    NSMutableArray<NSString* >* _audios;
    NSMutableArray<NSString* >* _subtitles;
    NSMutableDictionary<NSNumber*, NSNumber* >* _audioIndex2StreamIndex;
    NSMutableDictionary<NSNumber*, NSNumber* >* _subtitleIndex2StreamIndex;
    NSInteger _selectedAudio;
    NSInteger _selectedSubtitle;
    void(^_selectedHandler)(NSInteger);
    void(^_completion)();
}

-(void) setDataSource:(NSDictionary*)mediaMeta;

@end

@implementation SubtitleAndAudioSelectionViewController

-(void) setDataSource:(NSDictionary*)mediaMeta {
    [_audios removeAllObjects];
    [_subtitles removeAllObjects];
    [_audioIndex2StreamIndex removeAllObjects];
    [_subtitleIndex2StreamIndex removeAllObjects];
    NSArray<NSDictionary* >* streams = [mediaMeta objectForKey:kk_IJKM_KEY_STREAMS];
    NSInteger streamIndex = 0;
    for (NSDictionary* stream in streams)
    {
        NSString* type = [stream objectForKey:k_IJKM_KEY_TYPE];
        NSString* title = [stream objectForKey:k_IJKM_KEY_TITLE];
        if ([type isEqualToString:@IJKM_VAL_TYPE__AUDIO] && title)
        {
            [_audioIndex2StreamIndex setObject:@(streamIndex) forKey:@(_audios.count)];
            [_audios addObject:title];
        }
        if ([type isEqualToString:@IJKM_VAL_TYPE__TIMEDTEXT] && title)
        {
            [_subtitleIndex2StreamIndex setObject:@(streamIndex) forKey:@(_subtitles.count)];
            [_subtitles addObject:title];
        }
        streamIndex++;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (instancetype)initWithStyle:(UITableViewStyle)style dataSource:(NSDictionary*)mediaMeta selectedAudioStream:(NSInteger)selectedAudioStream selectedSubtitleStream:(NSInteger)selectedSubtitleStream selectedHandler:(void(^)(NSInteger))selectedHandler completion:(void(^)())completion {
    if (self = [super initWithStyle:style])
    {
        _audios = [[NSMutableArray alloc] init];
        _subtitles = [[NSMutableArray alloc] init];
        _audioIndex2StreamIndex = [[NSMutableDictionary alloc] init];
        _subtitleIndex2StreamIndex = [[NSMutableDictionary alloc] init];
        _selectedAudio = selectedAudioStream;
        _selectedSubtitle = selectedSubtitleStream;
        _completion = completion;
        _selectedHandler = selectedHandler;
        [self setDataSource:mediaMeta];
    }
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
//    self.automaticallyAdjustsScrollViewInsets = YES;
//    self.edgesForExtendedLayout = UIRectEdgeNone;
//    self.extendedLayoutIncludesOpaqueBars = NO;
    self.tableView.contentInset = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger sections = 1;
    if (_audios.count > 0) sections++;
    if (_subtitles.count > 0) sections++;
    return sections;
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return _audios.count;
    else if (section == 1)
        return _subtitles.count;
    return 1;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 2) return 0;
    return 24.f;
}

-(NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section)
    {
        case 0:
            return @"Audio(s):";
        case 1:
            return @"Subtitle(s):";
        default:
            return nil;
    }
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* identifier = (indexPath.section != 2 ? SelectionTableViewCellIdentifier : SelectionTableViewButtonCellIdentifier);
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    switch (indexPath.section)
    {
        case 0:
        {
            cell.textLabel.text = _audios[indexPath.row];
            NSNumber* streamIndex = [_audioIndex2StreamIndex objectForKey:@(indexPath.row)];
            if (streamIndex.integerValue == _selectedAudio)
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        case 1:
        {
            cell.textLabel.text = _subtitles[indexPath.row];
            NSNumber* streamIndex = [_subtitleIndex2StreamIndex objectForKey:@(indexPath.row)];
            if (streamIndex.integerValue == _selectedSubtitle)
            {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            else
            {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            break;
        case 2:
        {
            UILabel* label = [[UILabel alloc] init];
            label.text = @"OK";
            [label sizeToFit];
            label.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            [cell.contentView addSubview:label];
            [label setCenter:cell.contentView.center];
//            cell.textLabel.textAlignment = NSTextAlignmentCenter;
//            cell.textLabel.text = @"OK";
        }
            break;
        default:
            break;
    }
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (0 == indexPath.section)
    {
        NSNumber* streamIndex = [_audioIndex2StreamIndex objectForKey:@(indexPath.row)];
        _selectedAudio = streamIndex.integerValue;
        if (_selectedHandler)
        {
            _selectedHandler(_selectedAudio);
        }
    }
    else if (1 == indexPath.section)
    {
        NSNumber* streamIndex = [_subtitleIndex2StreamIndex objectForKey:@(indexPath.row)];
        _selectedSubtitle = streamIndex.integerValue;
        if (_selectedHandler)
        {
            _selectedHandler(_selectedSubtitle);
        }
    }
    else if (2 == indexPath.section)
    {
        [self dismissViewControllerAnimated:NO completion:^{
            if (_completion)
            {
                _completion();
            }
        }];
    }
    [tableView reloadData];
}

@end

@interface CameraPlayerViewController () <IJKGPUImageMovieDelegate>
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
@property (nonatomic, weak) IBOutlet UINavigationBar* navigationBar;
@property (nonatomic, weak) IBOutlet UIView* controlPanelView;
@property (nonatomic, weak) IBOutlet UIButton* playOrPauseButton;
@property (nonatomic, weak) IBOutlet UISlider* progressSlider;
@property (nonatomic, weak) IBOutlet UILabel* durationLabel;
@property (nonatomic, weak) IBOutlet UILabel* currentTimeLabel;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UILabel* fastSeekLabel;

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
    self.navigationBar.hidden = hidden;
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

-(IBAction)onClickControlPanel:(id)sender {
    
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
    _videoCamera.audioEncodingTarget = nil;
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
    ///!!![_ijkMovie addTarget:_movieWriter];
}

-(void) startMovieWriteRecording {
    [_movieWriter startRecording];
}

#pragma mark - View lifecycle

-(void) applicationDidBecomeActive:(id)sender {
    [self setupMovieWriter];
    [_videoCamera resumeCameraCapture];
    [self startMovieWriteRecording];
}

-(void) applicationWillResignActive:(id)sender {
    [self disassembleMovieWriter];
    [_videoCamera pauseCameraCapture];
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeMovieNotificationObservers];
}

- (BOOL) prefersStatusBarHidden {
    return YES;
}

-(void) dismissSelf {
    [_ijkMovie shutdown];
    [self disassembleMovieWriter];
    [_videoCamera stopCameraCapture];
    [self removeMovieNotificationObservers];
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) showSubtitleAndAudioSelector {
    SubtitleAndAudioSelectionViewController* vc = [[SubtitleAndAudioSelectionViewController alloc] initWithStyle:UITableViewStyleGrouped dataSource:_ijkMovie.monitor.mediaMeta selectedAudioStream:_ijkMovie.currentAudioStream selectedSubtitleStream:_ijkMovie.currentSubtitleStream selectedHandler:^(NSInteger selectedStream) {
        NSLog(@"SubtitleAndAudioSelectionViewController selectedStream=%ld", selectedStream);
        [_ijkMovie selectStream:(int)selectedStream];
    } completion:^() {
        _ijkMovie.currentPlaybackTime = _ijkMovie.currentPlaybackTime - 1.f;
        [_ijkMovie play];
    }];
    [self presentViewController:vc animated:NO completion:^() {
        [_ijkMovie pause];
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(dismissSelf)];
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    
    self.navItem.title = [self.sourceVideoFile lastPathComponent];
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
//    self.navigationController.navigationBarHidden = YES;

    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
    _filterView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //_filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    [self.view addSubview:_filterView];
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    [self.view bringSubviewToFront:self.overlayView];
    [self.view bringSubviewToFront:self.controlPanelView];
    
    UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanRecognized:)];
    panRecognizer.minimumNumberOfTouches = 1;
    [self.overlayView addGestureRecognizer:panRecognizer];
    _fastSeekStartTime = 0.f;
    
    _isProgressSliderBeingDragged = NO;
    self.playOrPauseButton.tag = 100;
    
    _filter = [[GPUImageSepiaFilter alloc] init];
    [(GPUImageSepiaFilter*)_filter setIntensity:0.f];
    [_filter addTarget:_filterView];
    
    [_videoCamera startCameraCapture];
    [_videoCamera resumeCameraCapture];
    
    [self installMovieNotificationObservers];
#ifdef SourceVideoFileName
    _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:SourceVideoFileName]];
#else
    _ijkMovie = [[IJKGPUImageMovie alloc] initWithContentURLString:self.sourceVideoFile];
#endif
    _ijkMovie.delegate = self;
    [_ijkMovie setPauseInBackground:YES];
    [_ijkMovie addTarget:_filter];
    [_ijkMovie prepareToPlay];
    [self refreshMediaControl];
    
    [self setupMovieWriter];
    [self startMovieWriteRecording];
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
            self.fastSeekLabel.hidden = NO;
            break;
        case UIGestureRecognizerStateChanged:
            [self setControlsHidden:NO];
            [self refreshMediaControl];
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerLoadStateDidChangeNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:_ijkMovie];
//    [[NSNotificationCenter defaultCenter]removeObserver:self name:IJKMPMoviePlayerPlaybackStateDidChangeNotification object:_ijkMovie];
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
