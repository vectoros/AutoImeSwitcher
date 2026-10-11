# AutoImeSwitcher

一个 macOS 应用，用于在切换前台应用时自动切换输入法。

## 功能特性

- 为不同应用设置默认输入法
- 切换前台应用时自动切换输入法
- 菜单栏图标，方便访问设置
- 可视化配置界面
- 运行日志查看功能

## 系统要求

- macOS 12.0 或更高版本
- Swift 5.9 或更高版本

## 安装

### 从源码构建

1. 克隆此仓库
2. 在项目根目录运行打包脚本：

```bash
bash scripts/package_app.sh
```

3. 构建的应用将自动生成
4. 生成DMG文件

```bash
bash scripts/package_dmg.sh
```

### 从 DMG 安装（需要手动构建）

1. 下载最新的 `AutoImeSwitcher.dmg` 文件
2. 挂载 DMG 文件
3. 将 `AutoImeSwitcher.app` 拖入 `Applications` 文件夹


## 使用方法

1. 启动 AutoImeSwitcher 应用
2. 点击菜单栏中的键盘图标
3. 在设置界面中，点击"添加应用"按钮选择要配置的应用
4. 为每个应用选择默认的输入法
5. 切换应用时，输入法将自动切换

## 项目结构

```
AutoImeSwitcher/
├── Sources/              # 源代码
│   ├── AutoImeSwitcherApp.swift  # 应用入口
│   ├── AppState.swift             # 应用状态管理
│   ├── InputSourceManager.swift   # 输入法管理
│   └── SettingsView.swift         # 设置界面
├── Resources/            # 资源文件
│   ├── AppIcon.icns      # 应用图标
│   └── dmg-background.png
├── scripts/              # 构建脚本
│   ├── package_app.sh    # 应用打包脚本
│   └── package_dmg.sh    # DMG 打包脚本
└── Package.swift         # Swift Package Manager 配置
```

## 技术栈

- SwiftUI - 用户界面
- AppKit - 系统集成
- Carbon - 输入法管理
- Swift Package Manager - 依赖管理

## 许可证

MIT License

## 焦点检测与 macOS 27

使用公开的 NSWorkspace、辅助功能和 Carbon API，最低部署版本仍为 macOS 12。应用/桌面空间变化触发检测，每 0.6 秒校验前台进程以补偿遗漏的激活事件。输入法切换后检查实际结果，最多尝试三次；焦点变化或暂停时，旧请求立即失效。

在设置页点击 **启用增强检测…**，按系统提示授予辅助功能权限，即可监听同一应用内的窗口与输入框焦点变化。未授权或应用不支持辅助功能事件时，仍可使用应用级检测。授权状态会自动刷新。自定义编辑器可能不提供标准输入框角色；本应用不采集按键或输入内容。

设置页提供规则搜索、多选添加应用、暂停开关、实时状态和最近 300 条内存日志。未配置应用保留当前输入法。一次切换校验结束后，手动选择的输入法会保留到下一次受支持的焦点事件。暂不可用的输入法规则不会被刷新操作删除。

## 开发与验证

```bash
swift build
swift test --disable-xctest
swift run
```

测试需要 Swift 6 或更高版本及 Swift Testing。Swift Testing 覆盖过期焦点请求、取消、重试上限、系统延迟恢复输入法及配置保留。macOS 27 手动验证应覆盖：快速切换应用、授权前后的同应用窗口/输入框切换、桌面空间/全屏切换、唤醒/解锁、输入法暂不可用和暂停/恢复。第三方输入法需单独验证，辅助功能支持情况因应用而异。验证时避免同时运行两个版本。

配置仍位于 `~/Library/Application Support/AutoImeSwitcher/config.json`。损坏配置会保留原文件并显示错误，不会自动覆盖。诊断日志仅保存在内存中，无需运行本地调试服务器。
