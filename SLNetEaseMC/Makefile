ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

PYTHON_FRAMEWORK ?= /opt/Python/Python.framework

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = SLNetEaseMC

SLNetEaseMC_FILES = \
    Sources/SLMain.m \
    Sources/SLModel.m \
    Sources/SLLogManager.m \
    Sources/SLScriptManager.m \
    Sources/SLScriptEngine.m \
    Sources/SLPythonBridge.m \
    Sources/SLAPIClient.m \
    Sources/SLFloatWindow.m \
    Sources/SLHotkeyManager.m \
    Sources/SLMainTabVC.m \
    Sources/SLFeatureListVC.m \
    Sources/SLAddFeatureVC.m \
    Sources/SLSettingVC.m \
    Sources/SLLogVC.m \
    Sources/SLAIAssistantVC.m \
    Sources/SLGlobalSettingVC.m \
    Sources/SLHookHelper.m

SLNetEaseMC_CFLAGS = -fobjc-arc \
    -Wno-deprecated-declarations \
    -I$(PYTHON_FRAMEWORK)/Headers \
    -F$(PYTHON_FRAMEWORK)/..

# 修复：weak 链接 Python —— 未嵌入 Python.framework 时 dylib 仍可加载（JS 功能不受影响）
SLNetEaseMC_LDFLAGS = -F$(PYTHON_FRAMEWORK)/.. -weak_framework Python

SLNetEaseMC_FRAMEWORKS = UIKit Foundation JavaScriptCore
SLNetEaseMC_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
