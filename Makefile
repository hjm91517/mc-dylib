export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MCPlugin
MCPlugin_FILES = Tweak.xm fishhook/fishhook.c
MCPlugin_CFLAGS = -fobjc-arc -I./fishhook -Wno-unused-function
MCPlugin_FRAMEWORKS = Foundation UIKit AVFoundation WebKit

include $(THEOS_MAKE_PATH)/tweak.mk
