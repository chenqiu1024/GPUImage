//
//  MadvMP4BoxParser.hpp
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/16.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#ifndef MadvMP4BoxParser_hpp
#define MadvMP4BoxParser_hpp

#include <stdio.h>

typedef struct {
    void* lutData;
    int lutDataSize;
    
    void* gyroData;
    int gyroDataSize;
    
} MadvMP4Boxes;

#ifdef __cplusplus
extern "C" {
#endif

    MadvMP4Boxes* createMadvMP4Boxes(const char* mp4Path);

    void releaseMadvMP4Boxes(MadvMP4Boxes* pBoxes);
    
#ifdef __cplusplus
}
#endif

#endif /* MadvMP4BoxParser_hpp */
