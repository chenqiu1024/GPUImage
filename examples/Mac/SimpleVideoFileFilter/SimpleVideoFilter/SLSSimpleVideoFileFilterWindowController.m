#import "SLSSimpleVideoFileFilterWindowController.h"
#import <GPUImage/GPUImage.h>

@interface SLSSimpleVideoFileFilterWindowController ()
{
    GPUImageMovie *movieFile;
    GPUImageOutput<GPUImageInput> *filter;
    GPUImageMovieWriter *movieWriter;
    NSTimer * timer;
}

@property (weak) IBOutlet GPUImageView *videoView;
@property (weak) IBOutlet NSTextField *progressLabel;

@property (weak) IBOutlet NSView *containerView;
@property (weak) IBOutlet NSButton *urlButton;
@property (weak) IBOutlet NSButton *avPlayerItemButton;

//@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;

@end

@implementation SLSSimpleVideoFileFilterWindowController


- (void)windowDidLoad {
    [super windowDidLoad];

    self.containerView.hidden = YES;

}

- (IBAction)gpuImageMovieWithURLButtonAction:(id)sender {
    [self runProcessingWithURL];
    [self showProcessingUI];
}

- (IBAction)gpuImageMovieWithAvplayeritemButtonAction:(id)sender {
    [self runProcessingWithAVPlayerItem];
    [self showProcessingUI];
}

- (void)showProcessingUI {
    self.containerView.hidden = NO;
    self.urlButton.hidden = YES;
    self.avPlayerItemButton.hidden = YES;
}

- (void)runProcessingWithAVPlayerItem {
//    NSURL *sampleURL = [[NSBundle mainBundle] URLForResource:@"sample_iPod" withExtension:@"m4v"];
    NSURL* sampleURL = [NSURL fileURLWithPath:@"/Users/domqiu/Movies/VID_20170220_182639AA.MP4"];
//    NSURL *sampleURL = [NSURL fileURLWithPath:@"/Users/qiudong/Movies/SampleMedias/Gyro/VID_20170823_094312AA.MP4"];
//    NSURL *sampleURL = [NSURL fileURLWithPath:@"/Users/qiudong/Movies/SampleMedias/TwirlingVRAudio/VID_20180806_185402AA.MP4"];
    
    AVPlayerItem* playerItem = [[AVPlayerItem alloc] initWithURL:sampleURL];
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    //movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    movieFile = [[GPUImageMovie alloc] initWithPlayerItem:playerItem];
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
    filter = [[GPUImagePixellateFilter alloc] init];
    //    filter = [[GPUImageUnsharpMaskFilter alloc] init];
    
    [movieFile addTarget:filter];
    
    // Only rotate the video for display, leave orientation the same for recording
    GPUImageView *filterView = (GPUImageView *)self.videoView;
    [filter addTarget:filterView];
    
    // In addition to displaying to the screen, write out a processed version of the movie to disk
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(3456, 1728)];
    [filter addTarget:movieWriter];
    
    // Configure this for video from the movie file, where we want to preserve all video frames and audio samples
    movieWriter.shouldPassthroughAudio = YES;
    movieFile.audioEncodingTarget = movieWriter;
    [movieFile enableSynchronizedEncodingUsingMovieWriter:movieWriter];
    
    [movieWriter startRecording];
    [movieFile startProcessing];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:0.3f
                                             target:self
                                           selector:@selector(retrievingProgress)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];

    [movieWriter setCompletionBlock:^{
        [filter removeTarget:movieWriter];
        [movieWriter finishRecording];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.progressLabel.stringValue = @"100%";
        });
    }];
    
    [self.player play];
}

- (void)retrievingProgress
{
    self.progressLabel.stringValue = [NSString stringWithFormat:@"%d%%", (int)(movieFile.progress * 100)];
}

- (IBAction)updatePixelWidth:(id)sender
{
    //    [(GPUImageUnsharpMaskFilter *)filter setIntensity:[(UISlider *)sender value]];
    [(GPUImagePixellateFilter *)filter setFractionalWidthOfAPixel:[(NSSlider *)sender floatValue]];
}

- (void)runProcessingWithURL {
    //    NSURL *sampleURL = [[NSBundle mainBundle] URLForResource:@"sample_iPod" withExtension:@"m4v"];
    NSURL* sampleURL = [NSURL fileURLWithPath:@"/Users/domqiu/Movies/VID_20170220_182639AA.MP4"];
    //    NSURL *sampleURL = [NSURL fileURLWithPath:@"/Users/qiudong/Movies/SampleMedias/Gyro/VID_20170823_094312AA.MP4"];
    //    NSURL *sampleURL = [NSURL fileURLWithPath:@"/Users/qiudong/Movies/SampleMedias/TwirlingVRAudio/VID_20180806_185402AA.MP4"];
    
    self.player = [AVPlayer playerWithURL:sampleURL];
    
    movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
    filter = [[GPUImagePixellateFilter alloc] init];
    //    filter = [[GPUImageUnsharpMaskFilter alloc] init];
    
    [movieFile addTarget:filter];
    
    // Only rotate the video for display, leave orientation the same for recording
    GPUImageView *filterView = (GPUImageView *)self.videoView;
    [filter addTarget:filterView];
    
    // In addition to displaying to the screen, write out a processed version of the movie to disk
    NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(640.0, 480.0)];
    [filter addTarget:movieWriter];
    
    // Configure this for video from the movie file, where we want to preserve all video frames and audio samples
    movieWriter.shouldPassthroughAudio = YES;
    movieFile.audioEncodingTarget = movieWriter;
    [movieFile enableSynchronizedEncodingUsingMovieWriter:movieWriter];
    
    [movieWriter startRecording];
    [movieFile startProcessing];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:0.3f
                                             target:self
                                           selector:@selector(retrievingProgress)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    
    [movieWriter setCompletionBlock:^{
        [filter removeTarget:movieWriter];
        [movieWriter finishRecording];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.progressLabel.stringValue = @"100%";
        });
    }];
    
    [self.player play];
}

@end
