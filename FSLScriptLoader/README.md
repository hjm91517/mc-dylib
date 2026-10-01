# FSLScriptLoader

注入 iOS App 的悬浮窗脚本加载器 dylib：点击悬浮球打开功能面板，可添加 **JS / Python** 脚本功能，点按运行、长按进入设置，每个功能支持屏幕快捷键（点击运行/停止，长按拖到任意位置）。

## 目录结构

```
FSLScriptLoader/
├── .github/workflows/build.yml   # GitHub Actions 自动编译
├── Makefile                      # Theos 构建脚本
├── Resources/
│   └── icon.png                  # ★ 悬浮窗图标 —— 换成你自己的图片（建议 96x96 PNG）
├── Frameworks/                   # CI 自动下载 Python.xcframework（无需手动放）
└── Sources/                      # 全部 Objective-C 源码
    ├── FSLScriptLoader.m         # dylib 入口（constructor）
    ├── FSLCore.h/.m              # 窗口管理（悬浮球 / 面板 / 快捷键）
    ├── FSLFloatingWindow.h/.m    # 悬浮球（可拖动、位置记忆、点击开关面板）
    ├── FSLHotkeyWindow.h/.m      # 每个功能的屏幕快捷键按钮
    ├── FSLMenuViewController.h/.m        # 功能列表（点按运行、长按设置、+ 添加）
    ├── FSLAddFunctionViewController.h/.m # 添加功能（命名 + JS/PY + 脚本输入）
    ├── FSLSettingsViewController.h/.m    # 设置页（开关/快捷键/自动参数/删除）
    ├── FSLFunction.h/.m          # 功能模型 + 持久化
    ├── FSLFunctionManager.h/.m   # 运行状态调度
    ├── FSLConfigParser.h/.m      # @config 参数自动识别
    ├── FSLJSEngine.h/.m          # JS 引擎（JavaScriptCore）
    ├── FSLPythonEngine.h/.m      # Python 引擎（运行时 dlopen Python.framework）
    └── FSLCommon.h/.m            # 工具（取窗口/弹窗/图标加载）
```

## 替换悬浮窗图标

把 **你自己的图标文件命名为 `icon.png`**，放到 `Resources/icon.png` 覆盖即可。
dylib 运行时会按以下顺序找图标：`dylib 同级 FSLResources.bundle/icon.png` → `App 包内 FSLResources.bundle/icon.png` → 内置默认图标。

## GitHub 编译

1. 把整个 `FSLScriptLoader` 文件夹上传到你的 GitHub 仓库（根目录）。
2. 推送后 **Actions** 自动运行；完成后在运行记录里下载 Artifact `FSLScriptLoader.zip`。
3. zip 内容：

```
FSLScriptLoader/
├── FSLScriptLoader.dylib     # 注入用 dylib（arm64 + arm64e）
├── FSLResources.bundle/
│   └── icon.png              # 你的悬浮窗图标
└── Frameworks/
    └── Python.framework      # Python 引擎（需要跑 PY 脚本才要嵌入）
```

## 注入 App

- **dylib**：用 TrollFools / injecttool / insert_dylib 等把 `FSLScriptLoader.dylib` 注入目标 App，并把 `FSLResources.bundle` 放到与 dylib 同级目录（需要图标时）。
- **Python 支持（可选）**：需要运行 PY 脚本时，把 `Frameworks/Python.framework` 放进 App 的 `Frameworks` 目录并随 App 重新签名；不嵌入也能正常注入，只是运行 PY 脚本会提示"Python 引擎未就绪"，JS 脚本不受影响。

## 使用

| 操作 | 效果 |
| --- | --- |
| 点击悬浮球 | 打开 / 关闭功能面板 |
| 拖动悬浮球 | 移动位置（自动记忆） |
| 面板右上角 + | 添加功能：命名 → 选 JS/PY → 输入脚本 → 保存 |
| 点击列表项 | 运行 / 停止该功能 |
| 长按列表项 | 进入该功能设置 |
| 设置-屏幕快捷键 | 开启后屏幕上出现该功能的独立按钮，点击运行/停止，长按拖动到任意位置 |

## 脚本参数自动识别

在脚本里用注释声明参数，设置页会自动生成对应控件：

```js
//@config {"key":"speed","type":"number","default":5,"label":"速度"}
var speed = getConfig("speed");
```

```python
#@config {"key":"debug","type":"bool","default":true,"label":"调试模式"}
import fsl
debug = fsl.get_config("debug")
```

`type` 支持 `bool`（开关）、`number`（数字输入）、`text`（文本输入）。

## 脚本 API

| JS | Python | 说明 |
| --- | --- | --- |
| `alert(msg)` | `fsl.alert(msg)` | 弹窗提示 |
| `log(msg)` / `console.log(msg)` | `fsl.log(msg)` | 写日志 |
| `getConfig(key)` | `fsl.get_config(key)` | 读取参数（用户设置优先，其次默认值） |
| `shouldStop()` | `fsl.should_stop()` | 查询是否收到停止请求（长循环脚本应轮询） |

> "停止"是协作式的：再次点击按钮/列表项会置停止标志，脚本里的循环需用 `shouldStop()` 检查后自行退出。

## 数据存储

功能列表与参数保存在 App 沙盒 `Documents/FSLScriptLoader/functions.plist`。
