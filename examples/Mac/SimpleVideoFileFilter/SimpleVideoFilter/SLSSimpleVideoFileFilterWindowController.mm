#import "SLSSimpleVideoFileFilterWindowController.h"
#import "MadvMP4BoxParser.hpp"
#import "MadvPanoGPUIRenderer.h"
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#import <GPUImage/GPUImage.h>

NSArray<NSString* >* g_inputMP4Paths;

NSImage* getVideoImage(NSString* videoURL, int timeMillSeconds, int destMinSize)
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = NO;///!!!
    CMTime ctime = CMTimeMake(timeMillSeconds, 1000);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:ctime actualTime:&actualTime error:&error];
    if (error)
        NSLog(@"#Bug3763# getVideoImage(%d) error:%@", timeMillSeconds, error);
    size_t videoWidth = CGImageGetWidth(image);
    size_t videoHeight = CGImageGetHeight(image);
    NSSize destSize;
    if (destMinSize > 0)
    {
        if (videoHeight > videoWidth)
            destSize = NSMakeSize(destMinSize, (float)destMinSize * (float)videoHeight / (float)videoWidth);
        else
            destSize = NSMakeSize((float)destMinSize * (float)videoWidth / (float)videoHeight, destMinSize);
    }
    else
    {
        destSize = NSMakeSize(videoWidth, videoHeight);
    }
    NSImage* thumb = [[NSImage alloc] initWithCGImage:image size:destSize];
    CGImageRelease(image);
    return thumb;
}

@interface SLSSimpleVideoFileFilterWindowController ()
{
    GPUImageMovie *movieFile;
    GPUImageOutput<GPUImageInput> *filter;
    GPUImageMovieWriter *movieWriter;
    NSTimer * timer;
    MadvMP4Boxes* _pBoxes;
}

@property (weak) IBOutlet GPUImageView *videoView;
@property (weak) IBOutlet NSTextField *progressLabel;

@property (weak) IBOutlet NSView *containerView;
@property (weak) IBOutlet NSButton *urlButton;
@property (weak) IBOutlet NSButton *avPlayerItemButton;

//@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, copy) NSString* tempLUTDirectoryPath;

@end

@implementation SLSSimpleVideoFileFilterWindowController

-(void) dealloc {
    releaseMadvMP4Boxes(_pBoxes);
}

- (void)windowDidLoad {
    [super windowDidLoad];

    self.containerView.hidden = YES;
    
    NSEnumerator<NSString* >* iter = self.urlStrings.objectEnumerator;
    [self processNextURL:iter];
}

-(void) processNextURL:(NSEnumerator<NSString* >*)iter {
    NSString* url = [iter nextObject];
    if (url)
    {
        [self runProcessingWithURL:url completion:^() {
            [self processNextURL:iter];
        }];
        [self showProcessingUI];
    }
}

- (IBAction)gpuImageMovieWithURLButtonAction:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt: @"打开"];
    
    openPanel.allowedFileTypes = [NSArray arrayWithObjects: @"mp4", @"mov", @"avi", @"mkv", @"rmvb", nil];
    openPanel.allowsMultipleSelection = YES;
    openPanel.directoryURL = nil;

    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1)
        {
//            NSURL* fileUrl = [[openPanel URLs] objectAtIndex:0];
//            // 获取文件内容
//            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:fileUrl error:nil];
//            NSString *fileContext = [[NSString alloc] initWithData:fileHandle.readDataToEndOfFile encoding:NSUTF8StringEncoding];
//            
//            // 将 获取的数据传递给 ViewController 的 TextView
//            ViewController *mainViewController = (ViewController *)[self gainMainViewController].contentViewController;
//            mainViewController.showCodeTextView.string = fileContext;
            NSArray* urls = [openPanel URLs];
            NSMutableArray<NSString* >* urlStrings = [NSMutableArray new];
            for (NSURL* url in urls)
            {
                [urlStrings addObject:url.path];
            }
            NSEnumerator<NSString* >* iter = urlStrings.objectEnumerator;
            [self processNextURL:iter];
        }
    }];
//    NSEnumerator<NSString* >* iter = g_inputMP4Paths.objectEnumerator;
//    [self processNextURL:iter];
}

-(void) processNextAVPlayerItem:(NSEnumerator<NSString* >*)iter {
    NSString* url = [iter nextObject];
    if (url)
    {
        [self runProcessingWithAVPlayerItem:url completion:^() {
            [self processNextAVPlayerItem:iter];
        }];
        [self showProcessingUI];
    }
}

- (IBAction)gpuImageMovieWithAvplayeritemButtonAction:(id)sender {
    NSEnumerator<NSString* >* iter = g_inputMP4Paths.objectEnumerator;
    [self processNextAVPlayerItem:iter];
}

- (void)showProcessingUI {
    self.containerView.hidden = NO;
    self.urlButton.hidden = YES;
    self.avPlayerItemButton.hidden = YES;
}

- (void)runProcessingWithAVPlayerItem:(NSString*)url completion:(void(^)(void))completion {
    NSURL* sampleURL = [NSURL fileURLWithPath:url];
    
    AVPlayerItem* playerItem = [[AVPlayerItem alloc] initWithURL:sampleURL];
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    //movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    movieFile = [[GPUImageMovie alloc] initWithPlayerItem:playerItem];
    NSLog(@"#CRASH# Create movieFile=%@", movieFile);
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
//    filter = [[GPUImagePixellateFilter alloc] init];
    //    filter = [[GPUImageUnsharpMaskFilter alloc] init];
    filter = [[MadvPanoGPUIRenderer alloc] init];
    
    [movieFile addTarget:filter];
    
    // Only rotate the video for display, leave orientation the same for recording
    GPUImageView *filterView = (GPUImageView *)self.videoView;
    [filter addTarget:filterView];
    
    // In addition to displaying to the screen, write out a processed version of the movie to disk
    NSString* movieName = [[[url lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_stitched.m4v"];
    NSString* pathToMovie = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:movieName];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    NSImage* snapshot = getVideoImage(url, 99.f, -1);
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:snapshot.size];
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
            
            if (completion)
            {
                completion();
            }
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

- (void)runProcessingWithURL:(NSString*)url completion:(void(^)(void))completion {
    releaseMadvMP4Boxes(_pBoxes);
    _pBoxes = createMadvMP4Boxes(url.UTF8String);
    if (NULL == _pBoxes->lutData && completion)
    {
        completion();
        return;
    }
    self.tempLUTDirectoryPath = makeTempLUTDirectory(url);
    extractLUTFilesFromMem(self.tempLUTDirectoryPath.UTF8String, NULL, (const uint8_t*)_pBoxes->lutData);
    
    NSURL* sampleURL = [NSURL fileURLWithPath:url];
    self.player = [AVPlayer playerWithURL:sampleURL];
    
    movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    NSLog(@"#CRASH# Create movieFile=%@", movieFile);
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
//    filter = [[GPUImagePixellateFilter alloc] init];
    //    filter = [[GPUImageUnsharpMaskFilter alloc] init];
    if (filter) [filter removeAllTargets];
    filter = [[MadvPanoGPUIRenderer alloc] initWithLUTPath:self.tempLUTDirectoryPath gyroData:_pBoxes->gyroData gyroDataFrames:(_pBoxes->gyroDataSize/36)];
    clearCachedLUT(self.tempLUTDirectoryPath.UTF8String);
    deleteIfTempLUTDirectory(self.tempLUTDirectoryPath.UTF8String);
    
    [movieFile addTarget:filter];
    
    // Only rotate the video for display, leave orientation the same for recording
    GPUImageView *filterView = (GPUImageView *)self.videoView;
    [filter addTarget:filterView];
    
    // In addition to displaying to the screen, write out a processed version of the movie to disk
    NSString* movieName = [[[url lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_stitched.m4v"];
    NSString* pathToMovie = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:movieName];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
    NSImage* snapshot = getVideoImage(url, 99.f, -1);
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:snapshot.size];
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
        NSLog(@"completionBlock: movieWriter=0x%ld, movieFile=0x%ld, url='%@'", (long)movieWriter.hash, (long)movieFile.hash, url);
        [movieWriter finishRecording];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.progressLabel.stringValue = @"100%";
            
            if (completion)
            {
                completion();
            }
        });
    }];
    
    [self.player play];
}

@end
