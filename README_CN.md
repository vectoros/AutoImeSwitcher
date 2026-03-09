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
./scripts/package_app.sh
```

3. 构建的应用将自动生成
4. 生成DMG文件

```bash
./scripts/package_dmg.sh
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
