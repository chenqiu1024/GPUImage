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

#ifdef __cplusplus
extern "C" {
#endif

bool parseMadvMP4Boxes(const char* mp4Path);

#ifdef __cplusplus
}
#endif

#endif /* MadvMP4BoxParser_hpp */
