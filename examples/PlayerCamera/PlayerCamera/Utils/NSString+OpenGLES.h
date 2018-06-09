//
//  NSString+OpenGLES.h
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/9.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>

//#ifdef __cplusplus
//extern "C" {
//#endif
//
//    inline uint32_t nextPowerOfTwo(uint32_t v);
//    
//    GLuint CreateTextureFromText(const char* text, UIFont* font, const CGColorRef color, int* pOutWidth, int* pOutHeight);
//    
//#ifdef __cplusplus
//}
//#endif

@interface NSString (OpenGLES)

-(GLuint) createTextureWithFont:(UIFont*)font color:(UIColor*)color outSize:(CGSize*)outSize;

@end
