/*
 * Copyright (C) 2010 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef ANDROID_HWUI_PROGRAM_CACHE_H
#define ANDROID_HWUI_PROGRAM_CACHE_H

#include <utils/KeyedVector.h>
#include <utils/Log.h>
#include <utils/String8.h>

#include <GLES2/gl2.h>

#include "Debug.h"
#include "Program.h"
#include "Properties.h"

namespace android {
namespace uirenderer {

///////////////////////////////////////////////////////////////////////////////
// Defines
///////////////////////////////////////////////////////////////////////////////

// Debug
#if DEBUG_PROGRAMS
    #define PROGRAM_LOGD(...) ALOGD(__VA_ARGS__)
#else
    #define PROGRAM_LOGD(...)
#endif

// TODO: This should be set in properties
#define PANEL_BIT_DEPTH 20
#define COLOR_COMPONENT_THRESHOLD (1.0f - (0.5f / PANEL_BIT_DEPTH))
#define COLOR_COMPONENT_INV_THRESHOLD (0.5f / PANEL_BIT_DEPTH)

#define PROGRAM_KEY_TEXTURE 0x1
#define PROGRAM_KEY_A8_TEXTURE 0x2
#define PROGRAM_KEY_BITMAP 0x4
#define PROGRAM_KEY_GRADIENT 0x8
#define PROGRAM_KEY_BITMAP_FIRST 0x10
#define PROGRAM_KEY_COLOR_MATRIX 0x20
#define PROGRAM_KEY_COLOR_LIGHTING 0x40
#define PROGRAM_KEY_COLOR_BLEND 0x80
#define PROGRAM_KEY_BITMAP_NPOT 0x100
#define PROGRAM_KEY_SWAP_SRC_DST 0x2000

#define PROGRAM_KEY_BITMAP_WRAPS_MASK 0x600
#define PROGRAM_KEY_BITMAP_WRAPT_MASK 0x1800

// Encode the xfermodes on 6 bits
#define PROGRAM_MAX_XFERMODE 0x1f
#define PROGRAM_XFERMODE_SHADER_SHIFT 26
#define PROGRAM_XFERMODE_COLOR_OP_SHIFT 20
#define PROGRAM_XFERMODE_FRAMEBUFFER_SHIFT 14

#define PROGRAM_BITMAP_WRAPS_SHIFT 9
#define PROGRAM_BITMAP_WRAPT_SHIFT 11

#define PROGRAM_GRADIENT_TYPE_SHIFT 33
#define PROGRAM_MODULATE_SHIFT 35

#define PROGRAM_IS_POINT_SHIFT 36

#define PROGRAM_HAS_AA_SHIFT 37

#define PROGRAM_HAS_EXTERNAL_TEXTURE_SHIFT 38
#define PROGRAM_HAS_TEXTURE_TRANSFORM_SHIFT 39

#ifdef MISSING_EGL_EXTERNAL_IMAGE
# undef PROGRAM_HAS_EXTERNAL_TEXTURE_SHIFT
# define PROGRAM_HAS_EXTERNAL_TEXTURE_SHIFT PROGRAM_KEY_TEXTURE
#endif

///////////////////////////////////////////////////////////////////////////////
// Types
///////////////////////////////////////////////////////////////////////////////

typedef uint64_t programid;

///////////////////////////////////////////////////////////////////////////////
// Cache
///////////////////////////////////////////////////////////////////////////////

/**
 * Generates and caches program. Programs are generated based on
 * ProgramDescriptions.
 */
class ProgramCache {
public:
    ProgramCache();
    ~ProgramCache();

    Program* get(const ProgramDescription& description);

    void clear();

private:
    Program* generateProgram(const ProgramDescription& description, programid key);
    String8 generateVertexShader(const ProgramDescription& description);
    String8 generateFragmentShader(const ProgramDescription& description);
    void generateBlend(String8& shader, const char* name, SkXfermode::Mode mode);
    void generateTextureWrap(String8& shader, GLenum wrapS, GLenum wrapT);

    void printLongString(const String8& shader) const;

    KeyedVector<programid, Program*> mCache;
}; // class ProgramCache

}; // namespace uirenderer
}; // namespace android

#endif // ANDROID_HWUI_PROGRAM_CACHE_H
