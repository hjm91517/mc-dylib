ARCHS = arm64
# BeeWare 的 Python-Apple-support 只提供 arm64 slice；没有 arm64e slice。
# 继续构建 arm64e 会导致 linker 找不到 PyArg_ParseTuple 等符号。
# 13.7 SDK：Linux 上的 clang-14 + ld64.lld-14 只支持 TBD v3（iOS14+ SDK 是 v4，无法链接）
TARGET = iphone:clang:13.7:13.0

PYTHON_FRAMEWORK ?= /opt/Python/Python.framework

include $(THEOS)/makefiles/common.mk

# Linux / 非 macOS 交叉编译宿主无法构建 Apple SDK 的 clang modules（could not build module 'Darwin'），
# 显式清空 Theos 的 modules 标志，改回文本 include，保证在 Linux 上与 macOS 上编译行为一致。
MODULESFLAGS :=

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
# -fuse-ld=lld：Linux 交叉编译时强制使用 ld64.lld（Mach-O），避免 clang 误选 ELF ld
hjpythonzd_LDFLAGS = -F$(PYTHON_FRAMEWORK)/.. -weak_framework Python -fuse-ld=lld

hjpythonzd_FRAMEWORKS = UIKit Foundation JavaScriptCore CoreGraphics
hjpythonzd_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
