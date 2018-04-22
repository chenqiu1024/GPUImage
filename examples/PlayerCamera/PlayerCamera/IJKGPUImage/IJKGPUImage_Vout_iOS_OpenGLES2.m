//
//  IJKGPUImage_Vout_iOS_OpenGLES2.m
//  PlayerCamera
//
//  Created by DOM QIU on 25/03/2018.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "IJKGPUImage_Vout_iOS_OpenGLES2.h"

/*
 * ijksdl_vout_ios_gles2.c
 *
 * Copyright (c) 2013 Bilibili
 * Copyright (c) 2013 Zhang Rui <bbcallen@gmail.com>
 *
 * This file is part of ijkPlayer.
 *
 * ijkPlayer is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ijkPlayer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ijkPlayer; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include <assert.h>
#include "ijksdl/ijksdl_vout.h"
#include "ijksdl/ijksdl_vout_internal.h"
#include "ijksdl/ffmpeg/ijksdl_vout_overlay_ffmpeg.h"
#include "ijksdl_vout_overlay_videotoolbox.h"
#import "IJKGPUImageMovie.h"

/// Immitate from ijksdl_vout_ios_gles2

typedef struct SDL_VoutSurface_Opaque {
    SDL_Vout* vout;
} SDL_VoutSurface_Opaque;

struct SDL_Vout_Opaque {
    IJKGPUImageMovie* glMovieOutput;
};

static SDL_VoutOverlay* vout_create_overlay_l(int width, int height, int frame_format, SDL_Vout* vout)
{
    switch (frame_format)
    {
        case IJK_AV_PIX_FMT__VIDEO_TOOLBOX:
            return SDL_VoutVideoToolBox_CreateOverlay(width, height, vout);
        default:
            return SDL_VoutFFmpeg_CreateOverlay(width, height, frame_format, vout);
    }
}

static SDL_VoutOverlay* vout_create_overlay(int width, int height, int frame_format, SDL_Vout* vout)
{
    SDL_LockMutex(vout->mutex);
    SDL_VoutOverlay *overlay = vout_create_overlay_l(width, height, frame_format, vout);
    SDL_UnlockMutex(vout->mutex);
    return overlay;
}

static void vout_free_l(SDL_Vout* vout)
{
    if (!vout)
        return;
    
    SDL_Vout_Opaque* opaque = vout->opaque;
    if (opaque)
    {
        if (opaque->glMovieOutput)
        {
            // TODO: post to MainThread?
            [opaque->glMovieOutput release];
            opaque->glMovieOutput = nil;
        }
    }
    
    SDL_Vout_FreeInternal(vout);
}

static int vout_display_overlay_l(SDL_Vout* vout, SDL_VoutOverlay* overlay)
{
    SDL_Vout_Opaque* opaque = vout->opaque;
    IJKGPUImageMovie* glMovie = opaque->glMovieOutput;
    
    if (!glMovie) {
        ALOGE("vout_display_overlay_l: NULL glMovie\n");
        return -1;
    }
    
    if (!overlay) {
        ALOGE("vout_display_overlay_l: NULL overlay\n");
        return -1;
    }
    
    if (overlay->w <= 0 || overlay->h <= 0) {
        ALOGE("vout_display_overlay_l: invalid overlay dimensions(%d, %d)\n", overlay->w, overlay->h);
        return -1;
    }
    
    [glMovie render:overlay];
    return 0;
}

static int vout_display_overlay(SDL_Vout* vout, SDL_VoutOverlay* overlay)
{
    @autoreleasepool {
        SDL_LockMutex(vout->mutex);
        int retval = vout_display_overlay_l(vout, overlay);
        SDL_UnlockMutex(vout->mutex);
        return retval;
    }
}

SDL_Vout* IJKGPUImage_Vout_iOS_CreateForOpenGLES2()
{
    SDL_Vout* vout = SDL_Vout_CreateInternal(sizeof(SDL_Vout_Opaque));
    if (!vout)
        return NULL;
    
    SDL_Vout_Opaque* opaque = vout->opaque;
    opaque->glMovieOutput = nil;
    vout->create_overlay = vout_create_overlay;
    vout->free_l = vout_free_l;
    vout->display_overlay = vout_display_overlay;
    
    return vout;
}

static void JKGPUImage_Vout_iOS_SetGLMovieOutput_l(SDL_Vout* vout, IJKGPUImageMovie* glMovieOutput)
{
    SDL_Vout_Opaque* opaque = vout->opaque;
    
    if (opaque->glMovieOutput == glMovieOutput)
        return;
    
    if (opaque->glMovieOutput) {
        [opaque->glMovieOutput release];
        opaque->glMovieOutput = nil;
    }
    
    if (glMovieOutput)
        opaque->glMovieOutput = glMovieOutput;
}

void JKGPUImage_Vout_iOS_SetGLMovieOutput(SDL_Vout* vout, IJKGPUImageMovie* glMovieOutput)
{
    SDL_LockMutex(vout->mutex);
    JKGPUImage_Vout_iOS_SetGLMovieOutput_l(vout, glMovieOutput);
    SDL_UnlockMutex(vout->mutex);
}

