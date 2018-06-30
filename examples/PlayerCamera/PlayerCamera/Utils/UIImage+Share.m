//
//  UIImage+Share.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/30.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "UIImage+Share.h"

@implementation UIImage (Share)

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

@end
