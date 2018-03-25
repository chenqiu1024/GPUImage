//
//  IJKGPUImage_Vout_iOS_OpenGLES2.h
//  PlayerCamera
//
//  Created by DOM QIU on 25/03/2018.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#include "ijksdl/ijksdl_stdinc.h"
#include "ijksdl/ijksdl_vout.h"

@class IJKGPUImageMovie;

SDL_Vout* IJKGPUImage_Vout_iOS_CreateForOpenGLES2();

void JKGPUImage_Vout_iOS_SetGLMovieOutput(SDL_Vout* vout, IJKGPUImageMovie* glMovieOutput);

