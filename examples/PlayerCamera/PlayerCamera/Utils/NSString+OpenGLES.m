//
//  NSString+OpenGLES.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/9.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "NSString+OpenGLES.h"

uint32_t nextPowerOfTwo(uint32_t v)
{
    v--;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    return v;
}

GLuint CreateTextureFromText(const char* text, UIFont* font, UIColor* color, int* pOutWidth, int* pOutHeight)
{
    NSString* txt = [NSString stringWithUTF8String:text];
    NSMutableDictionary<NSAttributedStringKey, id>* attributes = [[NSMutableDictionary alloc] init];
    [attributes setObject:[UIColor clearColor] forKey:NSBackgroundColorAttributeName];
    if (color)
    {
        [attributes setObject:color forKey:NSForegroundColorAttributeName];
    }
    if (font)
    {
        [attributes setObject:font forKey:NSFontAttributeName];
    }
    
    CGSize renderedSize = [txt sizeWithAttributes:attributes];
    
    const uint32_t height = nextPowerOfTwo((int)renderedSize.height);
    *pOutHeight = height;
    const uint32_t width = nextPowerOfTwo((int) renderedSize.width);
    *pOutWidth = width;
    
    const int bitsPerElement = 8;
    int sizeInBytes = height * width * 4;
    int texturePitch = width * 4;
    uint8_t* data = calloc(1, sizeInBytes);
    memset(data, 0x00, sizeInBytes);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(data, width, height, bitsPerElement, texturePitch, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGContextSetTextDrawingMode(context, kCGTextFillStroke);
    
    CGColorRef cgColor = color.CGColor;
    CGContextSetStrokeColorWithColor(context, cgColor);
    CGContextSetFillColorWithColor(context, cgColor);
//    CGColorRelease(color);
    CGContextTranslateCTM(context, 0.0f, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    
    UIGraphicsPushContext(context);
    
    [txt drawInRect:CGRectMake(0, 0, width, height) withAttributes:attributes];
    
    UIGraphicsPopContext();
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    GLuint textureID;
    glGenTextures(1, &textureID);
    
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    free(data);
    
    return textureID;
}

@implementation NSString (OpenGLES)

-(GLuint) createTextureWithFont:(UIFont*)font color:(UIColor*)color outSize:(CGSize*)outSize {
    int width, height;
    GLuint texture = CreateTextureFromText(self.UTF8String, font, color, &width, &height);
    if (NULL != outSize)
    {
        outSize->width = width;
        outSize->height = height;
    }
    return texture;
}

@end
