#import "GPUImageVideoCamera.h"
#import "GPUImageMovieWriter.h"
#import "GPUImageFilter.h"
#import "LogManager.h"

void setColorConversion601( GLfloat conversionMatrix[9] )
{
    kColorConversion601 = conversionMatrix;
}

void setColorConversion601FullRange( GLfloat conversionMatrix[9] )
{
    kColorConversion601FullRange = conversionMatrix;
}

void setColorConversion709( GLfloat conversionMatrix[9] )
{
    kColorConversion709 = conversionMatrix;
}

#pragma mark -
#pragma mark Private methods and instance variables

@interface GPUImageVideoCamera () 
{
	AVCaptureDeviceInput *audioInput;
	AVCaptureAudioDataOutput *audioOutput;
    NSDate *startingCaptureTime;
	
    dispatch_queue_t cameraProcessingQueue, audioProcessingQueue;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    GLint yuvConversionMatrixUniform;
    const GLfloat *_preferredConversion;
    
    BOOL isFullYUVRange;
    
    int imageBufferWidth, imageBufferHeight;
    
    BOOL addedAudioInputsDueToEncodingTarget;
}

- (void)updateOrientationSendToTargets;
- (void)convertYUVToRGBOutput;

@end

@implementation GPUImageVideoCamera

@synthesize captureSessionPreset = _captureSessionPreset;
@synthesize captureSession = _captureSession;
@synthesize inputCamera = _inputCamera;
@synthesize runBenchmark = _runBenchmark;
@synthesize outputImageOrientation = _outputImageOrientation;
@synthesize delegate = _delegate;
@synthesize horizontallyMirrorFrontFacingCamera = _horizontallyMirrorFrontFacingCamera, horizontallyMirrorRearFacingCamera = _horizontallyMirrorRearFacingCamera;
@synthesize frameRate = _frameRate;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init
{
    if (!(self = [self initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack]))
    {
		return nil;
    }
    
    return self;
}

- (id)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition; 
{
	if (!(self = [super init]))
    {
		return nil;
    }

    cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
	audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW,0);
    frameRenderingSemaphore = dispatch_semaphore_create(1);

	_frameRate = 0; // This will not set frame rate unless this value gets set to 1 or above
    _runBenchmark = NO;
    capturePaused = NO;
    outputRotation = kGPUImageNoRotation;
    internalRotation = kGPUImageNoRotation;
    captureAsYUV = YES;
    _preferredConversion = kColorConversion709;
    
	// Grab the back-facing or front-facing camera
    _inputCamera = nil;
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) 
	{
		if ([device position] == cameraPosition)
		{
			_inputCamera = device;
		}
	}
    
    if (!_inputCamera) {
        return nil;
    }
    
	// Create the capture session
	_captureSession = [[AVCaptureSession alloc] init];
	NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", (long)_captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession beginConfiguration];
    
	// Add the video input	
	NSError *error = nil;
	videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
	if ([_captureSession canAddInput:videoInput]) 
	{
		[_captureSession addInput:videoInput];
	}
    
	// Add the video frame output	
	videoOutput = [[AVCaptureVideoDataOutput alloc] init];
	[videoOutput setAlwaysDiscardsLateVideoFrames:NO];

//    if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
    if (captureAsYUV && [GPUImageContext supportsFastTextureUpload])
    {
        BOOL supportsFullYUVRange = NO;
        NSArray *supportedPixelFormats = videoOutput.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
            }
        }
        
        if (supportsFullYUVRange)
        {
            [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            isFullYUVRange = YES;
        }
        else
        {
            [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            isFullYUVRange = NO;
        }
    }
    else
    {
        [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    runSynchronouslyOnVideoProcessingQueue(^{
        
        if (captureAsYUV)
        {
            [GPUImageContext useImageProcessingContext];
            //            if ([GPUImageContext deviceSupportsRedTextures])
            //            {
            //                yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForRGFragmentShaderString];
            //            }
            //            else
            //            {
            if (isFullYUVRange)
            {
                yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
            }
            else
            {
                yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
            }

            //            }
            
            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
                
                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            
            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            yuvConversionMatrixUniform = [yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
            
            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
            
            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        }
    });
    
    [videoOutput setSampleBufferDelegate:self queue:cameraProcessingQueue];
	if ([_captureSession canAddOutput:videoOutput])
    {NSLog(@"#VideoCapture# GPUImageVideoCamera $ canAddVideoOutput(V):0x%lx by _captureSession:0x%lx,  in %s %s %d", videoOutput.hash, _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
        [_captureSession addOutput:videoOutput];
	}
	else
	{NSLog(@"#VideoCapture# GPUImageVideoCamera $ CANNOT addVideoOutput(V):0x%lx by _captureSession:0x%lx,  in %s %s %d", videoOutput.hash, _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
		NSLog(@"Couldn't add video output");
        return nil;
	}
    
	_captureSessionPreset = sessionPreset;
    [_captureSession setSessionPreset:_captureSessionPreset];

// This will let you get 60 FPS video from the 720p preset on an iPhone 4S, but only that device and that preset
//    AVCaptureConnection *conn = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
//    
//    if (conn.supportsVideoMinFrameDuration)
//        conn.videoMinFrameDuration = CMTimeMake(1,60);
//    if (conn.supportsVideoMaxFrameDuration)
//        conn.videoMaxFrameDuration = CMTimeMake(1,60);
    NSLog(@"#VideoCapture# GPUImageVideoCamera $ commitConfiguration after adding Video output in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession commitConfiguration];
    
	return self;
}

- (GPUImageFramebuffer *)framebufferForOutput;
{
    return outputFramebuffer;
}

- (void)dealloc 
{
    [self stopCameraCapture];
    [videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    
    [self removeInputsAndOutputs];
    
// ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
#if !OS_OBJECT_USE_OBJC
    if (frameRenderingSemaphore != NULL)
    {
        dispatch_release(frameRenderingSemaphore);
    }
#endif
}

- (BOOL)addAudioInputsAndOutputs
{
    if (audioOutput)
        return NO;
    NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession beginConfiguration];
    
    _microphone = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_microphone error:nil];
    if ([_captureSession canAddInput:audioInput])
    {
        [_captureSession addInput:audioInput];
    }
    audioOutput = [[AVCaptureAudioDataOutput alloc] init];

    if ([_captureSession canAddOutput:audioOutput])
    {NSLog(@"#VideoCapture# GPUImageVideoCamera $ canAddAudioOutput(A):0x%lx by _captureSession:0x%lx,  in %s %s %d", audioOutput.hash, _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
        [_captureSession addOutput:audioOutput];
    }
    else
    {NSLog(@"#VideoCapture# GPUImageVideoCamera $ CANNOT addAudioOutput(A):0x%lx by _captureSession:0x%lx,  in %s %s %d", audioOutput.hash, _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
        NSLog(@"Couldn't add audio output");
    }
    [audioOutput setSampleBufferDelegate:self queue:audioProcessingQueue];
    NSLog(@"#VideoCapture# GPUImageVideoCamera $ commitConfiguration after adding Audio output in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession commitConfiguration];
    return YES;
}

- (BOOL)removeAudioInputsAndOutputs
{
    if (!audioOutput)
        return NO;
    NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession beginConfiguration];
    [_captureSession removeInput:audioInput];
    [_captureSession removeOutput:audioOutput];
    audioInput = nil;
    audioOutput = nil;
    _microphone = nil;
    [_captureSession commitConfiguration];
    NSLog(@"#VideoCapture# _captureSession(0x%lx) commitConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    return YES;
}

- (void)removeInputsAndOutputs
{NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    [_captureSession beginConfiguration];
    if (videoInput) {
        [_captureSession removeInput:videoInput];
        [_captureSession removeOutput:videoOutput];
        videoInput = nil;
        videoOutput = nil;
    }
    if (_microphone != nil)
    {
        [_captureSession removeInput:audioInput];
        [_captureSession removeOutput:audioOutput];
        audioInput = nil;
        audioOutput = nil;
        _microphone = nil;
    }
    [_captureSession commitConfiguration];
    NSLog(@"#VideoCapture# _captureSession(0x%lx) commitConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
}

#pragma mark -
#pragma mark Managing targets

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    
    [newTarget setInputRotation:outputRotation atIndex:textureLocation];
}

#pragma mark -
#pragma mark Manage the camera video stream

- (BOOL)isRunning;
{
    return [_captureSession isRunning];
}

- (void)startCameraCapture;
{NSLog(@"#VideoCapture# GPUImageVideoCamera$startCameraCapture in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
    if (![_captureSession isRunning])
    {NSLog(@"#VideoCapture# GPUImageVideoCamera$startCameraCapture : startRunning in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
        startingCaptureTime = [NSDate date];
		[_captureSession startRunning];
	};
}

- (void)stopCameraCapture;
{NSLog(@"#VideoCapture# GPUImageVideoCamera$stopCameraCapture in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
    if ([_captureSession isRunning])
    {NSLog(@"#VideoCapture# GPUImageVideoCamera$stopCameraCapture : stopRunning in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
        [_captureSession stopRunning];
    }
}

- (void)pauseCameraCapture;
{
    capturePaused = YES;
}

- (void)resumeCameraCapture;
{
    capturePaused = NO;
}

- (void)rotateCamera
{
	if (self.frontFacingCameraPresent == NO)
		return;
	
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    AVCaptureDevicePosition currentCameraPosition = [[videoInput device] position];
    
    if (currentCameraPosition == AVCaptureDevicePositionBack)
    {
        currentCameraPosition = AVCaptureDevicePositionFront;
    }
    else
    {
        currentCameraPosition = AVCaptureDevicePositionBack;
    }
    
    AVCaptureDevice *backFacingCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *device in devices) 
	{
		if ([device position] == currentCameraPosition)
		{
			backFacingCamera = device;
		}
	}
    newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
    
    if (newVideoInput != nil)
    {NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:videoInput];
        if ([_captureSession canAddInput:newVideoInput])
        {
            [_captureSession addInput:newVideoInput];
            videoInput = newVideoInput;
        }
        else
        {
            [_captureSession addInput:videoInput];
        }
        //captureSession.sessionPreset = oriPreset;
        [_captureSession setSessionPreset:_captureSessionPreset];
        [_captureSession commitConfiguration];
        NSLog(@"#VideoCapture# _captureSession(0x%lx) commitConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
    }
    
    _inputCamera = backFacingCamera;
    [self setOutputImageOrientation:_outputImageOrientation];
}

- (AVCaptureDevicePosition)cameraPosition 
{
    return [[videoInput device] position];
}

+ (BOOL)isBackFacingCameraPresent;
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == AVCaptureDevicePositionBack)
			return YES;
	}
	
	return NO;
}

- (BOOL)isBackFacingCameraPresent
{
    return [GPUImageVideoCamera isBackFacingCameraPresent];
}

+ (BOOL)isFrontFacingCameraPresent;
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == AVCaptureDevicePositionFront)
			return YES;
	}
	
	return NO;
}

- (BOOL)isFrontFacingCameraPresent
{
    return [GPUImageVideoCamera isFrontFacingCameraPresent];
}

- (void)setCaptureSessionPreset:(NSString *)captureSessionPreset;
{NSLog(@"#VideoCapture# _captureSession(0x%lx) beginConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
	[_captureSession beginConfiguration];
	
	_captureSessionPreset = captureSessionPreset;
	[_captureSession setSessionPreset:_captureSessionPreset];
	
	[_captureSession commitConfiguration];
    NSLog(@"#VideoCapture# _captureSession(0x%lx) commitConfiguration in %s %s %d", _captureSession.hash, [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
}

- (void)setFrameRate:(int32_t)frameRate;
{
	_frameRate = frameRate;
	
	if (_frameRate > 0)
	{
		if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [_inputCamera lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [_inputCamera setActiveVideoMinFrameDuration:CMTimeMake(1, _frameRate)];
                [_inputCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, _frameRate)];
#endif
            }
            [_inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in videoOutput.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = CMTimeMake(1, _frameRate);
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = CMTimeMake(1, _frameRate);
#pragma clang diagnostic pop
            }
        }
        
	}
	else
	{
		if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [_inputCamera lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [_inputCamera setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [_inputCamera setActiveVideoMaxFrameDuration:kCMTimeInvalid];
#endif
            }
            [_inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in videoOutput.connections)
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
            }
        }
        
	}
}

- (int32_t)frameRate;
{
	return _frameRate;
}

- (AVCaptureConnection *)videoCaptureConnection {
    for (AVCaptureConnection *connection in [videoOutput connections] ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
				return connection;
			}
		}
	}
    
    return nil;
}

#define INITIALFRAMESTOIGNOREFORBENCHMARK 5

- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
{//NSLog(@"#Timestamp# GPUImageVideoCamera : New frame at %f", CMTimeGetSeconds(currentTime));
    // First, update all the framebuffers in the targets
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:textureIndexOfTarget];
                
                if ([currentTarget wantsMonochromeInput] && captureAsYUV)
                {
                    [currentTarget setCurrentlyReceivingMonochromeInput:YES];
                    // TODO: Replace optimization for monochrome output
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
                else
                {
                    [currentTarget setCurrentlyReceivingMonochromeInput:NO];
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
            }
            else
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            }
        }
    }
    
    // Then release our hold on the local framebuffer to send it back to the cache as soon as it's no longer needed
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
    
    // Finally, trigger rendering as needed
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
            }
        }
    }
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
    if (capturePaused)
    {
        return;
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
    CFTypeRef colorAttachments = CVBufferGetAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
            if (isFullYUVRange)
            {
                _preferredConversion = kColorConversion601FullRange;
            }
            else
            {
                _preferredConversion = kColorConversion601;
            }
        }
        else
        {
            _preferredConversion = kColorConversion709;
        }
    }
    else
    {
        if (isFullYUVRange)
        {
            _preferredConversion = kColorConversion601FullRange;
        }
        else
        {
            _preferredConversion = kColorConversion601;
        }
    }

	CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

    [GPUImageContext useImageProcessingContext];

    if ([GPUImageContext supportsFastTextureUpload] && captureAsYUV)
    {
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;

//        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (CVPixelBufferGetPlaneCount(cameraFrame) > 0) // Check for YUV planar inputs to do RGB conversion
        {
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            
            if ( (imageBufferWidth != bufferWidth) && (imageBufferHeight != bufferHeight) )
            {
                imageBufferWidth = bufferWidth;
                imageBufferHeight = bufferHeight;
            }
            
            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
//                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, cameraFrame, NULL, GL_TEXTURE_2D, GL_RED_EXT, bufferWidth, bufferHeight, GL_RED_EXT, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
//                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, coreVideoTextureCache, cameraFrame, NULL, GL_TEXTURE_2D, GL_RG_EXT, bufferWidth/2, bufferHeight/2, GL_RG_EXT, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
//            if (!allTargetsWantMonochromeData)
//            {
                [self convertYUVToRGBOutput];
//            }

            int rotatedImageBufferWidth = bufferWidth, rotatedImageBufferHeight = bufferHeight;
            
            if (GPUImageRotationSwapsWidthAndHeight(internalRotation))
            {
                rotatedImageBufferWidth = bufferHeight;
                rotatedImageBufferHeight = bufferWidth;
            }
            
            [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:rotatedImageBufferWidth height:rotatedImageBufferHeight time:currentTime];
            
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
        else
        {
            // TODO: Mesh this with the output framebuffer structure
            
//            CVPixelBufferLockBaseAddress(cameraFrame, 0);
//            
//            CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_RGBA, bufferWidth, bufferHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &texture);
//            
//            if (!texture || err) {
//                NSLog(@"Camera CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
//                NSAssert(NO, @"Camera failure");
//                return;
//            }
//            
//            outputTexture = CVOpenGLESTextureGetName(texture);
//            //        glBindTexture(CVOpenGLESTextureGetTarget(texture), outputTexture);
//            glBindTexture(GL_TEXTURE_2D, outputTexture);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//            
//            [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bufferWidth height:bufferHeight time:currentTime];
//
//            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
//            CFRelease(texture);
//
//            outputTexture = 0;
        }
        
        
        if (_runBenchmark)
        {
            numberOfFramesCaptured++;
            if (numberOfFramesCaptured > INITIALFRAMESTOIGNOREFORBENCHMARK)
            {
                CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
                totalFrameTimeDuringCapture += currentFrameTime;
                NSLog(@"Average frame time : %f ms", [self averageFrameDurationDuringCapture]);
                NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
            }
        }
    }
    else
    {
        CVPixelBufferLockBaseAddress(cameraFrame, 0);
        
        int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(cameraFrame);
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bytesPerRow / 4, bufferHeight) onlyTexture:YES];
        [outputFramebuffer activateFramebuffer];

        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        
        //        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
        
        // Using BGRA extension to pull in video frame data directly
        // The use of bytesPerRow / 4 accounts for a display glitch present in preview video frames when using the photo preset on the camera
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bytesPerRow / 4, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
        
        [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bytesPerRow / 4 height:bufferHeight time:currentTime];
        
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
        
        if (_runBenchmark)
        {
            numberOfFramesCaptured++;
            if (numberOfFramesCaptured > INITIALFRAMESTOIGNOREFORBENCHMARK)
            {
                CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
                totalFrameTimeDuringCapture += currentFrameTime;
            }
        }
    }  
}

+(void) printCMFormatDescription:(CMFormatDescriptionRef)format {
    CFTypeID typeID = CMFormatDescriptionGetTypeID();
    CFDictionaryRef extensions = CMFormatDescriptionGetExtensions(format);
    size_t formatListSize, layoutListSize;
    /*const AudioFormatListItem* formatList = */CMAudioFormatDescriptionGetFormatList(format, &formatListSize);
    /*const AudioStreamBasicDescription* asbd = */CMAudioFormatDescriptionGetStreamBasicDescription(format);
    const AudioChannelLayout* audioChannelLayoutList = CMAudioFormatDescriptionGetChannelLayout(format, &layoutListSize);
    NSLog(@"#AFD# type=%ld, formatList.size=%ld, channelLayout.size=%ld", (long)typeID, formatListSize, layoutListSize);
    NSLog(@"#AFD# extensions%@", NULL == extensions ? @" is NULL":[NSString stringWithFormat:@".size = %ld", CFDictionaryGetCount(extensions)]);
    NSLog(@"#AFD# audioChannelLayoutList.size = %ld", layoutListSize);
    for (int i=0; i<layoutListSize; ++i)
    {
        AudioChannelLayout audioChannelLayout = audioChannelLayoutList[i];
        NSLog(@"#AFD# ACL.channelBitmap = %d", (int)audioChannelLayout.mChannelBitmap);
        NSLog(@"#AFD# ACL.channelLayoutTag = 0x%lx", (long)audioChannelLayout.mChannelLayoutTag);
        NSLog(@"#AFD# ACL.channelDescriptions.size = %d", (int)audioChannelLayout.mNumberChannelDescriptions);
        for (int j=0; j<audioChannelLayout.mNumberChannelDescriptions; ++j)
        {
            AudioChannelDescription aclDesc = audioChannelLayout.mChannelDescriptions[j];
            NSLog(@"#AFD# ACL.channelDescriptions[%d].flags = 0x%x", j, aclDesc.mChannelFlags);
            NSLog(@"#AFD# ACL.channelDescriptions[%d].label = 0x%x", j, aclDesc.mChannelLabel);
            NSLog(@"#AFD# ACL.channelDescriptions[%d].coordinates = {%f,%f,%f}", j, aclDesc.mCoordinates[0], aclDesc.mCoordinates[1], aclDesc.mCoordinates[2]);
        }
    }
}

+(void) printCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription* asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    NSLog(@"#SampleBuffer# channels=%d, sampleRate=%f, duration=%f formatID=%d, bytesPerFrame=%d, framesPerPacket=%d, bytesPerPacket=%d", asbd->mChannelsPerFrame, asbd->mSampleRate, CMTimeGetSeconds(duration), asbd->mFormatID, asbd->mBytesPerFrame, asbd->mFramesPerPacket, asbd->mBytesPerPacket);
//    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
//    CMTime outputDuration = CMSampleBufferGetOutputDuration(sampleBuffer);
//    CMTime decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
//    CMTime outputDecodeTimeStamp = CMSampleBufferGetOutputDecodeTimeStamp(sampleBuffer);
//    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//    CMTime outputPresentationTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
//    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
//    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
//    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
//    CMItemCount numSamples = CMSampleBufferGetNumSamples(sampleBuffer);
//    size_t totalSampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer);
//    NSLog(@"#SampleBuffer# numSamples=%ld, totalSampleSize=%ld, duration=%.4f, outputDuration=%.4f, decodeTime=%.4f, outputDecodeTime=%.4f, presentTime=%.4f, outputPresentTime=%.4f", /*((char*)&mediaType)[0],((char*)&mediaType)[1],((char*)&mediaType)[2],((char*)&mediaType)[3], ((char*)&mediaSubType)[0],((char*)&mediaSubType)[1],((char*)&mediaSubType)[2],((char*)&mediaSubType)[3], */numSamples, totalSampleSize, CMTimeGetSeconds(duration), CMTimeGetSeconds(outputDuration), CMTimeGetSeconds(decodeTimeStamp), CMTimeGetSeconds(outputDecodeTimeStamp), CMTimeGetSeconds(presentationTimeStamp), CMTimeGetSeconds(outputPresentationTimeStamp));
//    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//    CMSampleBufferGetSampleTimingInfoArray(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemCount numSampleTimingEntries#>, <#CMSampleTimingInfo * _Nullable timingArrayOut#>, <#CMItemCount * _Nullable timingArrayEntriesNeededOut#>)
//    CMSampleBufferGetSampleTimingInfo(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemIndex sampleIndex#>, <#CMSampleTimingInfo * _Nonnull timingInfoOut#>)
//    CMSampleBufferGetOutputSampleTimingInfoArray(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemCount timingArrayEntries#>, <#CMSampleTimingInfo * _Nullable timingArrayOut#>, <#CMItemCount * _Nullable timingArrayEntriesNeededOut#>)
//    CMSampleBufferGetSampleSizeArray(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemCount sizeArrayEntries#>, <#size_t * _Nullable sizeArrayOut#>, <#CMItemCount * _Nullable sizeArrayEntriesNeededOut#>)
//    CMSampleBufferGetSampleSize(<#CMSampleBufferRef  _Nonnull sbuf#>, <#CMItemIndex sampleIndex#>)
//    CMSampleBufferGetAudioStreamPacketDescriptions(<#CMSampleBufferRef  _Nonnull sbuf#>, <#size_t packetDescriptionsSize#>, <#AudioStreamPacketDescription * _Nullable packetDescriptionsOut#>, <#size_t * _Nullable packetDescriptionsSizeNeededOut#>)
//    CMSampleBufferGetAudioStreamPacketDescriptionsPtr(<#CMSampleBufferRef  _Nonnull sbuf#>, <#const AudioStreamPacketDescription * _Nullable * _Nullable packetDescriptionsPtrOut#>, <#size_t * _Nullable packetDescriptionsSizeOut#>)
//    CMSampleBufferGetSampleAttachmentsArray(<#CMSampleBufferRef  _Nonnull sbuf#>, <#Boolean createIfNecessary#>)
//    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(<#CMSampleBufferRef  _Nonnull sbuf#>, <#size_t * _Nullable bufferListSizeNeededOut#>, <#AudioBufferList * _Nullable bufferListOut#>, <#size_t bufferListSize#>, <#CFAllocatorRef  _Nullable blockBufferStructureAllocator#>, <#CFAllocatorRef  _Nullable blockBufferBlockAllocator#>, <#uint32_t flags#>, <#CMBlockBufferRef  _Nullable * _Nullable blockBufferOut#>)
}

+(CMSampleBufferRef) copyCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMSampleBufferRef copy = NULL;
    
    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
//    CMTime outputDuration = CMSampleBufferGetOutputDuration(sampleBuffer);
    CMTime decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
//    CMTime outputDecodeTimeStamp = CMSampleBufferGetOutputDecodeTimeStamp(sampleBuffer);
    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//    CMTime outputPresentationTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer);
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
//    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
//    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription);
    CMItemCount numSamples = CMSampleBufferGetNumSamples(sampleBuffer);
    size_t totalSampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer);
    
    CMSampleTimingInfo timing;
    timing.duration = duration;
    timing.duration.timescale *= numSamples;
    timing.presentationTimeStamp = presentationTimeStamp;
    timing.decodeTimeStamp = decodeTimeStamp;
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t dataSize = CMBlockBufferGetDataLength(blockBuffer);
    void* data = malloc(dataSize);
    CMBlockBufferCopyDataBytes(blockBuffer, 0, dataSize, data);
    CMBlockBufferRef blockBufferCopy;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, data, totalSampleSize, kCFAllocatorNull, NULL, 0, totalSampleSize, 0, &blockBufferCopy);
//    NSLog(@"#SampleBuffer# dataSize=%ld, sizeOfSourceBlock=%ld, sizeOfCopiedBlock=%ld", (long)dataSize, CMBlockBufferGetDataLength(blockBuffer), CMBlockBufferGetDataLength(blockBufferCopy));
//    free(data);
    
    const size_t sampleSizeArray[] = {2};
    CMSampleBufferCreateReady(kCFAllocatorDefault, blockBufferCopy, formatDescription, numSamples, 1, &timing, 1, sampleSizeArray, &copy);
    return copy;
//    NSLog(@"#SampleBuffer# mediaType=%c%c%c%c:%c%c%c%c, numSamples=%ld, totalSampleSize=%ld, duration=%f, outputDuration=%f, decodeTime=%f, outputDecodeTime=%f, presentTime=%f, outputPresentTime=%f", ((char*)&mediaType)[0],((char*)&mediaType)[1],((char*)&mediaType)[2],((char*)&mediaType)[3], ((char*)&mediaSubType)[0],((char*)&mediaSubType)[1],((char*)&mediaSubType)[2],((char*)&mediaSubType)[3], numSamples, totalSampleSize, CMTimeGetSeconds(duration), CMTimeGetSeconds(outputDuration), CMTimeGetSeconds(decodeTimeStamp), CMTimeGetSeconds(outputDecodeTimeStamp), CMTimeGetSeconds(presentationTimeStamp), CMTimeGetSeconds(outputPresentationTimeStamp));
}

+(CMSampleBufferRef) createForgedCMSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMTime duration;
//    static NSDate* prevTimeStamp = nil;
//    if (prevTimeStamp)
//    {
//        NSDate* now = [NSDate date];
//        duration = CMTimeMake([now timeIntervalSinceDate:prevTimeStamp] * 1000, 1000);
//    }
//    else
//    {
//        prevTimeStamp = [NSDate date];
//        return NULL;
//    }
    duration = CMSampleBufferGetDuration(sampleBuffer);
    AudioStreamBasicDescription* audioStreamBasicDescription = (AudioStreamBasicDescription*) CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
    int numChannels = 2;
    double sampleRate = 44100.0;
    audioStreamBasicDescription->mSampleRate = sampleRate;
    audioStreamBasicDescription->mBytesPerFrame *= (numChannels / audioStreamBasicDescription->mChannelsPerFrame);
    audioStreamBasicDescription->mBytesPerPacket *= (numChannels / audioStreamBasicDescription->mChannelsPerFrame);
    audioStreamBasicDescription->mChannelsPerFrame = numChannels;
    
    CMFormatDescriptionRef formatDescriptionCopy;
    CMAudioFormatDescriptionCreate(kCFAllocatorDefault, audioStreamBasicDescription, 0, nil, 0, nil, NULL, &formatDescriptionCopy);
    CMItemCount numSamples = audioStreamBasicDescription->mSampleRate * CMTimeGetSeconds(duration);
    CMTime presentationTimeStamp = CMTimeMake((int64_t)[[NSDate date] timeIntervalSince1970], 1);
    size_t totalSampleSize = numSamples * sizeof(int16_t) * numChannels;
    
    CMSampleTimingInfo timing;
    timing.duration = duration;
    timing.duration.timescale *= numSamples;
    timing.presentationTimeStamp = presentationTimeStamp;
    timing.decodeTimeStamp = kCMTimeInvalid;
    
    int16_t* data = (int16_t*) malloc(totalSampleSize);
    /*
    const float Frequencies[] = {530, 450};
    static size_t samplesCount = 0;
    for (int i=0; i<numSamples; ++i)
    {
        for (int c=0; c<numChannels; c++)
        {
            float phase = 2.0f * M_PI * samplesCount * Frequencies[c] / audioStreamBasicDescription->mSampleRate;
            int16_t amplitude = (int16_t)(sinf(phase) * 16384);
            data[numChannels * i + c] = amplitude;
        }
        samplesCount++;
    }
    /*/
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t dataSize = CMBlockBufferGetDataLength(blockBuffer);
    CMBlockBufferCopyDataBytes(blockBuffer, 0, totalSampleSize < dataSize ? totalSampleSize : dataSize, data);
    //*/
    CMBlockBufferRef blockBufferCopy;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, data, totalSampleSize, kCFAllocatorNull, NULL, 0, totalSampleSize, 0, &blockBufferCopy);
    
    const size_t sampleSizeArray[] = {2};
    CMSampleBufferRef copy = NULL;
    CMSampleBufferCreateReady(kCFAllocatorDefault, blockBufferCopy, formatDescriptionCopy, numSamples, 1, &timing, 1, sampleSizeArray, &copy);
    return copy;
}

- (void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
//    [self.class printCMSampleBuffer:sampleBuffer];
//    CMSampleBufferRef copied = [self.class copyCMSampleBuffer:sampleBuffer];
//    CMSampleBufferRef copied = [self.class createForgedCMSampleBuffer:sampleBuffer];
//    [self.class printCMSampleBuffer:copied];

//    [self.audioEncodingTarget processAudioBuffer0:sampleBuffer];
//    [self.audioEncodingTarget processAudioBuffer0:copied];
//    CFRelease(copied);
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];

    int rotatedImageBufferWidth = imageBufferWidth, rotatedImageBufferHeight = imageBufferHeight;

    if (GPUImageRotationSwapsWidthAndHeight(internalRotation))
    {
        rotatedImageBufferWidth = imageBufferHeight;
        rotatedImageBufferHeight = imageBufferWidth;
    }

    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(rotatedImageBufferWidth, rotatedImageBufferHeight) textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_2D, luminanceTexture);
	glUniform1i(yuvConversionLuminanceTextureUniform, 4);

    glActiveTexture(GL_TEXTURE5);
	glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
	glUniform1i(yuvConversionChrominanceTextureUniform, 5);

    glUniformMatrix3fv(yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);

    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
	glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:internalRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark -
#pragma mark Benchmarking

- (CGFloat)averageFrameDurationDuringCapture;
{
    return (totalFrameTimeDuringCapture / (CGFloat)(numberOfFramesCaptured - INITIALFRAMESTOIGNOREFORBENCHMARK)) * 1000.0;
}

- (void)resetBenchmarkAverage;
{
    numberOfFramesCaptured = 0;
    totalFrameTimeDuringCapture = 0.0;
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (captureOutput != audioOutput)
    {
//        NSLog(@"#VideoCapture# GPUImageVideoCamera $ captureOutput in %s %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent.UTF8String, __PRETTY_FUNCTION__, __LINE__);
        //DoctorLog(@"#.#");
    }
    if (!self.captureSession.isRunning)
    {DoctorLog(@"#VideoCapture# GPUImageVideoCamera$captureOutput return#0 in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    else if (captureOutput == audioOutput)
    {
        [self processAudioSampleBuffer:sampleBuffer];
    }
    else
    {
        if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
        {DoctorLog(@"#VideoCapture# GPUImageVideoCamera$captureOutput return#1 in %@ %s %d", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __FUNCTION__, __LINE__);
            return;
        }
        
        CMSampleBufferRef copiedSampleBuffer = NULL;
        OSStatus result = CMSampleBufferCreateCopy(kCFAllocatorDefault, sampleBuffer, &copiedSampleBuffer);
        if (noErr == result && NULL != copiedSampleBuffer)
        {
            runAsynchronouslyOnVideoProcessingQueue(^{
                //Feature Detection Hook.
                if (self.delegate)
                {
                    [self.delegate willOutputSampleBuffer:copiedSampleBuffer];
                }
                
                [self processVideoSampleBuffer:copiedSampleBuffer];
                
                CFRelease(copiedSampleBuffer);
                dispatch_semaphore_signal(frameRenderingSemaphore);
            });
        }
    }
}

#pragma mark -
#pragma mark Accessors

- (void)setAudioEncodingTarget:(GPUImageMovieWriter *)newValue;
{
    if (newValue) {
        /* Add audio inputs and outputs, if necessary */
        addedAudioInputsDueToEncodingTarget |= [self addAudioInputsAndOutputs];
    } else if (addedAudioInputsDueToEncodingTarget) {
        /* Remove audio inputs and outputs, if they were added by previously setting the audio encoding target */
        [self removeAudioInputsAndOutputs];
        addedAudioInputsDueToEncodingTarget = NO;
    }

    [super setAudioEncodingTarget:newValue];
}

- (void)updateOrientationSendToTargets;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        
        //    From the iOS 5.0 release notes:
        //    In previous iOS versions, the front-facing camera would always deliver buffers in AVCaptureVideoOrientationLandscapeLeft and the back-facing camera would always deliver buffers in AVCaptureVideoOrientationLandscapeRight.
        
        if (captureAsYUV && [GPUImageContext supportsFastTextureUpload])
        {
            outputRotation = kGPUImageNoRotation;
            if ([self cameraPosition] == AVCaptureDevicePositionBack)
            {
                if (_horizontallyMirrorRearFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kGPUImageRotateRightFlipVertical;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kGPUImageFlipHorizonal;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kGPUImageFlipVertical;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
                else
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kGPUImageRotateRight;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kGPUImageRotateLeft;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
            }
            else
            {
                if (_horizontallyMirrorFrontFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kGPUImageRotateRightFlipVertical;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kGPUImageRotateRightFlipHorizontal;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kGPUImageFlipHorizonal;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kGPUImageFlipVertical;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                   }
                }
                else
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:internalRotation = kGPUImageRotateRight;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:internalRotation = kGPUImageRotateLeft;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:internalRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:internalRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# internalRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
            }
        }
        else
        {
            if ([self cameraPosition] == AVCaptureDevicePositionBack)
            {
                if (_horizontallyMirrorRearFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kGPUImageRotateRightFlipVertical;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kGPUImageFlipHorizonal;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kGPUImageFlipVertical;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
                else
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kGPUImageRotateRight;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kGPUImageRotateLeft;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
            }
            else
            {
                if (_horizontallyMirrorFrontFacingCamera)
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kGPUImageRotateRightFlipVertical;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kGPUImageRotateRightFlipHorizontal;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kGPUImageFlipHorizonal;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kGPUImageFlipVertical;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
                else
                {
                    switch(_outputImageOrientation)
                    {
                        case UIInterfaceOrientationPortrait:outputRotation = kGPUImageRotateRight;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationPortraitUpsideDown:outputRotation = kGPUImageRotateLeft;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeLeft:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        case UIInterfaceOrientationLandscapeRight:outputRotation = kGPUImageRotate180;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                            break;
                        default:outputRotation = kGPUImageNoRotation;
                            NSLog(@"#Rotation# outputRotation=%s . at %d in %s", GPUImageRotationModeStr(internalRotation), __LINE__, __PRETTY_FUNCTION__);
                    }
                }
            }
        }
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            [currentTarget setInputRotation:outputRotation atIndex:[[targetTextureIndices objectAtIndex:indexOfObject] integerValue]];
        }
    });
}

- (void)setOutputImageOrientation:(UIInterfaceOrientation)newValue;
{
    _outputImageOrientation = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorFrontFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorFrontFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorRearFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorRearFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}

@end
