//
//  IJKGPUImage_GLES2_Renderer.h
//  GijkPlayer
//
//  Created by DOM QIU on 2018/5/29.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#ifndef IJKGPUImage_GLES2_Renderer_H
#define IJKGPUImage_GLES2_Renderer_H

#ifdef __APPLE__
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>
#else
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <GLES2/gl2platform.h>
#endif

#include "ijksdl/ijksdl_gles2.h"

//typedef struct SDL_VoutOverlay SDL_VoutOverlay;

/*
 * Common
 */

//#ifdef DEBUG
//#define IJK_GLES2_checkError_TRACE(op)
//#define IJK_GLES2_checkError_DEBUG(op)
//#else
//#define IJK_GLES2_checkError_TRACE(op) IJK_GLES2_checkError(op)
//#define IJK_GLES2_checkError_DEBUG(op) IJK_GLES2_checkError(op)
//#endif

//void IJK_GLES2_printString(const char *name, GLenum s);
//void IJK_GLES2_checkError(const char *op);
//
//GLuint IJK_GLES2_loadShader(GLenum shader_type, const char *shader_source);


/*
 * Renderer
 */
//#define IJK_GLES2_MAX_PLANE 3
//typedef struct IJK_GLES2_Renderer IJK_GLES2_Renderer;

IJK_GLES2_Renderer *IJKGPUImage_GLES2_Renderer_create(SDL_VoutOverlay *overlay);
void      IJKGPUImage_GLES2_Renderer_reset(IJK_GLES2_Renderer *renderer);
void      IJKGPUImage_GLES2_Renderer_free(IJK_GLES2_Renderer *renderer);
void      IJKGPUImage_GLES2_Renderer_freeP(IJK_GLES2_Renderer **renderer);

GLboolean IJKGPUImage_GLES2_Renderer_setupGLES();
GLboolean IJKGPUImage_GLES2_Renderer_isValid(IJK_GLES2_Renderer *renderer);
GLboolean IJKGPUImage_GLES2_Renderer_isFormat(IJK_GLES2_Renderer *renderer, int format);
GLboolean IJKGPUImage_GLES2_Renderer_use(IJK_GLES2_Renderer *renderer);
GLboolean IJKGPUImage_GLES2_Renderer_renderOverlay(IJK_GLES2_Renderer *renderer, SDL_VoutOverlay *overlay);

//#define IJK_GLES2_GRAVITY_RESIZE                (0) // Stretch to fill view bounds.
//#define IJK_GLES2_GRAVITY_RESIZE_ASPECT         (1) // Preserve aspect ratio; fit within view bounds.
//#define IJK_GLES2_GRAVITY_RESIZE_ASPECT_FILL    (2) // Preserve aspect ratio; fill view bounds.
GLboolean IJKGPUImage_GLES2_Renderer_setGravity(IJK_GLES2_Renderer *renderer, int gravity, GLsizei view_width, GLsizei view_height);

#endif //#ifndef IJKGPUImage_GLES2_Renderer_H

