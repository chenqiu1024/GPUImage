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

@interface CameraDictateViewController ()

@property (nonatomic, strong) GPUImageVideoCamera* videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter* movieWriter;
@property (nonatomic, strong) IFlySpeechRecognizer* speechRecognizer;

-(IBAction)onShootButtonPressed:(id)sender;

-(IBAction)onRotateCameraButtonPressed:(id)sender;

@property (nonatomic, strong) IBOutlet UIButton* shootButton;
@property (nonatomic, strong) IBOutlet UIButton* rotateCameraButton;
@property (nonatomic, strong) IBOutlet UILabel* dictateLabel;

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
    [_videoCamera rotateCamera];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.shootButton.tag = 0;
    
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
