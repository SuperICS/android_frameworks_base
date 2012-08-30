LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    AVCEncoder.cpp \
    src/avcenc_api.cpp \
    src/bitstream_io.cpp \
    src/block.cpp \
    src/findhalfpel.cpp \
    src/header.cpp \
    src/init.cpp \
    src/intra_est.cpp \
    src/motion_comp.cpp \
    src/motion_est.cpp \
    src/rate_control.cpp \
    src/residual.cpp \
    src/sad.cpp \
    src/slice.cpp \
    src/vlc_encode.cpp

ifeq ($(ARCH_ARM_HAVE_NEON),true)
LOCAL_SRC_FILES += src/sad_neon.s src/sad_halfpel_neon.s src/motion_comp_neon.s \
                   src/intra_est_neon.s src/block_neon.s src/motion_est_neon.s \
                   src/sad_inline_neon.s  ColorConverter_neon.s
else
LOCAL_SRC_FILES += src/sad_halfpel.cpp
endif

LOCAL_MODULE := libstagefright_avcenc

LOCAL_C_INCLUDES := \
    $(LOCAL_PATH)/src \
    $(LOCAL_PATH)/../common/include \
    $(TOP)/frameworks/base/include/media/stagefright/openmax \
    $(TOP)/frameworks/base/media/libstagefright/include

LOCAL_CFLAGS := \
    -D__arm__ \
    -DOSCL_IMPORT_REF= -DOSCL_UNUSED_ARG= -DOSCL_EXPORT_REF=

ifeq ($(BOARD_USES_AMLOGICPLAYER),true)
LOCAL_CFLAGS += -DAMLOGICPLAYER
endif

ifeq ($(ARCH_ARM_HAVE_NEON),true)
LOCAL_CFLAGS += -DNEON_OPTIMIZATION
endif

include $(BUILD_STATIC_LIBRARY)
