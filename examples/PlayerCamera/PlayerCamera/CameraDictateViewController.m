//
//  CameraDictateViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/4.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "CameraDictateViewController.h"
#import <GPUImage.h>
#import <iflyMSC/IFlyMSC.h>
#import "ISRDataHelper.h"

@interface CameraDictateViewController () <IFlySpeechRecognizerDelegate>

@property (nonatomic, strong) GPUImageVideoCamera* videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter* movieWriter;

@property (nonatomic, strong) IFlySpeechRecognizer* speechRecognizer;
@property (nonatomic, copy) NSString* speechRecognizerResultString;

-(IBAction)onShootButtonPressed:(id)sender;

-(IBAction)onRotateCameraButtonPressed:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton* shootButton;
@property (nonatomic, strong) IBOutlet UIButton* rotateCameraButton;
@property (nonatomic, strong) IBOutlet UILabel* dictateLabel;

-(void) initSpeechRecognizer;
-(BOOL) startSpeechRecognizer;
-(void) stopSpeechRecognizer;

@end

@implementation CameraDictateViewController

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
    ///_videoCamera.audioEncodingTarget = _movieWriter;
    ///[_ijkMovie addTarget:_movieWriter];
}

-(IBAction)onShootButtonPressed:(id)sender {
    if (0 == self.shootButton.tag)
    {
        self.shootButton.tag = 1;
        [self.shootButton setTitle:@"Shooting..." forState:UIControlStateNormal];
        _movieWriter.paused = NO;
    }
    else
    {
        self.shootButton.tag = 0;
        [self.shootButton setTitle:@"Shoot" forState:UIControlStateNormal];
        _movieWriter.paused = YES;
    }
}

-(IBAction)onRotateCameraButtonPressed:(id)sender {
    ///!!![_videoCamera rotateCamera];
    [self startSpeechRecognizer];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.shootButton.tag = 0;
//*
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    GPUImageView* gpuimageView = (GPUImageView*)self.view;
    [_videoCamera addTarget:gpuimageView];
    [self setupMovieWriter];
    _movieWriter.paused = YES;
    [_movieWriter startRecording];
    
    [_videoCamera startCameraCapture];
//*/
    self.speechRecognizerResultString = @"";
    [self initSpeechRecognizer];
    //[self startSpeechRecognizer];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //*
    ///[self initSpeechRecognizer];
    ///[self startSpeechRecognizer];
    /*/
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    //*/
}

-(void)viewWillDisappear:(BOOL)animated
{
    /*
    [self stopSpeechRecognizer];
    
    [_speechRecognizer cancel];
    [_speechRecognizer setDelegate:nil];
    [_speechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    //*/
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) applicationDidBecomeActive:(id)sender {
    [self initSpeechRecognizer];
    ///[self startSpeechRecognizer];
}

-(void) applicationWillResignActive:(id)sender {
    [self stopSpeechRecognizer];
    
    [self releaseSpeechRecognizer];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
#pragma mark    IFLY
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
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dictateLabel.text = self.speechRecognizerResultString;
    });
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
