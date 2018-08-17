#import "MadvPanoGPUIRenderer.h"
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#import <AVFoundation/AVFoundation.h>


@implementation MadvPanoGPUIRenderer

@synthesize preventRendering = _preventRendering;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _preventRendering = NO;
    imageCaptureSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_signal(imageCaptureSemaphore);
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
    });
    
    return self;
}

- (void)dealloc
{
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

- (void)render
{
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    
    //TODO:
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
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
    [self render];
    
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

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

#pragma mark -
#pragma mark Accessors

@end
