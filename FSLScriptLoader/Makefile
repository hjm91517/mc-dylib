export TARGET := iphone:clang:latest:14.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = FSLScriptLoader

FSLScriptLoader_FILES = $(wildcard Sources/*.m)
FSLScriptLoader_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore JavaScriptCore
FSLScriptLoader_CFLAGS = -fobjc-arc -O2 -Wno-deprecated-declarations -Wno-unused-variable
FSLScriptLoader_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
