export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Melodify
Melodify_FILES = Tweak.xm
Melodify_CFLAGS = -fobjc-arc
Melodify_FRAMEWORKS = Foundation UIKit AVFoundation MediaPlayer QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
