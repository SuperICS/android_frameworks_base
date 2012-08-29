LOCAL_PATH:= $(call my-dir)

#
# libmediaplayerservice
#

include $(CLEAR_VARS)

LOCAL_SRC_FILES:=               \
    MediaRecorderClient.cpp     \
    MediaPlayerService.cpp      \
    MetadataRetrieverClient.cpp \
    TestPlayerStub.cpp          \
    MidiMetadataRetriever.cpp   \
    MidiFile.cpp                \
    StagefrightPlayer.cpp       \
    StagefrightRecorder.cpp

ifeq ($(BOARD_USES_AMLOGICPLAYER),true)
    LOCAL_SRC_FILES +=amlogic/AmlPlayerMetadataRetriever.cpp
    LOCAL_SRC_FILES +=amlogic/AmSuperPlayer.cpp
    LOCAL_SRC_FILES +=amlogic/AmlogicPlayer.cpp
    LOCAL_SRC_FILES +=amlogic/AmlogicPlayerRender.cpp
    LOCAL_SRC_FILES +=amlogic/AmlogicPlayerStreamSource.cpp
    LOCAL_SRC_FILES +=amlogic/AmlogicPlayerStreamSourceListener.cpp
endif

LOCAL_SHARED_LIBRARIES :=     		\
	libcutils             			\
	libutils              			\
	libbinder             			\
	libvorbisidec         			\
	libsonivox            			\
	libmedia              			\
	libcamera_client      			\
	libandroid_runtime    			\
	libstagefright        			\
	libstagefright_omx    			\
	libstagefright_foundation       \
	libgui                          \
	libdl

LOCAL_STATIC_LIBRARIES := \
        libstagefright_nuplayer                 \
        libstagefright_rtsp                     \

LOCAL_C_INCLUDES :=                                                 \
	$(JNI_H_INCLUDE)                                                \
	$(call include-path-for, graphics corecg)                       \
	$(TOP)/frameworks/base/include/media/stagefright/openmax \
	$(TOP)/frameworks/base/media/libstagefright/include             \
	$(TOP)/frameworks/base/media/libstagefright/rtsp                \
    $(TOP)/external/tremolo/Tremolo \


ifeq ($(BOARD_USES_AMLOGICPLAYER),true)
LOCAL_C_INCLUDES +=\
		$(TOP)/frameworks/base/include  \
        $(TOP)/packages/amlogic/LibPlayer/amplayer/player/include     \
        $(TOP)/packages/amlogic/LibPlayer/amplayer/control/include    \
        $(TOP)/packages/amlogic/LibPlayer/amadec/include      \
        $(TOP)/packages/amlogic/LibPlayer/amcodec/include     \
        $(TOP)/packages/amlogic/LibPlayer/amavutils/include     \
        $(TOP)/packages/amlogic/LibPlayer/amffmpeg/

LOCAL_SHARED_LIBRARIES += libui
LOCAL_SHARED_LIBRARIES +=libamplayer libamavutils
	LOCAL_CFLAGS += -DAMLOGICPLAYER
	LOCAL_CFLAGS += -DBUILD_WITH_AMLOGIC_PLAYER=1
endif

LOCAL_MODULE:= libmediaplayerservice

include $(BUILD_SHARED_LIBRARY)

include $(call all-makefiles-under,$(LOCAL_PATH))

