#import "GPUImageMovieWriter.h"

#import "GPUImageContext.h"
#import "GLProgram.h"
#import "GPUImageFilter.h"

NSString *const kGPUImageColorSwizzlingFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate).bgra;
 }
);


@interface GPUImageMovieWriter ()
{
    GLuint movieFramebuffer, movieRenderbuffer;
    
    GLProgram *colorSwizzlingProgram;
    GLint colorSwizzlingPositionAttribute, colorSwizzlingTextureCoordinateAttribute;
    GLint colorSwizzlingInputTextureUniform;

    GPUImageFramebuffer *firstInputFramebuffer;
    
    BOOL discont0, discont1;
    CMTime startTime, previousFrameTime, previousAudioTime0, previousAudioTime1;
    CMTime audioOffsetTime0, audioOffsetTime1, videoOffsetTime;
    
    dispatch_queue_t audioQueue, videoQueue;
    BOOL audioEncoding0IsFinished, audioEncoding1IsFinished, videoEncodingIsFinished;

    BOOL isRecording;
}

// Movie recording
- (void)initializeMovieWithOutputSettings:(NSMutableDictionary *)outputSettings;

// Frame rendering
- (void)createDataFBO;
- (void)destroyDataFBO;
- (void)setFilterFBO;

- (void)renderAtInternalSizeUsingFramebuffer:(GPUImageFramebuffer *)inputFramebufferToUse;

@end

@implementation GPUImageMovieWriter

@synthesize hasAudioTrack = _hasAudioTrack;
@synthesize encodingLiveVideo = _encodingLiveVideo;
@synthesize shouldPassthroughAudio = _shouldPassthroughAudio;
@synthesize completionBlock;
@synthesize failureBlock;
@synthesize videoInputReadyCallback;
@synthesize audioInputReadyCallback;
@synthesize enabled;
@synthesize shouldInvalidateAudioSampleWhenDone = _shouldInvalidateAudioSampleWhenDone;
@synthesize paused = _paused;
@synthesize movieWriterContext = _movieWriterContext;

@synthesize delegate = _delegate;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize;
{
    return [self initWithMovieURL:newMovieURL size:newSize fileType:AVFileTypeQuickTimeMovie outputSettings:nil];
}

- (id)initWithMovieURL:(NSURL *)newMovieURL size:(CGSize)newSize fileType:(NSString *)newFileType outputSettings:(NSMutableDictionary *)outputSettings;
{
    if (!(self = [super init]))
    {
		return nil;
    }

    _shouldInvalidateAudioSampleWhenDone = NO;
    
    self.enabled = YES;
    alreadyFinishedRecording = NO;
    videoEncodingIsFinished = NO;
    audioEncoding0IsFinished = NO;
    audioEncoding1IsFinished = NO;

    discont0 = NO;
    discont1 = NO;
    videoSize = newSize;
    movieURL = newMovieURL;
    fileType = newFileType;
    startTime = kCMTimeInvalid;
    _encodingLiveVideo = [[outputSettings objectForKey:@"EncodingLiveVideo"] isKindOfClass:[NSNumber class]] ? [[outputSettings objectForKey:@"EncodingLiveVideo"] boolValue] : YES;
    previousFrameTime = kCMTimeNegativeInfinity;
    previousAudioTime0 = kCMTimeNegativeInfinity;
    previousAudioTime1 = kCMTimeNegativeInfinity;
    inputRotation = kGPUImageNoRotation;
    
    _movieWriterContext = [[GPUImageContext alloc] init];
    [_movieWriterContext useSharegroup:[[[GPUImageContext sharedImageProcessingContext] context] sharegroup]];

    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        [_movieWriterContext useAsCurrentContext];
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        }
        else
        {
            colorSwizzlingProgram = [_movieWriterContext programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageColorSwizzlingFragmentShaderString];
        }
        
        if (!colorSwizzlingProgram.initialized)
        {
            [colorSwizzlingProgram addAttribute:@"position"];
            [colorSwizzlingProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![colorSwizzlingProgram link])
            {
                NSString *progLog = [colorSwizzlingProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [colorSwizzlingProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [colorSwizzlingProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                colorSwizzlingProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }        
        
        colorSwizzlingPositionAttribute = [colorSwizzlingProgram attributeIndex:@"position"];
        colorSwizzlingTextureCoordinateAttribute = [colorSwizzlingProgram attributeIndex:@"inputTextureCoordinate"];
        colorSwizzlingInputTextureUniform = [colorSwizzlingProgram uniformIndex:@"inputImageTexture"];
        
        [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
        
        glEnableVertexAttribArray(colorSwizzlingPositionAttribute);
        glEnableVertexAttribArray(colorSwizzlingTextureCoordinateAttribute);
    });
        
    [self initializeMovieWithOutputSettings:outputSettings];

    return self;
}

- (void)dealloc;
{
    [self destroyDataFBO];

#if !OS_OBJECT_USE_OBJC
    if( audioQueue != NULL )
    {
        dispatch_release(audioQueue);
    }
    if( videoQueue != NULL )
    {
        dispatch_release(videoQueue);
    }
#endif
}

#pragma mark -
#pragma mark Movie recording

- (void)initializeMovieWithOutputSettings:(NSDictionary *)outputSettings;
{
    isRecording = NO;
    
    self.enabled = YES;
    NSError *error = nil;
    assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:fileType error:&error];
    if (error != nil)
    {
        NSLog(@"Error: %@", error);
        if (failureBlock) 
        {
            failureBlock(error);
        }
        else 
        {
            if(self.delegate && [self.delegate respondsToSelector:@selector(movieRecordingFailedWithError:)])
            {
                [self.delegate movieRecordingFailedWithError:error];
            }
        }
    }
    
    // Set this to make sure that a functional movie is produced, even if the recording is cut off mid-stream. Only the last second should be lost in that case.
    assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
    
    // use default output settings if none specified
    if (outputSettings == nil) 
    {
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
        [settings setObject:AVVideoCodecH264 forKey:AVVideoCodecKey];
        [settings setObject:[NSNumber numberWithInt:videoSize.width] forKey:AVVideoWidthKey];
        [settings setObject:[NSNumber numberWithInt:videoSize.height] forKey:AVVideoHeightKey];
        outputSettings = settings;
    }
    // custom output settings specified
    else 
    {
		__unused NSString *videoCodec = [outputSettings objectForKey:AVVideoCodecKey];
		__unused NSNumber *width = [outputSettings objectForKey:AVVideoWidthKey];
		__unused NSNumber *height = [outputSettings objectForKey:AVVideoHeightKey];
		
		NSAssert(videoCodec && width && height, @"OutputSettings is missing required parameters.");
        
        if( [outputSettings objectForKey:@"EncodingLiveVideo"] ) {
            NSMutableDictionary *tmp = [outputSettings mutableCopy];
            [tmp removeObjectForKey:@"EncodingLiveVideo"];
            outputSettings = tmp;
        }
    }
    
    /*
    NSDictionary *videoCleanApertureSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithInt:videoSize.width], AVVideoCleanApertureWidthKey,
                                                [NSNumber numberWithInt:videoSize.height], AVVideoCleanApertureHeightKey,
                                                [NSNumber numberWithInt:0], AVVideoCleanApertureHorizontalOffsetKey,
                                                [NSNumber numberWithInt:0], AVVideoCleanApertureVerticalOffsetKey,
                                                nil];

    NSDictionary *videoAspectRatioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInt:3], AVVideoPixelAspectRatioHorizontalSpacingKey,
                                              [NSNumber numberWithInt:3], AVVideoPixelAspectRatioVerticalSpacingKey,
                                              nil];

    NSMutableDictionary * compressionProperties = [[NSMutableDictionary alloc] init];
    [compressionProperties setObject:videoCleanApertureSettings forKey:AVVideoCleanApertureKey];
    [compressionProperties setObject:videoAspectRatioSettings forKey:AVVideoPixelAspectRatioKey];
    [compressionProperties setObject:[NSNumber numberWithInt: 2000000] forKey:AVVideoAverageBitRateKey];
    [compressionProperties setObject:[NSNumber numberWithInt: 16] forKey:AVVideoMaxKeyFrameIntervalKey];
    [compressionProperties setObject:AVVideoProfileLevelH264Main31 forKey:AVVideoProfileLevelKey];
    
    [outputSettings setObject:compressionProperties forKey:AVVideoCompressionPropertiesKey];
    */
     
    assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    
    // You need to use BGRA for the video in order to get realtime encoding. I use a color-swizzling shader to line up glReadPixels' normal RGBA output with the movie input's BGRA.
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                           [NSNumber numberWithInt:videoSize.width], kCVPixelBufferWidthKey,
                                                           [NSNumber numberWithInt:videoSize.height], kCVPixelBufferHeightKey,
                                                           nil];
//    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey,
//                                                           nil];
        
    assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assetWriterVideoInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    [assetWriter addInput:assetWriterVideoInput];
}

- (void)setEncodingLiveVideo:(BOOL) value
{
    _encodingLiveVideo = value;
    if (isRecording) {
        NSAssert(NO, @"Can not change Encoding Live Video while recording");
    }
    else
    {
        assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
        assetWriterAudioInput0.expectsMediaDataInRealTime = _encodingLiveVideo;
        assetWriterAudioInput1.expectsMediaDataInRealTime = _encodingLiveVideo;
    }
}

- (void)startRecording
{
    alreadyFinishedRecording = NO;
    startTime = kCMTimeInvalid;
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        if (audioInputReadyCallback == NULL)
        {
            [assetWriter startWriting];
        }
    });
    isRecording = YES;
//    [assetWriter startSessionAtSourceTime:kCMTimeZero];
}

- (void)startRecordingInOrientation:(CGAffineTransform)orientationTransform;
{
	assetWriterVideoInput.transform = orientationTransform;

	[self startRecording];
}

- (void)cancelRecording;
{
    if (assetWriter.status == AVAssetWriterStatusCompleted)
    {
        return;
    }
    
    isRecording = NO;
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        alreadyFinishedRecording = YES;

        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
        {
            videoEncodingIsFinished = YES;
            [assetWriterVideoInput markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncoding0IsFinished )
        {
            audioEncoding0IsFinished = YES;
            [assetWriterAudioInput0 markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncoding1IsFinished )
        {
            audioEncoding1IsFinished = YES;
            [assetWriterAudioInput1 markAsFinished];
        }
        [assetWriter cancelWriting];
    });
}

- (void)finishRecording;
{
    [self finishRecordingWithCompletionHandler:NULL];
}

- (void)finishRecordingWithCompletionHandler:(void (^)(void))handler;
{
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        isRecording = NO;
        
        if (assetWriter.status == AVAssetWriterStatusCompleted || assetWriter.status == AVAssetWriterStatusCancelled || assetWriter.status == AVAssetWriterStatusUnknown)
        {
            if (handler)
                runAsynchronouslyOnContextQueue(_movieWriterContext, handler);
            return;
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
        {
            videoEncodingIsFinished = YES;
            [assetWriterVideoInput markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncoding0IsFinished )
        {
            audioEncoding0IsFinished = YES;
            [assetWriterAudioInput0 markAsFinished];
        }
        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncoding1IsFinished )
        {
            audioEncoding1IsFinished = YES;
            [assetWriterAudioInput1 markAsFinished];
        }
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_6_0))
        // Not iOS 6 SDK
        [assetWriter finishWriting];
        if (handler)
            runAsynchronouslyOnContextQueue(_movieWriterContext,handler);
#else
        // iOS 6 SDK
        if ([assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)]) {
            // Running iOS 6
            [assetWriter finishWritingWithCompletionHandler:(handler ?: ^{ })];
        }
        else {
            // Not running iOS 6
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [assetWriter finishWriting];
#pragma clang diagnostic pop
            if (handler)
                runAsynchronouslyOnContextQueue(_movieWriterContext, handler);
        }
#endif
    });
}

- (void)processAudioBuffer0:(CMSampleBufferRef)audioBuffer;
{
    if (!isRecording || _paused)
    {
        return;
    }
    
//    if (_hasAudioTrack && CMTIME_IS_VALID(startTime))
    if (_hasAudioTrack)
    {
        CFRetain(audioBuffer);

        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
        if (audioOffsetTime0.value <= 0)
        {
            audioOffsetTime0 = currentSampleTime;
        }
        
        if (discont0) {
            discont0 = NO;
            
            CMTime current;
            if (audioOffsetTime0.value > 0) {
                current = CMTimeSubtract(currentSampleTime, audioOffsetTime0);
//                NSLog(@"#Timestamp# current = CMTimeSubtract(currentSampleTime, offsetTime);// currentSampleTime=%f, offsetTime=%f, current=%f", CMTimeGetSeconds(currentSampleTime), CMTimeGetSeconds(offsetTime), CMTimeGetSeconds(current));
            } else {
                current = currentSampleTime;
//                NSLog(@"#Timestamp# current = currentSampleTime;// currentSampleTime=%f, current=%f", CMTimeGetSeconds(currentSampleTime), CMTimeGetSeconds(current));
            }
            
            CMTime offset = CMTimeSubtract(current, previousAudioTime0);
            
            if (audioOffsetTime0.value == 0) {
                audioOffsetTime0 = offset;
//                NSLog(@"#Timestamp# offsetTime = offset; =%f", CMTimeGetSeconds(offset));
            } else {
//                NSLog(@"#Timestamp# offsetTime = CMTimeAdd(offsetTime, offset); offsetTime=%f, offset=%f, =%f", CMTimeGetSeconds(offsetTime), CMTimeGetSeconds(offset), CMTimeGetSeconds(CMTimeAdd(offsetTime, offset)));
                audioOffsetTime0 = CMTimeAdd(audioOffsetTime0, offset);
            }
        }
        
        if (audioOffsetTime0.value > 0) {
            CMSampleBufferRef tmpBufferRef = audioBuffer;
//            NSLog(@"#Timestamp# Before adjust, currentSampleTime=%f", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(audioBuffer)));
            audioBuffer = [self adjustTime:tmpBufferRef by:audioOffsetTime0];
//            NSLog(@"#Timestamp# After adjust, currentSampleTime=%f", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(audioBuffer)));
            CFRelease(tmpBufferRef);
        }
        // record most recent time so we know the length of the pause
        
        currentSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
        previousAudioTime0 = currentSampleTime;
        
        if (CMTIME_IS_INVALID(startTime))
        {
            runSynchronouslyOnContextQueue(_movieWriterContext, ^{
                if ((audioInputReadyCallback == NULL) && (assetWriter.status != AVAssetWriterStatusWriting))
                {
                    [assetWriter startWriting];
                }
                [assetWriter startSessionAtSourceTime:currentSampleTime];
                startTime = currentSampleTime;
                //                NSLog(@"#Timestamp# startTime = currentSampleTime = %f", CMTimeGetSeconds(startTime));
            });
        }
        
        if (!assetWriterAudioInput0.readyForMoreMediaData && _encodingLiveVideo)
        {
//            NSLog(@"#Timestamp# 1: Had to drop an audio frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
            return;
        }
        
//        NSLog(@"#Timestamp# previousAudioTime = currentSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer); =%f", CMTimeGetSeconds(previousAudioTime));
        //if the consumer wants to do something with the audio samples before writing, let him.
        if (self.audioProcessingCallback) {
            //need to introspect into the opaque CMBlockBuffer structure to find its raw sample buffers.
            CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(audioBuffer);
            CMItemCount numSamplesInBuffer = CMSampleBufferGetNumSamples(audioBuffer);
            AudioBufferList audioBufferList;
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioBuffer,
                                                                    NULL,
                                                                    &audioBufferList,
                                                                    sizeof(audioBufferList),
                                                                    NULL,
                                                                    NULL,
                                                                    kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                    &buffer
                                                                    );
            //passing a live pointer to the audio buffers, try to process them in-place or we might have syncing issues.
            for (int bufferCount=0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++) {
                SInt16 *samples = (SInt16 *)audioBufferList.mBuffers[bufferCount].mData;
                self.audioProcessingCallback(&samples, numSamplesInBuffer);
            }
        }
        
//        NSLog(@"Recorded audio sample time: %lld, %d, %lld", currentSampleTime.value, currentSampleTime.timescale, currentSampleTime.epoch);
        void(^write)() = ^() {
            while( ! assetWriterAudioInput0.readyForMoreMediaData && ! _encodingLiveVideo && ! audioEncoding0IsFinished ) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
                //NSLog(@"audio waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!assetWriterAudioInput0.readyForMoreMediaData)
            {
//                NSLog(@"#Timestamp# 2: Had to drop an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            else if(assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![assetWriterAudioInput0 appendSampleBuffer:audioBuffer])
                    NSLog(@"#Timestamp# Problem appending audio buffer at time: %f", CMTimeGetSeconds(currentSampleTime));
//                else
//                    NSLog(@"#Timestamp# Success appending audio buffer at time: %f", CMTimeGetSeconds(currentSampleTime));
            }
            else
            {
//                NSLog(@"#Timestamp# Wrote an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }

            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
        };
//        runAsynchronouslyOnContextQueue(_movieWriterContext, write);
        if( _encodingLiveVideo )
        {
//            NSLog(@"#Timestamp# 4 return, _encodingLiveVideo=%d", _encodingLiveVideo);
            runAsynchronouslyOnContextQueue(_movieWriterContext, write);
        }
        else
        {
            write();
        }
    }
    else
    {
//        NSLog(@"#Timestamp# No audio track");
    }
}

- (void)processAudioBuffer1:(CMSampleBufferRef)audioBuffer;
{
    if (!isRecording || _paused)
    {
        return;
    }
    
    //    if (_hasAudioTrack && CMTIME_IS_VALID(startTime))
    if (_hasAudioTrack)
    {
        CFRetain(audioBuffer);
        
        CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
        if (audioOffsetTime1.value <= 0)
        {
            audioOffsetTime1 = currentSampleTime;
        }
        
        if (discont1) {
            discont1 = NO;
            
            CMTime current;
            if (audioOffsetTime1.value > 0) {
                current = CMTimeSubtract(currentSampleTime, audioOffsetTime1);
                                NSLog(@"#Timestamp# current = CMTimeSubtract(currentSampleTime, offsetTime);// currentSampleTime=%f, offsetTime=%f, current=%f", CMTimeGetSeconds(currentSampleTime), CMTimeGetSeconds(audioOffsetTime1), CMTimeGetSeconds(current));
            } else {
                current = currentSampleTime;
                                NSLog(@"#Timestamp# current = currentSampleTime;// currentSampleTime=%f, current=%f", CMTimeGetSeconds(currentSampleTime), CMTimeGetSeconds(current));
            }
            
            CMTime offset = CMTimeSubtract(current, previousAudioTime1);
            
            if (audioOffsetTime1.value == 0) {
                audioOffsetTime1 = offset;
                                NSLog(@"#Timestamp# offsetTime = offset; =%f", CMTimeGetSeconds(offset));
            } else {
                                NSLog(@"#Timestamp# offsetTime = CMTimeAdd(offsetTime, offset); offsetTime=%f, offset=%f, =%f", CMTimeGetSeconds(audioOffsetTime1), CMTimeGetSeconds(offset), CMTimeGetSeconds(CMTimeAdd(audioOffsetTime1, offset)));
                audioOffsetTime1 = CMTimeAdd(audioOffsetTime1, offset);
            }
        }
        
        if (audioOffsetTime1.value > 0) {
            CMSampleBufferRef tmpBufferRef = audioBuffer;
                        NSLog(@"#Timestamp# Before adjust, currentSampleTime=%f", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(audioBuffer)));
            audioBuffer = [self adjustTime:tmpBufferRef by:audioOffsetTime1];
                        NSLog(@"#Timestamp# After adjust, currentSampleTime=%f", CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(audioBuffer)));
            CFRelease(tmpBufferRef);
        }
        // record most recent time so we know the length of the pause
        
        currentSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer);
        previousAudioTime1 = currentSampleTime;
        
        if (CMTIME_IS_INVALID(startTime))
        {
            runSynchronouslyOnContextQueue(_movieWriterContext, ^{
                if ((audioInputReadyCallback == NULL) && (assetWriter.status != AVAssetWriterStatusWriting))
                {
                    [assetWriter startWriting];
                }
                [assetWriter startSessionAtSourceTime:currentSampleTime];
                startTime = currentSampleTime;
                                NSLog(@"#Timestamp# startTime = currentSampleTime = %f", CMTimeGetSeconds(startTime));
            });
        }
        
        if (!assetWriterAudioInput1.readyForMoreMediaData && _encodingLiveVideo)
        {
                        NSLog(@"#Timestamp# 1: Had to drop an audio frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
            return;
        }
        
                NSLog(@"#Timestamp# previousAudioTime = currentSampleTime = CMSampleBufferGetPresentationTimeStamp(audioBuffer); =%f", CMTimeGetSeconds(previousAudioTime1));
        //if the consumer wants to do something with the audio samples before writing, let him.
        if (self.audioProcessingCallback) {
            //need to introspect into the opaque CMBlockBuffer structure to find its raw sample buffers.
            CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(audioBuffer);
            CMItemCount numSamplesInBuffer = CMSampleBufferGetNumSamples(audioBuffer);
            AudioBufferList audioBufferList;
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioBuffer,
                                                                    NULL,
                                                                    &audioBufferList,
                                                                    sizeof(audioBufferList),
                                                                    NULL,
                                                                    NULL,
                                                                    kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                    &buffer
                                                                    );
            //passing a live pointer to the audio buffers, try to process them in-place or we might have syncing issues.
            for (int bufferCount=0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++) {
                SInt16 *samples = (SInt16 *)audioBufferList.mBuffers[bufferCount].mData;
                self.audioProcessingCallback(&samples, numSamplesInBuffer);
            }
        }
        
        //        NSLog(@"Recorded audio sample time: %lld, %d, %lld", currentSampleTime.value, currentSampleTime.timescale, currentSampleTime.epoch);
        void(^write)() = ^() {
            while( ! assetWriterAudioInput1.readyForMoreMediaData && ! _encodingLiveVideo && ! audioEncoding1IsFinished ) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
                //NSLog(@"audio waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!assetWriterAudioInput1.readyForMoreMediaData)
            {
                //                NSLog(@"#Timestamp# 2: Had to drop an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            else if(assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![assetWriterAudioInput1 appendSampleBuffer:audioBuffer])
                    NSLog(@"#Timestamp# Problem appending audio buffer at time: %f", CMTimeGetSeconds(currentSampleTime));
                else
                    NSLog(@"#Timestamp# Success appending audio buffer at time: %f", CMTimeGetSeconds(currentSampleTime));
            }
            else
            {
                NSLog(@"#Timestamp# Wrote an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
            }
            
            if (_shouldInvalidateAudioSampleWhenDone)
            {
                CMSampleBufferInvalidate(audioBuffer);
            }
            CFRelease(audioBuffer);
        };
        //        runAsynchronouslyOnContextQueue(_movieWriterContext, write);
        if( _encodingLiveVideo )
        {
            NSLog(@"#Timestamp# 4 return, _encodingLiveVideo=%d", _encodingLiveVideo);
            runAsynchronouslyOnContextQueue(_movieWriterContext, write);
        }
        else
        {
            write();
        }
    }
    else
    {
                NSLog(@"#Timestamp# No audio track");
    }
}

- (void)enableSynchronizationCallbacks;
{
    if (videoInputReadyCallback != NULL)
    {
        if( assetWriter.status != AVAssetWriterStatusWriting )
        {
            [assetWriter startWriting];
        }
        videoQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.videoReadingQueue", GPUImageDefaultQueueAttribute());
        [assetWriterVideoInput requestMediaDataWhenReadyOnQueue:videoQueue usingBlock:^{
            if( _paused )
            {
                //NSLog(@"video requestMediaDataWhenReadyOnQueue paused");
                // if we don't sleep, we'll get called back almost immediately, chewing up CPU
                usleep(10000);
                return;
            }
            //NSLog(@"video requestMediaDataWhenReadyOnQueue begin");
            while( assetWriterVideoInput.readyForMoreMediaData && ! _paused )
            {
                if( videoInputReadyCallback && ! videoInputReadyCallback() && ! videoEncodingIsFinished )
                {
                    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
                        if( assetWriter.status == AVAssetWriterStatusWriting && ! videoEncodingIsFinished )
                        {
                            videoEncodingIsFinished = YES;
                            [assetWriterVideoInput markAsFinished];
                        }
                    });
                }
            }
            //NSLog(@"video requestMediaDataWhenReadyOnQueue end");
        }];
    }
    
    if (audioInputReadyCallback != NULL)
    {
        audioQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.audioReadingQueue", GPUImageDefaultQueueAttribute());
        [assetWriterAudioInput0 requestMediaDataWhenReadyOnQueue:audioQueue usingBlock:^{
            if( _paused )
            {
                //NSLog(@"audio requestMediaDataWhenReadyOnQueue paused");
                // if we don't sleep, we'll get called back almost immediately, chewing up CPU
                usleep(10000);
                return;
            }
            //NSLog(@"audio requestMediaDataWhenReadyOnQueue begin");
            while( assetWriterAudioInput0.readyForMoreMediaData && ! _paused )
            {
                if( audioInputReadyCallback && ! audioInputReadyCallback() && ! audioEncoding0IsFinished )
                {
                    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
                        if( assetWriter.status == AVAssetWriterStatusWriting && ! audioEncoding0IsFinished )
                        {
                            audioEncoding0IsFinished = YES;
                            [assetWriterAudioInput0 markAsFinished];
                        }
                    });
                }
            }
            //NSLog(@"audio requestMediaDataWhenReadyOnQueue end");
        }];
    }        
    
}

#pragma mark -
#pragma mark Frame rendering

- (void)createDataFBO;
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &movieFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        

        CVPixelBufferPoolCreatePixelBuffer (NULL, [assetWriterPixelBufferInput pixelBufferPool], &renderTarget);

        /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
         * regardless of the kCVImageBufferYCbCrMatrixKey value.
         * Tagging the resulting video file as BT.601, is the best option right now.
         * Creating a proper BT.709 video is not possible at the moment.
         */
        CVBufferSetAttachment(renderTarget, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
        CVBufferSetAttachment(renderTarget, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
        
        CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault, [_movieWriterContext coreVideoTextureCache], renderTarget,
                                                      NULL, // texture attributes
                                                      GL_TEXTURE_2D,
                                                      GL_RGBA, // opengl format
                                                      (int)videoSize.width,
                                                      (int)videoSize.height,
                                                      GL_BGRA, // native iOS format
                                                      GL_UNSIGNED_BYTE,
                                                      0,
                                                      &renderTexture);
        
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    }
    else
    {
        glGenRenderbuffers(1, &movieRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, movieRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (int)videoSize.width, (int)videoSize.height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, movieRenderbuffer);	
    }
    
	
	__unused GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
}

- (void)destroyDataFBO;
{
    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        [_movieWriterContext useAsCurrentContext];

        if (movieFramebuffer)
        {
            glDeleteFramebuffers(1, &movieFramebuffer);
            movieFramebuffer = 0;
        }
        
        if (movieRenderbuffer)
        {
            glDeleteRenderbuffers(1, &movieRenderbuffer);
            movieRenderbuffer = 0;
        }
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            if (renderTexture)
            {
                CFRelease(renderTexture);
            }
            if (renderTarget)
            {
                CVPixelBufferRelease(renderTarget);
            }
            
        }
    });
}

- (void)setFilterFBO;
{
    if (!movieFramebuffer)
    {
        [self createDataFBO];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, movieFramebuffer);
    
    glViewport(0, 0, (int)videoSize.width, (int)videoSize.height);
}

- (void)renderAtInternalSizeUsingFramebuffer:(GPUImageFramebuffer *)inputFramebufferToUse;
{
    [_movieWriterContext useAsCurrentContext];
    [self setFilterFBO];
    
    [_movieWriterContext setContextShaderProgram:colorSwizzlingProgram];
    
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // This needs to be flipped to write out to video correctly
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    const GLfloat *textureCoordinates = [GPUImageFilter textureCoordinatesForRotation:inputRotation];
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, [inputFramebufferToUse texture]);
	glUniform1i(colorSwizzlingInputTextureUniform, 4);
    
//    NSLog(@"Movie writer framebuffer: %@", inputFramebufferToUse);
    
    glVertexAttribPointer(colorSwizzlingPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(colorSwizzlingTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();
}

#pragma mark -
#pragma mark GPUImageInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    if (!isRecording || _paused)
    {
        [firstInputFramebuffer unlock];
        return;
    }

    if (CMTIME_IS_NEGATIVE_INFINITY(videoOffsetTime) || videoOffsetTime.value <= 0)
    {
        videoOffsetTime = frameTime;
    }
    
    if (discont0) {
        discont0 = NO;
        CMTime current;
        
        if (videoOffsetTime.value > 0) {
            current = CMTimeSubtract(frameTime, videoOffsetTime);
//            NSLog(@"#Timestamp# current = CMTimeSubtract(frameTime, videoOffsetTime);// frameTime=%f, videoOffsetTime=%f, current=%f", CMTimeGetSeconds(frameTime), CMTimeGetSeconds(videoOffsetTime), CMTimeGetSeconds(current));
        } else {
            current = frameTime;
//            NSLog(@"#Timestamp# current = frameTime;// frameTime=%f, current=%f", CMTimeGetSeconds(frameTime), CMTimeGetSeconds(current));
        }
        
        if (CMTIME_IS_NEGATIVE_INFINITY(previousFrameTime) || previousFrameTime.value < 0)
        {
            previousFrameTime = kCMTimeZero;
        }
        CMTime offset  = CMTimeSubtract(current, previousFrameTime);
//        NSLog(@"#Timestamp# CMTime offset  = CMTimeSubtract(current, previousFrameTime); offset=%f, current=%f, previousFrameTime=%f", CMTimeGetSeconds(offset), CMTimeGetSeconds(current), CMTimeGetSeconds(previousFrameTime));
        if (videoOffsetTime.value == 0) {
            videoOffsetTime = offset;
//            NSLog(@"#Timestamp# videoOffsetTime = offset; =%f", CMTimeGetSeconds(offset));
        } else {
//            NSLog(@"#Timestamp# videoOffsetTime = CMTimeAdd(videoOffsetTime, offset); videoOffsetTime=%f, offset=%f, =%f", CMTimeGetSeconds(videoOffsetTime), CMTimeGetSeconds(offset), CMTimeGetSeconds(CMTimeAdd(videoOffsetTime, offset)));
            videoOffsetTime = CMTimeAdd(videoOffsetTime, offset);
        }
    }
    
    if (videoOffsetTime.value > 0) {
//        NSLog(@"#Timestamp# frameTime = CMTimeSubtract(frameTime, videoOffsetTime); frameTime=%f, videoOffsetTime=%f, =%f", CMTimeGetSeconds(frameTime), CMTimeGetSeconds(videoOffsetTime), CMTimeGetSeconds(CMTimeSubtract(frameTime, videoOffsetTime)));
        frameTime = CMTimeSubtract(frameTime, videoOffsetTime);
    }
    
    // Drop frames forced by images and other things with no time constants
    // Also, if two consecutive times with the same value are added to the movie, it aborts recording, so I bail on that case
    if ( (CMTIME_IS_INVALID(frameTime)) || (CMTIME_COMPARE_INLINE(frameTime, ==, previousFrameTime)) || (CMTIME_IS_INDEFINITE(frameTime)) ) 
    {
        [firstInputFramebuffer unlock];
        return;
    }

    if (CMTIME_IS_INVALID(startTime))
    {
        runSynchronouslyOnContextQueue(_movieWriterContext, ^{
            if ((videoInputReadyCallback == NULL) && (assetWriter.status != AVAssetWriterStatusWriting))
            {
                [assetWriter startWriting];
            }
            
            [assetWriter startSessionAtSourceTime:frameTime];
            startTime = frameTime;
//            NSLog(@"#Timestamp# startTime = frameTime = %f", CMTimeGetSeconds(startTime));
        });
    }

    GPUImageFramebuffer *inputFramebufferForBlock = firstInputFramebuffer;
    glFinish();

    runAsynchronouslyOnContextQueue(_movieWriterContext, ^{
        if (!assetWriterVideoInput.readyForMoreMediaData && _encodingLiveVideo)
        {
            [inputFramebufferForBlock unlock];
//            NSLog(@"1: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            return;
        }
        
        // Render the frame with swizzled colors, so that they can be uploaded quickly as BGRA frames
        [_movieWriterContext useAsCurrentContext];
        [self renderAtInternalSizeUsingFramebuffer:inputFramebufferForBlock];
        
        CVPixelBufferRef pixel_buffer = NULL;
        
        if ([GPUImageContext supportsFastTextureUpload])
        {
            pixel_buffer = renderTarget;
            CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        }
        else
        {
            CVReturn status = CVPixelBufferPoolCreatePixelBuffer (NULL, [assetWriterPixelBufferInput pixelBufferPool], &pixel_buffer);
            if ((pixel_buffer == NULL) || (status != kCVReturnSuccess))
            {
                CVPixelBufferRelease(pixel_buffer);
                return;
            }
            else
            {
                CVPixelBufferLockBaseAddress(pixel_buffer, 0);
                
                GLubyte *pixelBufferData = (GLubyte *)CVPixelBufferGetBaseAddress(pixel_buffer);
                glReadPixels(0, 0, videoSize.width, videoSize.height, GL_RGBA, GL_UNSIGNED_BYTE, pixelBufferData);
            }
        }
        
        void(^write)() = ^() {
            while( ! assetWriterVideoInput.readyForMoreMediaData && ! _encodingLiveVideo && ! videoEncodingIsFinished ) {
                NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
                //            NSLog(@"video waiting...");
                [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
            }
            if (!assetWriterVideoInput.readyForMoreMediaData)
            {
                NSLog(@"2: Had to drop a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            else if(self.assetWriter.status == AVAssetWriterStatusWriting)
            {
                if (![assetWriterPixelBufferInput appendPixelBuffer:pixel_buffer withPresentationTime:frameTime])
                {
//                    NSLog(@"#Timestamp# Problem appending pixelBuffer at time:%f", CMTimeGetSeconds(frameTime));
                }
//                else
//                {
//                    NSLog(@"#Timestamp# Success appending pixelBuffer at time:%f", CMTimeGetSeconds(frameTime));
//                }
            }
            else
            {
                NSLog(@"Couldn't write a frame");
                //NSLog(@"Wrote a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, frameTime)));
            }
            CVPixelBufferUnlockBaseAddress(pixel_buffer, 0);
            
            previousFrameTime = frameTime;
//            NSLog(@"#Timestamp# previousFrameTime = frameTime; =%f", CMTimeGetSeconds(frameTime));
            if (![GPUImageContext supportsFastTextureUpload])
            {
                CVPixelBufferRelease(pixel_buffer);
            }
        };
        
        write();
        
        [inputFramebufferForBlock unlock];
    });
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    [newInputFramebuffer lock];
//    runSynchronouslyOnContextQueue(_movieWriterContext, ^{
        firstInputFramebuffer = newInputFramebuffer;
//    });
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
}

- (CGSize)maximumOutputSize;
{
    return videoSize;
}

- (void)endProcessing 
{
    if (completionBlock) 
    {
        if (!alreadyFinishedRecording)
        {
            alreadyFinishedRecording = YES;
            completionBlock();
        }        
    }
    else 
    {
        if (_delegate && [_delegate respondsToSelector:@selector(movieRecordingCompleted)])
        {
            [_delegate movieRecordingCompleted];
        }
    }
}

- (BOOL)shouldIgnoreUpdatesToThisTarget;
{
    return NO;
}

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
{
    
}

#pragma mark -
#pragma mark Accessors

- (void)setHasAudioTrack:(BOOL)newValue
{
	[self setHasAudioTrack:newValue audioSettings:nil];
}

- (void)setHasAudioTrack:(BOOL)newValue audioSettings:(NSDictionary *)audioOutputSettings0;
{
    _hasAudioTrack = newValue;
    
    if (_hasAudioTrack)
    {
        if (_shouldPassthroughAudio)
        {
			// Do not set any settings so audio will be the same as passthrough
			audioOutputSettings0 = nil;
        }
        else if (audioOutputSettings0 == nil)
        {
            AVAudioSession *sharedAudioSession = [AVAudioSession sharedInstance];
            [sharedAudioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
            double preferredHardwareSampleRate;
            
            if ([sharedAudioSession respondsToSelector:@selector(sampleRate)])
            {
                preferredHardwareSampleRate = [sharedAudioSession sampleRate];
            }
            else
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                preferredHardwareSampleRate = [[AVAudioSession sharedInstance] currentHardwareSampleRate];
#pragma clang diagnostic pop
            }
            
            AudioChannelLayout acl;
            bzero( &acl, sizeof(acl));
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
            
            audioOutputSettings0 = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                         [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                         [ NSNumber numberWithFloat: preferredHardwareSampleRate ], AVSampleRateKey,
                                         [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                         //[ NSNumber numberWithInt:AVAudioQualityLow], AVEncoderAudioQualityKey,
                                         [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                         nil];
/*
            AudioChannelLayout acl;
            bzero( &acl, sizeof(acl));
            acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
            
            audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                                   [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                   [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                                   [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                   [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                   nil];*/
        }
        
        AudioChannelLayout steroACL;
        bzero( &steroACL, sizeof(steroACL));
        steroACL.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        NSDictionary* audioOutputSettings1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                              [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
                                              [ NSNumber numberWithFloat: 16000 ], AVSampleRateKey,
                                              [ NSData dataWithBytes: &steroACL length: sizeof( steroACL ) ], AVChannelLayoutKey,
                                              //[ NSNumber numberWithInt:AVAudioQualityLow], AVEncoderAudioQualityKey,
                                              [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                              nil];
        
        assetWriterAudioInput0 = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings0];
        assetWriterAudioInput1 = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings1];
        [assetWriter addInput:assetWriterAudioInput0];
        [assetWriter addInput:assetWriterAudioInput1];
        assetWriterAudioInput0.expectsMediaDataInRealTime = _encodingLiveVideo;
        assetWriterAudioInput1.expectsMediaDataInRealTime = _encodingLiveVideo;
    }
    else
    {
        // Remove audio track if it exists
    }
}

- (NSArray*)metaData {
    return assetWriter.metadata;
}

- (void)setMetaData:(NSArray*)metaData {
    assetWriter.metadata = metaData;
}
 
- (CMTime)duration {
    if( ! CMTIME_IS_VALID(startTime) )
        return kCMTimeZero;
    if( ! CMTIME_IS_NEGATIVE_INFINITY(previousFrameTime) )
        return CMTimeSubtract(previousFrameTime, startTime);
    if( ! CMTIME_IS_NEGATIVE_INFINITY(previousAudioTime0) )
        return CMTimeSubtract(previousAudioTime0, startTime);
    if( ! CMTIME_IS_NEGATIVE_INFINITY(previousAudioTime1) )
        return CMTimeSubtract(previousAudioTime1, startTime);
    return kCMTimeZero;
}

- (CGAffineTransform)transform {
    return assetWriterVideoInput.transform;
}

- (void)setTransform:(CGAffineTransform)transform {
    assetWriterVideoInput.transform = transform;
}

- (AVAssetWriter*)assetWriter {
    return assetWriter;
}

- (void)setPaused:(BOOL)newValue {
    if (_paused != newValue) {
        _paused = newValue;
        
        if (_paused) {
            discont0 = YES;
            discont1 = YES;
        }
    }
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef) sample by:(CMTime) offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    
    return sout;
}

@end
