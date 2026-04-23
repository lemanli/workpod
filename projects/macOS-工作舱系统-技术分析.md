# macOS 工作舱系统 - 技术分析与开发计划

## 1. 核心技术栈

### 开发语言
- **Swift** (推荐) - macOS 原生开发，与 Cocoa 框架无缝集成
- **SwiftUI** - UI 框架，适合快速开发
- **Objective-C** (备选) - 需要更细粒度控制时

### 核心框架
- **Accessibility API** - 窗口检测与控制
- **CGWindowListCopyWindowInfo** - 窗口信息获取
- **NSWorkspace** - 应用启动与监控
- **CoreGraphics / Quartz** - 窗口操作
- **EventTap** - 全局键盘事件监听
- **UserDefaults / Codable** - 配置存储

---

## 2. 技术模块分解

### 模块 1：应用启动与监控
**难度：⭐⭐☆☆☆ (中低)**

**功能：**
- 启动指定应用
- 监控应用进程状态
- 检测应用是否已运行

**技术：**
```swift
// 启动应用
let url = URL(fileURLWithPath: "/Applications/Chrome.app")
NSWorkspace.shared.open(url)

// 检测应用是否运行
letRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.google.Chrome" }
```

**风险：** 低

---

### 模块 2：窗口检测与布局恢复
**难度：⭐⭐⭐⭐☆ (高)**

**功能：**
- 列出所有窗口及其位置
- 获取窗口位置、大小、标题
- 保存窗口布局快照
- 恢复窗口布局

**技术：**
```swift
// 获取窗口列表
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]

// 窗口信息包含：kCGWindowNumber, kCGWindowBounds, kCGWindowOwnerPID
```

**风险：** 
- 部分应用窗口无法获取（安全限制）
- 窗口 ID 可能变化

**缓解：**
- 首次启动时提示用户授权 Accessibility 权限
- 使用 bundleId + 窗口标题作为标识

---

### 模块 3：快捷键监听
**难度：⭐⭐☆☆☆ (中低)**

**功能：**
- 全局快捷键注册
- 切舱快捷键
- 窗口切换快捷键

**技术：**
```swift
// 使用 EventTap 或 HIServices
let eventTap = CGEventTapCreate(...)
// 或使用 MASShortcut 库
```

**风险：** 
- 用户可能已占用快捷键
- 系统级快捷键优先级问题

**缓解：**
- 提供快捷键冲突检测
- 支持用户自定义快捷键

---

### 模块 4：提示层 UI
**难度：⭐⭐☆☆☆ (中低)**

**功能：**
- 跨舱切换提示
- 出舱检测提示
- 动画过渡

**技术：**
```swift
// 使用 NSWindow + SwiftUI
class OverlayWindow: NSWindow {
    init() {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: true)
        self.level = .screenSaver
        self.ignoresMouseEvents = true
    }
}
```

**风险：** 低

---

### 模块 5：状态持久化
**难度：⭐☆☆☆☆ (低)**

**功能：**
- 保存工作舱配置
- 保存窗口布局快照
- 恢复工作舱状态

**技术：**
```swift
// 使用 UserDefaults + Codable
struct CockpitConfig: Codable {
    let id: String
    let name: String
    let members: [MemberConfig]
}

// 保存
let data = try JSONEncoder().encode(config)
UserDefaults.standard.set(data, forKey: "cockpit_\(id)")
```

**风险：** 低

---

## 3. MVP 开发计划

### 第一阶段：核心功能 (1-2 周)

#### 任务 1：基础框架搭建 (1-2 天)
```
[ ] 创建 Swift/SwiftUI 项目
[ ] 基础窗口 UI
[ ] 配置文件读写
[ ] 日志系统
```

#### 任务 2：应用启动与监控 (2-3 天)
```
[ ] 实现应用启动
[ ] 实现应用状态监控
[ ] 实现应用进程检测
```

#### 任务 3：窗口检测 (3-4 天)
```
[ ] 获取窗口列表
[ ] 解析窗口信息
[ ] 保存窗口布局
[ ] 恢复窗口布局
```

#### 任务 4：工作舱管理 (2-3 天)
```
[ ] 工作舱 CRUD UI
[ ] 工作舱配置保存
[ ] 工作舱列表展示
```

#### 任务 5：一键进入工作舱 (2-3 天)
```
[ ] 工作舱激活逻辑
[ ] 应用启动 + 窗口恢复
[ ] 主成员聚焦
```

### 第二阶段：增强功能 (1-1.5 周)

#### 任务 6：舱内切换 (1-2 天)
```
[ ] 焦点窗口切换
[ ] 窗口层级调整
```

#### 任务 7：跨舱切换提示 (2-3 天)
```
[ ] 提示层 UI
[ ] 切换逻辑
[ ] 取消机制
```

#### 任务 8：伪全屏模式 (2-3 天)
```
[ ] 全屏模式 UI
[ ] 窗口放大逻辑
[ ] 布局恢复
```

#### 任务 9：状态保存与恢复 (1-2 天)
```
[ ] 快照保存
[ ] 状态恢复
[ ] 应用重启恢复
```

---

## 4. 实施优先级

### P0 - 必须完成
1. 应用启动与监控
2. 窗口检测与布局恢复
3. 工作舱创建与管理
4. 一键进入工作舱

### P1 - 应该完成
1. 舱内切换
2. 跨舱切换提示
3. 状态保存与恢复

### P2 - 可选增强
1. 伪全屏模式
2. 快捷键支持
3. 缩略图预览

---

## 5. 开发步骤

### Step 1: 初始化项目
```bash
mkdir WorkPod
cd WorkPod
swift package init --type executable --name WorkPod
```

### Step 2: 创建核心模块
```
WorkPod/
├── Sources/
│   ├── WorkPod/
│   │   ├── main.swift
│   │   ├── Models/
│   │   │   ├── Cockpit.swift
│   │   │   └── Member.swift
│   │   ├── Manager/
│   │   │   ├── CockpitManager.swift
│   │   │   └── WindowManager.swift
│   │   └── UI/
│   │       └── MainWindow.swift
│   └── WorkPodCLI/
│       └── main.swift
├── Package.swift
└── README.md
```

### Step 3: 实现顺序
1. Models - 数据模型定义
2. Manager - 核心逻辑
3. UI - 界面展示

---

## 6. 测试计划

### 单元测试
- 应用启动测试
- 窗口检测测试
- 配置保存测试

### 集成测试
- 完整工作舱流程测试
- 跨舱切换测试

### 手动测试
- 使用常见应用测试兼容性
- 边界情况测试

---

## 7. 风险与应对

| 风险 | 等级 | 应对方案 |
|------|------|----------|
| Accessibility 权限受限 | 高 | 提供清晰的权限引导 |
| 窗口 ID 变化 | 中 | 使用多维标识 |
| 性能问题 | 中 | 持续性能测试 |
| 兼容性问题 | 高 | 优先支持主流应用 |

---

## 8. 下一步行动

1. ✅ 创建 Swift 项目
2. ✅ 实现基础数据模型
3. ✅ 实现应用启动模块
4. ✅ 实现窗口检测模块
5. ✅ 实现工作舱管理 UI

---

**准备开始实施！**
