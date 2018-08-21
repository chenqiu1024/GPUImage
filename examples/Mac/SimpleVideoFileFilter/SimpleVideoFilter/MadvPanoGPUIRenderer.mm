#import "MadvPanoGPUIRenderer.h"
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#import <AVFoundation/AVFoundation.h>

BOOL getGyroMatrix(float* pMatrix, NSInteger frameNumber, void* gyroData) {
    @try
    {
        if (!gyroData)
            return NO;
        
        NSInteger iSrcByte = frameNumber * 36;
        Byte* bytes = (Byte*)gyroData;
        for (int j=0; j<9; ++j)
        {
            int b0 = bytes[iSrcByte++];
            int b1 = bytes[iSrcByte++];
            int b2 = bytes[iSrcByte++];
            int b3 = bytes[iSrcByte++];
            int intValue = (b0 & 0xff) | ((b1 & 0xff) << 8) | ((b2 & 0xff) << 16) | ((b3 & 0xff) << 24);
            pMatrix[j] = *((float*) (int*) &intValue);
        }
        //NSLog(@"getGyroMatrix : frame#%d {%.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f}", (int)frameNumber, pMatrix[0],pMatrix[1],pMatrix[2],pMatrix[3],pMatrix[4],pMatrix[5],pMatrix[6],pMatrix[7],pMatrix[8]);
        return YES;
    }
    @catch (id ex)
    {
        return NO;
    }
    @finally
    {
    }
}

@interface MadvPanoGPUIRenderer ()
{
    AutoRef<MadvGLRenderer> _renderer;
//    AutoRef<PanoCameraController> _panoController;
//    AutoRef<GLCamera> _glCamera;
    void* _gyroData;
    int _gyroDataFrames;
}
@end

@implementation MadvPanoGPUIRenderer

#pragma mark -
#pragma mark Initialization and teardown

-(id)initWithLUTPath:(NSString*)lutPath gyroData:(void*)gyroData gyroDataFrames:(int)gyroDataFrames
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _gyroData = gyroData;
    _gyroDataFrames = gyroDataFrames;
    
    imageCaptureSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_signal(imageCaptureSemaphore);
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        Vec2f lutSourceSize = { DEFAULT_LUT_VALUE_WIDTH, DEFAULT_LUT_VALUE_HEIGHT };
        _renderer = new MadvGLRenderer(lutPath.UTF8String, lutSourceSize, lutSourceSize, 180, 90);
//        _panoController = new PanoCameraController(_renderer);
//        _glCamera = _renderer->glCamera();
        _renderer->setIsYUVColorSpace(false);
        kmMat4 sourceTextureMatrix;
        float sourceTextureMatrixData[] = {
            1.f, 0.f, 0.f, 0.f,
            0.f, -1.f, 0.f, 0.f,
            0.f, 0.f, 1.f, 0.f,
            0.f, 1.f, 0.f, 1.f,
        };
        kmMat4Fill(&sourceTextureMatrix, sourceTextureMatrixData);
        _renderer->setTextureMatrix(&sourceTextureMatrix);
        _renderer->setFlipY(true);
    });
    
    return self;
}

- (void)dealloc
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        _renderer = NULL;
//        _panoController = NULL;
//        _glCamera = NULL;
    });
    
#if !OS_OBJECT_USE_OBJC
    if (imageCaptureSemaphore != NULL)
    {
        dispatch_release(imageCaptureSemaphore);
    }
#endif
    
}

#pragma mark -
#pragma mark Still image processing

- (void)useNextFrameForImageCapture;
{
    usingNextFrameForImageCapture = YES;
    
    // Set the semaphore high, if it isn't already
    if (dispatch_semaphore_wait(imageCaptureSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
}

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput
{
    // Give it three seconds to process, then abort if they forgot to set up the image capture properly
    double timeoutForImageCapture = 10.0;///!!!
    dispatch_time_t convertedTimeout = dispatch_time(DISPATCH_TIME_NOW, timeoutForImageCapture * NSEC_PER_SEC);
    
    if (dispatch_semaphore_wait(imageCaptureSemaphore, convertedTimeout) != 0)
    {
        return NULL;
    }
    
    GPUImageFramebuffer* framebuffer = [self framebufferForOutput];
    
    usingNextFrameForImageCapture = NO;
    dispatch_semaphore_signal(imageCaptureSemaphore);
    
    CGImageRef image = [framebuffer newCGImageFromFramebufferContents];
    return image;
}

#pragma mark -
#pragma mark Managing the display FBOs

- (CGSize)sizeOfFBO;
{
    CGSize outputSize = [self maximumOutputSize];
    if ( (CGSizeEqualToSize(outputSize, CGSizeZero)) || (inputTextureSize.width < outputSize.width) )
    {
        return inputTextureSize;
    }
    else
    {
        return outputSize;
    }
}

#pragma mark -
#pragma mark Rendering

- (void)renderAtTime:(CMTime)frameTime
{
//    if (self.preventRendering)
//    {
//        [firstInputFramebuffer unlock];
//        return;
//    }
    static NSUInteger frameNumber = 0;
    if (frameNumber >= 0 && frameNumber < _gyroDataFrames && _renderer)
    {
        float gyroMatrix[9] = {1.f,0.f,0.f, 0.f,1.f,0.f, 0.f,0.f,1.f};
        getGyroMatrix(gyroMatrix, frameNumber, _gyroData);
//        NSLog(@"#GYRO# {%.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f}", gyroMatrix[0], gyroMatrix[1], gyroMatrix[2], gyroMatrix[3], gyroMatrix[4], gyroMatrix[5], gyroMatrix[6], gyroMatrix[7], gyroMatrix[8]);
//        _panoController->setGyroMatrix(gyroMatrix, 3);
//        _glCamera->setGyroMatrix(gyroMatrix, 3);
    }
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    glClearColor(0.f, 0.5f, 1.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    CGSize boundsSize = [self sizeOfFBO];
    _renderer->setSourceTextures(firstInputFramebuffer.texture, firstInputFramebuffer.texture, GL_TEXTURE_2D, false);
    _renderer->setDisplayMode(PanoramaDisplayModeFromCubeMap | PanoramaDisplayModeLUTInMesh);
    _renderer->drawRemappedPanorama(0, 0, boundsSize.width, boundsSize.height, 512);
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
    
    frameNumber++;///!!!For Debug
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime;
{
    if (self.frameProcessingCompletionBlock != NULL)
    {
        self.frameProcessingCompletionBlock(self, frameTime);
    }
    
    // Get all targets the framebuffer so they can grab a lock on it
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [self setInputFramebufferForTarget:currentTarget atIndex:textureIndex];
            [currentTarget setInputSize:[self outputFrameSize] atIndex:textureIndex];
        }
    }
    
    // Release our hold so it can return to the cache immediately upon processing
    [[self framebufferForOutput] unlock];
    
    if (usingNextFrameForImageCapture)
    {
        //        usingNextFrameForImageCapture = NO;
    }
    else
    {
        [self removeOutputFramebuffer];
    }
    
    // Trigger processing last, so that our unlock comes first in serial execution, avoiding the need for a callback
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            [currentTarget newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

- (CGSize)outputFrameSize;
{
    return inputTextureSize;
}

#pragma mark -
#pragma mark Input parameters

#pragma mark -
#pragma mark GPUImageInput

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    [self renderAtTime:frameTime];
    
    [self informTargetsAboutNewFrameAtTime:frameTime];
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    firstInputFramebuffer = newInputFramebuffer;
    [firstInputFramebuffer lock];
}

- (CGSize)rotatedSize:(CGSize)sizeToRotate forIndex:(NSInteger)textureIndex;
{
    CGSize rotatedSize = sizeToRotate;
    
//    if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
//    {
//        rotatedSize.width = sizeToRotate.height;
//        rotatedSize.height = sizeToRotate.width;
//    }
    
    return rotatedSize;
}

- (CGPoint)rotatedPoint:(CGPoint)pointToRotate forRotation:(GPUImageRotationMode)rotation;
{
    CGPoint rotatedPoint;
    switch(rotation)
    {
        case kGPUImageNoRotation: return pointToRotate; break;
        case kGPUImageFlipHorizonal:
        {
            rotatedPoint.x = 1.0 - pointToRotate.x;
            rotatedPoint.y = pointToRotate.y;
        }; break;
        case kGPUImageFlipVertical:
        {
            rotatedPoint.x = pointToRotate.x;
            rotatedPoint.y = 1.0 - pointToRotate.y;
        }; break;
        case kGPUImageRotateLeft:
        {
            rotatedPoint.x = 1.0 - pointToRotate.y;
            rotatedPoint.y = pointToRotate.x;
        }; break;
        case kGPUImageRotateRight:
        {
            rotatedPoint.x = pointToRotate.y;
            rotatedPoint.y = 1.0 - pointToRotate.x;
        }; break;
        case kGPUImageRotateRightFlipVertical:
        {
            rotatedPoint.x = pointToRotate.y;
            rotatedPoint.y = pointToRotate.x;
        }; break;
        case kGPUImageRotateRightFlipHorizontal:
        {
            rotatedPoint.x = 1.0 - pointToRotate.y;
            rotatedPoint.y = 1.0 - pointToRotate.x;
        }; break;
        case kGPUImageRotate180:
        {
            rotatedPoint.x = 1.0 - pointToRotate.x;
            rotatedPoint.y = 1.0 - pointToRotate.y;
        }; break;
    }
    
    return rotatedPoint;
}

- (void)setupFilterForSize:(CGSize)filterFrameSize;
{
    // This is where you can override to provide some custom setup, if your filter has a size-dependent element
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
//    if (self.preventRendering)
//    {
//        return;
//    }
    
    if (overrideInputSize)
    {
        if (CGSizeEqualToSize(forcedMaximumSize, CGSizeZero))
        {
        }
        else
        {
            CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(newSize, CGRectMake(0.0, 0.0, forcedMaximumSize.width, forcedMaximumSize.height));
            inputTextureSize = insetRect.size;
        }
    }
    else
    {
        CGSize rotatedSize = [self rotatedSize:newSize forIndex:textureIndex];
        
        if (CGSizeEqualToSize(rotatedSize, CGSizeZero))
        {
            inputTextureSize = rotatedSize;
        }
        else if (!CGSizeEqualToSize(inputTextureSize, rotatedSize))
        {
            inputTextureSize = rotatedSize;
        }
    }
    
    [self setupFilterForSize:[self sizeOfFBO]];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
//    inputRotation = newInputRotation;
}

- (void)forceProcessingAtSize:(CGSize)frameSize;
{
    if (CGSizeEqualToSize(frameSize, CGSizeZero))
    {
        overrideInputSize = NO;
    }
    else
    {
        overrideInputSize = YES;
        inputTextureSize = frameSize;
        forcedMaximumSize = CGSizeZero;
    }
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;
{
    if (CGSizeEqualToSize(frameSize, CGSizeZero))
    {
        overrideInputSize = NO;
        inputTextureSize = CGSizeZero;
        forcedMaximumSize = CGSizeZero;
    }
    else
    {
        overrideInputSize = YES;
        forcedMaximumSize = frameSize;
    }
}

- (CGSize)maximumOutputSize;
{
    // I'm temporarily disabling adjustments for smaller output sizes until I figure out how to make this work better
    return CGSizeZero;
    
    /*
     if (CGSizeEqualToSize(cachedMaximumOutputSize, CGSizeZero))
     {
     for (id<GPUImageInput> currentTarget in targets)
     {
     if ([currentTarget maximumOutputSize].width > cachedMaximumOutputSize.width)
     {
     cachedMaximumOutputSize = [currentTarget maximumOutputSize];
     }
     }
     }
     
     return cachedMaximumOutputSize;
     */
}

- (void)endProcessing
{
    if (!isEndProcessing)
    {
        isEndProcessing = YES;
        
        for (id<GPUImageInput> currentTarget in targets)
        {
            [currentTarget endProcessing];
        }
    }
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue {
    
}


- (BOOL)wantsMonochromeInput;
{
    return NO;
}

#pragma mark -
#pragma mark Accessors

@end
