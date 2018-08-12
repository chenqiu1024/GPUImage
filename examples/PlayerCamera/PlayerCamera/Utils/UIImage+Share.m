//
//  UIImage+Share.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/30.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "UIImage+Share.h"

@implementation UIImage (Share)

-(UIImage*) imageScaledToFitMaxSize:(CGSize)maxSize orientation:(UIImageOrientation)orientation {
    float scale = 1.0f;
    if (self.size.width > maxSize.width)
        scale = maxSize.width / self.size.width;
    if (self.size.height * scale > maxSize.height)
        scale = maxSize.height / self.size.height;
    if (scale != 1.0f)
    {
        int w = (int)(self.size.width * scale);
        int h = (int)(self.size.height * scale);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGContextDrawImage(context, CGRectMake(0, 0, w, h), self.CGImage);
        CGImageRef cgImage = CGBitmapContextCreateImage(context);
        UIImage* ret = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:orientation];
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        return ret;
    }
    else
        return [UIImage imageWithCGImage:self.CGImage scale:1.0f orientation:orientation];
}

+(UIImage*) longImageWithImages:(NSArray<UIImage* >*)images {
    CGSize longImageSize = CGSizeZero;
    for (UIImage* img in images)
    {
        longImageSize.height += img.size.height;
        if (img.size.width > longImageSize.width)
            longImageSize.width = img.size.width;
    }
    
    GLubyte* imageData = (GLubyte *) calloc(1, (int)longImageSize.width * (int)longImageSize.height * 4);
    
    CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef imageContext = CGBitmapContextCreate(imageData, (int)longImageSize.width, (int)longImageSize.height, 8, (int)longImageSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGFloat y = 0.f;
    for (UIImage* img in images)
    {
        CGContextDrawImage(imageContext, CGRectMake((longImageSize.width - img.size.width) / 2.f, y, img.size.width, img.size.height), img.CGImage);
        y += img.size.height;
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(imageContext);
    UIImage* ret = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    CGContextRelease(imageContext);
    CGColorSpaceRelease(genericRGBColorspace);
    
    free(imageData);
    return ret;
}

/*/
 UIImage *imageToShare = [UIImage imageNamed:@"res1.jpg"];
 UIImage *imageToShare1 = [UIImage imageNamed:@"res3.jpg"];
 NSData* data0 = UIImageJPEGRepresentation(imageToShare, 1.f);
 NSData* data1 = UIImageJPEGRepresentation(imageToShare1, 1.f);
 //NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"res3" ofType:@"jpg"]];
 NSArray *activityItems = @[data0, data1];
 UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
 [self presentViewController:activityVC animated:TRUE completion:nil];
 //*/
+(UIImage*) fixOrientation:(UIImage*)aImage {
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end
