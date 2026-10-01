# hjpythonzd

注入网易版 Minecraft（或其他 iOS App）的悬浮窗脚本加载器 dylib：悬浮球点开主面板（功能 / 日志 / AI / 设置 四个 Tab），支持 JS + Python 脚本、脚本变量自动识别、屏幕快捷键、AI 生成脚本。

## 目录结构

```
hjpythonzd/
├── .github/workflows/build.yml   # GitHub Actions 自动编译
├── Makefile                      # Theos 构建（arm64 + arm64e）
├── resources/
│   └── icon.png                  # ★ 悬浮窗图标：替换成你的图片（推荐 120x120 PNG）
└── Sources/                      # 全部 Objective-C 源码（17 个 .m + 头文件）
    ├── SLMain.m                  # 入口：Python 初始化 + 悬浮窗启动
    ├── SLModel.h/.m              # 功能数据模型（NSSecureCoding）
    ├── SLScriptManager.h/.m      # 功能增删存取
    ├── SLScriptEngine.h/.m       # JS / Python 脚本执行引擎
    ├── SLPythonBridge.h/.m      # Python 内建模块 scriptloader
    ├── SLLogManager.h/.m         # 日志 + 崩溃捕获
    ├── SLAPIClient.h/.m          # OpenAI 兼容接口客户端
    ├── SLFloatWindow.h/.m        # 悬浮球
    ├── SLHotkeyManager.h/.m      # 每个功能的屏幕快捷键
    ├── SLMainTabVC.h/.m          # 主面板（4 个 Tab）
    ├── SLFeatureListVC.h/.m      # 功能列表（点按运行 / 长按设置 / 左滑删除）
    ├── SLAddFeatureVC.h/.m       # 添加功能（JS/PY + AI 生成）
    ├── SLSettingVC.h/.m          # 单功能设置（开关 / 快捷键 / 变量 / 试运行）
    ├── SLLogVC.h/.m              # 日志查看（运行/失败/崩溃/AI/系统）
    ├── SLAIAssistantVC.h/.m      # AI 对话
    ├── SLGlobalSettingVC.h/.m    # API Key / BaseURL / Model 配置
    └── SLHookHelper.h/.m         # 反检测 Hook（预留 fishhook 接口）
```

## 本版相对你贴出的代码修复的问题

| # | 问题 | 修复 |
| --- | --- | --- |
| 1 | 悬浮窗点击打开主面板后悬浮窗消失且无法恢复 | 从应用最顶层 present 主面板，展示时临时隐藏悬浮窗，关闭时恢复，兼容多 scene。
| 2 | 项目路径/持久化目录硬编码为 SLNetEaseMC，不利于改名 | 抽出常量 kProjectFolderName，默认改为 hjpythonzd，统一使用。
| 3 | SLPythonBridge 弹窗查找 keyWindow 在 iOS13+ 场景下不稳 | 使用兼容的 scene 查找逻辑。
| 4 | SLAddFeatureVC 默认选择 Python（在无 Python.framework 下可能不可用） | 默认改为 JS，避免误导用户。

更多细节见代码注释。
