ARCHS = arm64
# BeeWare 的 Python-Apple-support 只提供 arm64 slice；没有 arm64e slice。
# 继续构建 arm64e 会导致 linker 找不到 PyArg_ParseTuple 等符号。
TARGET = iphone:clang:latest:14.0

PYTHON_FRAMEWORK ?= /opt/Python/Python.framework

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = hjpythonzd

hjpythonzd_FILES = \
    Sources/SLMain.m \
    Sources/SLConstants.m \
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

hjpythonzd_CFLAGS = -fobjc-arc \
    -Wno-deprecated-declarations \
    -I$(PYTHON_FRAMEWORK)/Headers \
    -F$(PYTHON_FRAMEWORK)/..

# 修复：weak 链接 Python —— 未嵌入 Python.framework 时 dylib 仍可加载（JS 功能不受影响）
hjpythonzd_LDFLAGS = -F$(PYTHON_FRAMEWORK)/.. -weak_framework Python

hjpythonzd_FRAMEWORKS = UIKit Foundation JavaScriptCore
hjpythonzd_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
