//
//  CameraDictateViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/4.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "CameraDictateViewController.h"
#import "PhotoLibraryViewController.h"
#import "CameraPlayerViewController.h"
#import "SnapshotEditorViewController.h"
#import <GPUImage.h>
#import <iflyMSC/IFlyMSC.h>
#import "ISRDataHelper.h"
#import "UINavigationBar+Translucent.h"

@interface CameraDictateViewController () <IFlySpeechRecognizerDelegate>

@property (nonatomic, copy) NSString* movieSavePath;

@property (nonatomic, strong) GPUImageVideoCamera* videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter* movieWriter;

@property (nonatomic, strong) IFlySpeechRecognizer* speechRecognizer;
@property (nonatomic, copy) NSString* speechRecognizerResultString;

-(IBAction)onShootButtonPressed:(id)sender;

-(IBAction)onRotateCameraButtonPressed:(id)sender;

@property (nonatomic, strong) IBOutlet UINavigationBar* navBar;
@property (nonatomic, strong) IBOutlet UINavigationItem* navItem;

@property (nonatomic, strong) IBOutlet UIButton* shootButton;
@property (nonatomic, strong) IBOutlet UIButton* rotateCameraButton;
//@property (nonatomic, strong) IBOutlet UILabel* dictateLabel;

-(void) initSpeechRecognizer;
-(BOOL) startSpeechRecognizer;
-(void) stopSpeechRecognizer;
-(void) releaseSpeechRecognizer;

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
    self.movieSavePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:VideoDirectory] stringByAppendingPathComponent:fileName];
    //NSString* pathToMovie = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
    unlink([self.movieSavePath UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL* movieURL = [NSURL fileURLWithPath:self.movieSavePath];
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
        //[self.shootButton setTitle:@"Shooting..." forState:UIControlStateNormal];
        [self.shootButton setImage:[UIImage imageNamed:@"button_recording"] forState:UIControlStateNormal];
        _movieWriter.paused = NO;
        self.navItem.rightBarButtonItem.enabled = YES;
    }
    else
    {
        self.shootButton.tag = 0;
        //[self.shootButton setTitle:@"Shoot" forState:UIControlStateNormal];
        [self.shootButton setImage:[UIImage imageNamed:@"button_to_record"] forState:UIControlStateNormal];
        _movieWriter.paused = YES;
    }
}

-(IBAction)onRotateCameraButtonPressed:(id)sender {
    [_videoCamera rotateCamera];
}

-(void) dismissSelf {
    _movieWriter.paused = YES;
    [self stopSpeechRecognizer];
    
    UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"AbortVideoCapturing", @"Abort video capturing?") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", @"Confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self releaseSpeechRecognizer];
        [self stopAndReleaseMovieWriter];
        [_videoCamera stopCameraCapture];
        [[NSFileManager defaultManager] removeItemAtPath:self.movieSavePath error:nil];
        self.movieSavePath = nil;
        [self dismissViewControllerAnimated:YES completion:nil];
        if (self.completeHandler)
        {
            self.completeHandler(nil, nil);
        }
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (self.shootButton.tag == 1)
        {
            _movieWriter.paused = NO;
        }
        [self startSpeechRecognizer];
    }];
    [alertCtrl addAction:confirmAction];
    [alertCtrl addAction:cancelAction];
    [self showViewController:alertCtrl sender:self];
}

-(void) finishCapturing {
    [self stopSpeechRecognizer];
    [self releaseSpeechRecognizer];
    [self stopAndReleaseMovieWriter];
    [_videoCamera stopCameraCapture];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (self.completeHandler)
    {
        self.completeHandler(self.movieSavePath, self.speechRecognizerResultString);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIBarButtonItem* backButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(dismissSelf)];
    UIBarButtonItem* doneButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"confirm"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(finishCapturing)];
    self.navItem.leftBarButtonItem = backButtonItem;
    doneButtonItem.enabled = NO;
    self.navItem.rightBarButtonItem = doneButtonItem;
    self.navItem.title = @"";
    //*
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];
    //https://www.jianshu.com/p/fa27ab9fb172
    
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
    [self startSpeechRecognizer];
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
    NSString* mediaType = AVMediaTypeVideo;//读取媒体类型
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];//读取设备授权状态
    if (authStatus == AVAuthorizationStatusDenied)
    {
        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"PermissionDenied", @"PermissionDenied") message:NSLocalizedString(@"NeedCameraPermission", @"NeedCameraPermission") preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* actionOK = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                if (@available(iOS 10.0, *))
                {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                    }];
                }
                else
                {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }
            /*
             作者：MajorLMJ
             链接：https://www.jianshu.com/p/b44f309feca0
             來源：简书
             简书著作权归作者所有，任何形式的转载都请联系作者获得授权并注明出处。
             //*/
        }];
        [alertCtrl addAction:actionOK];
        UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self releaseSpeechRecognizer];
            [self stopAndReleaseMovieWriter];
            [_videoCamera stopCameraCapture];
            [[NSFileManager defaultManager] removeItemAtPath:self.movieSavePath error:nil];
            self.movieSavePath = nil;
            [self dismissViewControllerAnimated:YES completion:nil];
            if (self.completeHandler)
            {
                self.completeHandler(nil, nil);
            }
        }];
        [alertCtrl addAction:actionCancel];
        [self presentViewController:alertCtrl animated:NO completion:^{
            
        }];
    }
    else
    {
        authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];//读取设备授权状态
        if (authStatus == AVAuthorizationStatusDenied)
        {
            UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"PermissionDenied", @"PermissionDenied") message:NSLocalizedString(@"NeedMicPermission", @"NeedMicPermission") preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* actionOK = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if ([[UIApplication sharedApplication] canOpenURL:url])
                {
                    if (@available(iOS 10.0, *))
                    {
                        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                        }];
                    }
                    else
                    {
                        [[UIApplication sharedApplication] openURL:url];
                    }
                }
                /*
                 作者：MajorLMJ
                 链接：https://www.jianshu.com/p/b44f309feca0
                 來源：简书
                 简书著作权归作者所有，任何形式的转载都请联系作者获得授权并注明出处。
                 //*/
            }];
            [alertCtrl addAction:actionOK];
            UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            }];
            [alertCtrl addAction:actionCancel];
            [self presentViewController:alertCtrl animated:NO completion:^{
                
            }];
        }
    }
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
    
    _movieWriter.paused = YES;
}

-(UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
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
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.dictateLabel.text = self.speechRecognizerResultString;
//    });
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
