# SLNetEaseMC

注入网易版 Minecraft（或其他 iOS App）的悬浮窗脚本加载器 dylib：悬浮球点开主面板（功能 / 日志 / AI / 设置 四个 Tab），支持 JS + Python 脚本、脚本变量自动识别、屏幕快捷键、AI 生成脚本。

## 目录结构

```
SLNetEaseMC/
├── .github/workflows/build.yml   # GitHub Actions 自动编译
├── Makefile                      # Theos 构建（arm64 + arm64e）
├── resources/
│   └── icon.png                  # ★ 悬浮窗图标：替换成你的图片（推荐 120x120 PNG）
└── Sources/                      # 全部 Objective-C 源码（17 个 .m + 头文件）
    ├── SLMain.m                  # 入口：Python 初始化 + 悬浮窗启动
    ├── SLModel.h/.m              # 功能数据模型（NSSecureCoding）
    ├── SLScriptManager.h/.m      # 功能增删存取
    ├── SLScriptEngine.h/.m       # JS / Python 脚本执行引擎
    ├── SLPythonBridge.h/.m       # Python 内建模块 scriptloader
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
| 1 | **Python 模板里的 `$变量` 是非法 Python 语法**，自带示例脚本必崩 | 引擎运行前自动把 `$var` 转为 `var`（正则 `\$(\w+)`） |
| 2 | **JS 引擎注入的变量没有 `$` 前缀**，脚本里 `$message` 取不到值 | 同时注入 `name` 和 `$name` 两个变量 |
| 3 | **硬链接 `-framework Python`**，没嵌入 framework 时整个 dylib 无法加载 | 改 `-weak_framework Python` + 运行时符号检测，PY 不可用不影响 JS |
| 4 | **`Py_Initialize()` 前未设 PYTHONHOME**，嵌入 Python 必崩 | 初始化前 setenv PYTHONHOME/PYTHONPATH/PYTHONDONTWRITEBYTECODE |
| 5 | sys.path **硬编码 python3.11**，换版本即失效 | 动态扫描 `Resources/lib/python3.*` 目录 |
| 6 | **SLSettingVC 保存时 `cellForRowAtIndexPath:` 离屏返回 nil**，滚出屏幕的变量值丢失 | 改为 `editingDidEnd` 即时写回数据源，保存只读数据源 |
| 7 | CI 上传路径 `.theos/obj/SLNetEaseMC.dylib` **实际在 debug 子目录**，产物为空 | 打包步骤 `find` 定位 + `FINALPACKAGE=1 DEBUG=0` + 打成 zip |
| 8 | 悬浮球 `masksToBounds` 把阴影裁掉；无 icon.png 时悬浮球近乎隐形 | 阴影移到 window 层；无图标时显示默认 ⚡ 占位 |
| 9 | 悬浮球/快捷键可拖出屏幕丢失 | 拖动边界钳制在屏幕内 |

另外：`SLCrashHandler` 补了 `raise(sig)`（记录后让系统正常生成崩溃报告）；`SLLogManager` 解码集合补 `NSMutableArray`；`SLAPIClient` 解析 choices 前加类型校验；`SLMainTabVC` 的 Done 按钮统一由工厂方法生成。

## 编译（GitHub Actions）

1. 把整个 `SLNetEaseMC` 文件夹推到仓库根目录。
2. Actions 自动运行，下载 Artifact `SLNetEaseMC.zip`，内含：
   - `SLNetEaseMC.dylib`（arm64 + arm64e）
   - `resources/icon.png`
   - `Frameworks/Python.framework`（BeeWare iOS Python，运行 PY 脚本用）

## 注入与使用

1. 把 `icon.png`（推荐 120×120）放到 `resources/` 目录（已带默认图，可直接替换）。
2. 解密 IPA，把 `Frameworks/Python.framework` 放到 `Payload/xxx.app/Frameworks/`，把 `icon.png` 放到 `Payload/xxx.app/`。
3. 用 TrollFools 或 insert_dylib 注入 `SLNetEaseMC.dylib`，重新签名安装。
4. 启动 App 出现悬浮球；不嵌 Python.framework 也能用，PY 脚本会提示不可用，JS 正常。
5. 设置页填写 API Key / Base URL / Model 后可使用 AI 助手和 AI 生成脚本。

## 脚本变量约定

- Python：`$message = "Hello"`（行首声明，引擎自动转合法变量）
- JS：`var $message = "Hello";`

在设置页会自动出现对应输入框，修改后随功能保存，运行时注入为同名变量。

## Python 内建模块 `scriptloader`

| 函数 | 说明 |
| --- | --- |
| `scriptloader.sl_alert(msg)` | 弹窗 |
| `scriptloader.sl_log(msg)` | 写入日志页 |
| `scriptloader.sl_http_get(url)` | 同步 GET（10 秒超时），返回字符串 |

JS 可用 `sl_log(msg)` / `sl_alert(msg)`。

数据存储：App 沙盒 `Documents/SLNetEaseMC/`（features.plist / logs / ai_config.plist / pylib）。
