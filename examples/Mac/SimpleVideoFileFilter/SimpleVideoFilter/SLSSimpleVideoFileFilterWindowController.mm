#import "SLSSimpleVideoFileFilterWindowController.h"
#import "MadvMP4BoxParser.hpp"
#import "MadvPanoGPUIRenderer.h"
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#import <GPUImage/GPUImage.h>
// TODO: 1.Filter out non-MADV medias; 2.Ignore ill rotation matrix; 3."Add files" and "Clear files" buttons and "Gyro Stablization" checkbox;
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
    
    NSString* _sourceFileURL;
    NSString* _destFileURL;
}

@property (weak) IBOutlet GPUImageView *videoView;
//@property (weak) IBOutlet NSTextField *progressLabel;
@property (weak) IBOutlet NSTextField* titleLabel;
@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

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
        NSString* ext = url.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"jpg"])
        {
            [self processJPEG:url completion:^(NSString* destPath) {
                [self processNextURL:iter];
            }];
        }
        else if ([ext isEqualToString:@"dng"])
        {
            [self processDNG:url completion:^(NSString* destPath) {
                [self processNextURL:iter];
            }];
        }
        else
        {
            [self runProcessingWithURL:url completion:^() {
                [self processNextURL:iter];
            }];
        }
        
        [self showProcessingUI];
    }
    else
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(onAllTranscodingDone:)])
        {
            [self.delegate onAllTranscodingDone:self];
        }
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
    NSString* movieName = [[[url lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_stitched.mp4"];
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
            self.progressIndicator.doubleValue = 1.0;
            
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
    self.progressIndicator.doubleValue = movieFile.progress;
    if (self.delegate && [self.delegate respondsToSelector:@selector(onTranscodingProgress:fileURL:)])
    {
        [self.delegate onTranscodingProgress:movieFile.progress fileURL:_sourceFileURL];
    }
}

- (IBAction)updatePixelWidth:(id)sender
{
    //    [(GPUImageUnsharpMaskFilter *)filter setIntensity:[(UISlider *)sender value]];
    [(GPUImagePixellateFilter *)filter setFractionalWidthOfAPixel:[(NSSlider *)sender floatValue]];
}

-(void) processDNG:(NSString*)sourcePath completion:(void(^)(NSString*))completion {
    GPUImageView* filterView = (GPUImageView*)self.videoView;
    GPUImagePicture* picture = [[GPUImagePicture alloc] initWithURL:[NSURL fileURLWithPath:sourcePath]];
    [picture addTarget:filterView];
    [picture processImage];
    
    NSString* documentDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString* destPath = [documentDirectory stringByAppendingPathComponent:[[sourcePath.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"_stitched.dng"]];
    NSString* tempLUTDirectory = makeTempLUTDirectory(sourcePath);
    
    TIFFHeader tiffHeader;
    std::list<std::list<DirectoryEntry> > IFDList;
    MadvEXIFExtension madvEXIFExt = readMadvEXIFExtensionFromRaw(sourcePath.UTF8String, &tiffHeader, IFDList);
    
    int64_t lutOffset = 0;
    if (madvEXIFExt.withEmbeddedLUT)
    {
        lutOffset = madvEXIFExt.embeddedLUTOffset;
        createDirectories(tempLUTDirectory.UTF8String);
        extractLUTFiles(tempLUTDirectory.UTF8String, sourcePath.UTF8String, (int32_t)lutOffset);
    }
    
    //            ALOGE("madvEXIFExt = {embeddedLUTOffset:%ld, width:%d, height:%d, sceneType:%x}, lutPath='%s'\n", (long)madvEXIFExt.embeddedLUTOffset, madvEXIFExt.width, madvEXIFExt.height, madvEXIFExt.sceneType, cstrLUTPath);
    
    XGLContext* glContext = new XGLContext(madvEXIFExt.width, madvEXIFExt.height, true, true, 3);
    glContext->makeCurrent();
    
    MVProgressClosure progressCallback;
    progressCallback.callback = NULL;
    progressCallback.context = NULL;
    /*/!!!For Debug:
     createFakeDNG(cstrDestPath, cstrSourcePath, 4, 4);
     /*/
    MadvGLRenderer::renderMadvRawToRaw(destPath.UTF8String, sourcePath.UTF8String,
                                       madvEXIFExt.width, madvEXIFExt.height,
                                       0 == madvEXIFExt.sceneType ? NULL : tempLUTDirectory.UTF8String,
                                       0, NULL,
                                       madvEXIFExt.cameraParams.gyroMatrix, (madvEXIFExt.gyroMatrixBytes > 0 ? 3 : 0), LONGITUDE_SEGMENTS, LATITUDE_SEGMENTS, progressCallback);
    //*/
    glContext->swapBuffers();
    XGLContext::makeNullCurrent();
    delete glContext;
    deleteIfTempLUTDirectory(tempLUTDirectory.UTF8String);
    
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:destPath];
    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(onTranscodingProgress:fileURL:)])
        {
            [self.delegate onTranscodingProgress:1.f fileURL:sourcePath];
        }
        if ([self.delegate respondsToSelector:@selector(onTranscodingDone:fileURL:)])
        {
            [self.delegate onTranscodingDone:image fileURL:sourcePath];
        }
    }
    
    [picture removeAllTargets];
    picture = [[GPUImagePicture alloc] initWithImage:image];
    [picture addTarget:filterView];
    [picture processImage];
    if (completion)
    {
        completion(destPath);
    }
}

-(void) processJPEG:(NSString*)sourcePath completion:(void(^)(NSString*))completion {
    //exifPrint(cstrSourcePath, std::cout);
    GPUImageView* filterView = (GPUImageView*)self.videoView;
    GPUImagePicture* picture = [[GPUImagePicture alloc] initWithURL:[NSURL fileURLWithPath:sourcePath]];
    [picture addTarget:filterView];
    [picture processImage];
    
    NSString* documentDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString* destPath = [documentDirectory stringByAppendingPathComponent:[[sourcePath.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"_stitched.jpg"]];
    NSString* tempLUTDirectory = makeTempLUTDirectory(sourcePath);
    
    jpeg_decompress_struct cinfo = readImageInfoFromJPEG(sourcePath.UTF8String);
    MadvEXIFExtension madvExifExt = readMadvEXIFExtensionFromJPEG(sourcePath.UTF8String);
    int64_t lutOffset = 0;
    if (madvExifExt.withEmbeddedLUT)
    {
        lutOffset = readLUTOffsetInJPEG(sourcePath.UTF8String);
        createDirectories(tempLUTDirectory.UTF8String);
        extractLUTFiles(tempLUTDirectory.UTF8String, sourcePath.UTF8String, (int32_t)lutOffset);
    }
    
    XGLContext* glContext = new XGLContext(cinfo.image_width, cinfo.image_height, true, true, 3);
    glContext->makeCurrent();
    
    int filterID = 0;
    MadvGLRenderer::renderMadvJPEGToJPEG(destPath.UTF8String,
                                         sourcePath.UTF8String,
                                         cinfo.image_width, cinfo.image_height,
                                         0 == madvExifExt.sceneType ? NULL : tempLUTDirectory.UTF8String,
                                         filterID, NULL,
                                         madvExifExt.cameraParams.gyroMatrix, (madvExifExt.gyroMatrixBytes > 0 ? 3 : 0),
                                         360, 180);
    glContext->swapBuffers();
    XGLContext::makeNullCurrent();
    delete glContext;
    deleteIfTempLUTDirectory(tempLUTDirectory.UTF8String);
    
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:destPath];
    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(onTranscodingProgress:fileURL:)])
        {
            [self.delegate onTranscodingProgress:1.f fileURL:sourcePath];
        }
        if ([self.delegate respondsToSelector:@selector(onTranscodingDone:fileURL:)])
        {
            [self.delegate onTranscodingDone:image fileURL:sourcePath];
        }
    }
    
    [picture removeAllTargets];
    picture = [[GPUImagePicture alloc] initWithImage:image];
    [picture addTarget:filterView];
    [picture processImage];
    if (completion)
    {
        completion(destPath);
    }
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
    
    if (filter)
    {
        [filter removeAllTargets];
    }
    movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    NSLog(@"#CRASH# Create movieFile=%@", movieFile);
    movieFile.runBenchmark = YES;
    movieFile.playAtActualSpeed = YES;
//    filter = [[GPUImagePixellateFilter alloc] init];
    //    filter = [[GPUImageUnsharpMaskFilter alloc] init];
    
    filter = [[MadvPanoGPUIRenderer alloc] initWithLUTPath:self.tempLUTDirectoryPath gyroData:_pBoxes->gyroData gyroDataFrames:(_pBoxes->gyroDataSize/36)];
    clearCachedLUT(self.tempLUTDirectoryPath.UTF8String);
    deleteIfTempLUTDirectory(self.tempLUTDirectoryPath.UTF8String);
    
    [movieFile addTarget:filter];
    
    // Only rotate the video for display, leave orientation the same for recording
    GPUImageView *filterView = (GPUImageView *)self.videoView;
    [filter addTarget:filterView];
    
    // In addition to displaying to the screen, write out a processed version of the movie to disk
    NSString* movieName = [[[url lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_stitched.mp4"];
    NSString* pathToMovie = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:movieName];
    unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    _sourceFileURL = url;
    self.titleLabel.stringValue = url;
    _destFileURL = pathToMovie;
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
        
        NSImage* thumbnail = getVideoImage(_destFileURL, 99.f, -1);
        dispatch_async(dispatch_get_main_queue(), ^{
            [timer invalidate];
            self.progressIndicator.doubleValue = 1.0;
            
            if (self.delegate)
            {
                if ([self.delegate respondsToSelector:@selector(onTranscodingProgress:fileURL:)])
                {
                    [self.delegate onTranscodingProgress:1.f fileURL:_sourceFileURL];
                }
                if ([self.delegate respondsToSelector:@selector(onTranscodingDone:fileURL:)])
                {
                    [self.delegate onTranscodingDone:thumbnail fileURL:_sourceFileURL];
                }
            }
            
            if (completion)
            {
                completion();
            }
        });
    }];
    
    [self.player play];
}

@end
