# DesktopPet

一个 macOS 桌面宠物：菜单栏常驻、透明悬浮窗、根据系统内存 / 网速实时驱动
宠物的表现。已经接入两个角色：白色比熊犬（`BichonPet`）和狸花猫
（`TabbyCatPet`），可以在菜单栏"切换角色"里互相切换。

两个角色目前用的是两套不同的绘制方式：比熊是 **Rive 素材驱动**
（`Resources/dog.riv` + `RiveRuntime`，见下方 [Rive 集成（比熊）](#rive-集成比熊)），
狸花猫仍然是**纯 SwiftUI 矢量绘制**，接入了"待机微动画 + spring 次级运动"
底层组件（见下方[待机微动画 & spring 次级运动层](#待机微动画--spring-次级运动层通用组件)），
让猫在没有任何系统负载变化时也永远不会看起来"死住"。

## 项目结构

```
DesktopPet/
├── DesktopPet.xcodeproj/
│   └── project.pbxproj
├── DesktopPet/
│   ├── App/
│   │   ├── DesktopPetApp.swift      # @main 入口，占位 Settings Scene
│   │   ├── AppDelegate.swift        # 创建悬浮窗/菜单栏、启动系统监控
│   │   └── AppState.swift           # 当前选中角色 + 角色注册表
│   ├── Windows/
│   │   └── FloatingPanel.swift      # 透明悬浮窗（NSPanel）
│   ├── Monitoring/
│   │   └── SystemMonitor.swift      # 内存 / 网速采集单例
│   ├── Characters/
│   │   ├── PetCharacter.swift       # 角色协议（含 personality 默认实现）
│   │   ├── PetMetrics.swift         # 归一化后的驱动参数
│   │   ├── BichonPet.swift          # 比熊犬角色实现（包装 Rive 视图）
│   │   └── TabbyCatPet.swift        # 狸花猫角色实现
│   ├── Animation/
│   │   ├── SpringValue.swift        # 1D 弹簧-阻尼模拟器（次级运动的物理内核）
│   │   ├── PetPersonality.swift     # 两个角色的"手感"参数表
│   │   ├── IdleAnimator.swift       # 待机微动画层：呼吸/重心晃/眨眼/耳朵抽动/彩蛋
│   │   └── TailSpringChain.swift    # 尾巴多节串联 spring（惯性甩动）
│   ├── Views/
│   │   ├── PetContainerView.swift   # 悬浮窗承载的顶层视图
│   │   ├── BichonView.swift         # 比熊犬：包装 RiveViewModel 播放 dog.riv
│   │   ├── SharedShapes.swift       # 猫仍在用的矢量 Shape（蓬松轮廓/汗滴）
│   │   └── TabbyCatView.swift       # 狸花猫矢量绘制 + 自主行为状态机
│   ├── MenuBar/
│   │   └── MenuBarController.swift  # 菜单栏：退出/自启/切换角色/穿透/调试预览
│   ├── Utilities/
│   │   └── LoginItemManager.swift   # 开机自启（SMAppService）
│   ├── Debug/
│   │   └── DebugCompareView.swift   # 两只宠物并排对比手感的调试视图
│   ├── Resources/
│   │   ├── Assets.xcassets          # AppIcon 占位 + AccentColor
│   │   └── dog.riv                  # 比熊 Rive 素材（Hond 角色，走路循环）
│   └── Info.plist
└── README.md
```

依赖的 Swift Package：**RiveRuntime**（`https://github.com/rive-app/rive-ios`，
`project.pbxproj` 里已经声明了 `XCRemoteSwiftPackageReference` / `up to next
major version 6.0.0`）。用 Xcode 打开项目后，如果没有自动解析，去
File > Packages > Resolve Package Versions 手动触发一次即可，不需要额外配置。

## 运行方法

1. 用 Xcode 15+ 打开 `DesktopPet.xcodeproj`（需要 macOS 13 SDK 及以上）。
2. 选中 `DesktopPet` scheme，运行目标设为 **My Mac**。
3. 点 Run（⌘R）。首次运行看不到 Dock 图标是预期行为——`LSUIElement = YES`
   让它只出现在菜单栏（图标是系统的爪印符号 `pawprint.fill`）。
4. 桌面上会出现一只透明背景的白色比熊犬悬浮窗，可以直接拖动它到任意位置，
   位置会自动记忆，下次启动恢复。
5. 点击菜单栏图标可以：切换角色、开关"鼠标点击穿透"、开关"开机自动启动"、
   打开"调试：手感对比预览"窗口、退出 App。

### 权限说明

- 内存采集（`host_statistics64`）和网速采集（`getifaddrs`）读取的都是系统级
  聚合信息，不需要在 Xcode 里额外勾选任何 Capability，也不需要 App Sandbox
  entitlement。
- 开机自启用的是 macOS 13+ 的 `SMAppService.mainApp`，同样不需要额外配置；
  首次开启后可在"系统设置 > 通用 > 登录项与扩展"里看到。
- 项目当前**没有开启 App Sandbox**（简化本地调试）。如果要上架 App Store，
  需要在 Signing & Capabilities 里开启 App Sandbox 并做真机验证——本项目用到
  的两个采集 API 在沙盒下同样可以正常工作，不需要新增 entitlement。

### 已知限制

- **比熊的两个系统数据驱动效果目前没有接上**（详见下方
  [Rive 集成（比熊）](#rive-集成比熊)）：一是"内存越大肚子越大"，dog.riv
  里没有对应的可控参数；二是"网速越快走得越快"（连续调速播放），没能在
  没有编译器可验证的环境下确认 `RiveViewModel` 是否有 `.speed` 之类的
  API，需要你在 Xcode 里确认后再接上。
- `PetCharacter` 协议里的 `colorForTemperature(_:)` 预留了根据 CPU 温度
  调整毛色的接口，但**没有接入真实温度采集**：macOS 上读取 CPU 温度需要
  访问 SMC（System Management Controller）的私有 IOKit 接口，使用私有 API
  有 App Store 审核被拒的风险，因此当前 `PetMetrics.cpuTemperature`
  始终为 `nil`，两个角色始终显示各自的默认配色。如果你只是自用、不打算上架，
  可以自行接入类似 `SMCKit` 这样的第三方私有 API 封装库。
- `Assets.xcassets` 里的 `AppIcon.appiconset` 只有尺寸占位、没有真实图片，
  因为整个角色都是代码绘制、没有美术资源。由于是 `LSUIElement` App，
  平时也看不到 Dock 图标；如果想要一个像样的 App 图标（比如给"关于本机"
  或 Finder 里看），自行拖几张 PNG 进去即可。
- 猫的"溜达 / 追鸟"目前只是在固定的 170×150 画布内做局部位移，并不会真的
  把桌面悬浮窗拖着到处走（见下方"自主行为状态机"章节末尾的说明）。

## 新增角色的步骤（`TabbyCatPet` 就是照这个流程接进来的）

得益于 `PetCharacter` 协议 + `AppState` 注册表的架构，新增角色不需要碰
窗口管理、系统监控、菜单栏这些基础设施代码，只需要三步：

1. **实现协议**：新建 `Characters/XxxPet.swift`，可以直接参考
   `Characters/TabbyCatPet.swift`（结构和 `BichonPet.swift` 完全一样）：

   ```swift
   struct TabbyCatPet: PetCharacter {
       let id = "cat"
       let displayName = "狸花猫"
       let canvasSize = CGSize(width: 170, height: 150)
       let idleAnimation: PetIdleBehavior = .slowWalk

       /// 不特别定制的话可以省略这一行，协议默认返回 .neutral；
       /// 想要独特的待机/spring 手感就像这样覆盖成专属的 PetPersonality。
       let personality: PetPersonality = .tabbyCat

       func draw(metrics: PetMetrics) -> AnyView {
           AnyView(TabbyCatView(metrics: metrics, bodyColor: colorForTemperature(metrics.cpuTemperature), personality: personality))
       }

       func colorForTemperature(_ celsius: Double?) -> Color { /* 基础配色 */ .brown }
   }
   ```

2. **实现对应的矢量视图**：新建 `Views/XxxView.swift`，参考 `BichonView.swift`
   或 `TabbyCatView.swift` 的结构——拆出身体/耳朵/尾巴/腿等独立子视图，用
   `metrics.memoryFraction` 驱动缩放、`metrics.networkActivity` 驱动
   摆腿/摇尾频率，并接入 `IdleAnimator` + `TailSpringChain`（见下一节）获得
   待机微动画和惯性甩动效果。如果想让角色在网络空闲时"自己找事做"（像猫会
   溜达、追鸟、舔爪子那样），可以参考 `TabbyCatView.swift` 里
   `resolveActivity(idleDuration:)` 的写法：用累计闲置时长做一个纯时间驱动的
   固定"节目单"，不需要额外的定时器或随机数状态。

3. **注册到 AppState**：在 `App/AppState.swift` 里把新角色加进
   `availableCharacters` 列表，并在 `character(for:)` 的 `switch` 里加一个分支
   （现在已经是比熊 + 狸花猫两项，照着追加第三项即可）：

   ```swift
   static let availableCharacters: [(id: String, name: String)] = [
       (id: "bichon", name: "比熊犬"),
       (id: "cat", name: "狸花猫"),
   ]

   static func character(for id: String) -> any PetCharacter {
       switch id {
       case "bichon": return BichonPet()
       case "cat": return TabbyCatPet()
       default: return BichonPet()
       }
   }
   ```

   保存后菜单栏"切换角色"子菜单会自动出现新角色选项，悬浮窗会在切换时
   自动按新角色的 `canvasSize` 调整大小——不需要改 `FloatingPanel.swift`
   或 `MenuBarController.swift`。

   **别忘了同步更新 Xcode 工程文件**：新增的 `.swift` 文件必须出现在
   `DesktopPet.xcodeproj/project.pbxproj` 的 Sources build phase 里才会被编译。
   用 Xcode 图形界面新增文件时它会自动处理；如果是手工拖文件进项目目录，
   记得在 Xcode 里 "Add Files to DesktopPet…" 一下，或者直接检查
   project.pbxproj 里是否已经有对应的 PBXFileReference / PBXBuildFile 条目。

## 待机微动画 & spring 次级运动层（通用组件）

`Animation/` 目录下的四个文件是比熊和狸花猫共用的底层动画组件，和
`SystemMonitor` 那套"系统数据驱动"完全独立，专门负责让角色在**没有任何
系统指标变化**时也始终有细微的生命感：

- **`SpringValue`**：最基础的一维弹簧-阻尼数值积分器。每帧调用
  `update(dt:)`，`value` 会像挂在弹簧上一样滞后地追向 `target`，并带一点
  回弹过冲。它和 SwiftUI 自带的 `.spring()` 修饰符分工不同：`.spring()`
  用于一次性状态切换的插值（比如落地瞬间的挤压回弹），`SpringValue` 用于
  持续追踪一个不断变化目标的物理量（比如尾巴要一直跟着身体的摆动滞后甩动）。
- **`PetPersonality`**：把"待机手感"相关的可调参数收拢成一个配置结构体，
  `IdleAnimator` 和各角色的尾巴/耳朵 spring 都读这里的值。两个角色共用
  同一份 `IdleAnimator` / `SpringValue` 实现，纯靠这个结构体的不同取值
  制造出不同的"性格"：

  | 参数 | 比熊 `.bichon` | 狸花猫 `.tabbyCat` |
  | --- | --- | --- |
  | 呼吸幅度 | 0.03（更明显） | 0.025（更沉稳内敛） |
  | 眨眼间隔 | 2~6 秒 | 1.5~4 秒（更频繁） |
  | 耳朵刚度 | 120 | 150（猫耳更挺、回位更快） |
  | 尾巴节数 / 刚度 | 2 节 / 高刚度（短蓬、甩得"脆"） | 3 节 / 低刚度（长尾、更灵活软甩） |
  | 待机彩蛋 | 偶尔"甩头"（叠加在头部旋转上） | 偶尔"尾尖抽动"（叠加在尾巴角度上），加上有独立调度的"舔爪子"整套动作 |

- **`IdleAnimator`**：持有随机排期状态的 class（用 `@State` 持有实例，
  在 `TimelineView` 反复重算 `body` 时保持同一份状态）。每帧 `update(t:)`
  一次，输出 `IdleState { breathScale, swayX, swayVelocity, eyeOpenL/R,
  earTwitchL/R, quirkPulse }`：
  - 呼吸和重心微晃是两个周期不同（3.2s / 5.1s）的正弦波叠加，避免看起来
    在整体循环；
  - 眨眼不是正弦，是随机排期：到点后 120ms 内 1→0→1；
  - 耳朵抽动、待机彩蛋都是"低概率随机事件 + 给 spring 一个瞬时速度冲量"，
    冲量大小是用 Python 数值模拟 `SpringValue` 的积分过程反推校准过的
    （比熊耳朵抽动峰值约 14°，狸花猫约 16°）。
- **`TailSpringChain`**：N 节串联的 `SpringValue`，每一节的目标是上一节
  当前的值，一个扰动会像鞭子一样沿链条传递、放大/衰减。两个角色都是"目标
  角度由活跃状态/行为决定，实际渲染角度是这个目标喂给链条之后的输出"，
  这样尾巴摆动天然带有"跟不上身体、慢半拍甩过去"的惯性感。渲染上仍然是
  一整根 Capsule（用链条最后一节即"尾尖"的值驱动旋转角），没有做成真正
  可见的多关节尾巴——这是为了避免在没有实机预览的情况下引入高风险的多关节
  变换计算，如果想要更进一步可以在角色的 `tailView` 里把 `segments` 逐节
  用起来（每节一个 Capsule，依次挂在上一节末端）。

**这一层和系统数据驱动层是相乘叠加、不是互相覆盖**：比如两个角色最终的
躯干/肚子缩放都是 `bellyScale（内存决定）× idleState.breathScale（呼吸）`，
躯干渲染时额外还会乘上一次落地/坐下瞬间触发的挤压系数 `squashAmount`，
并用 `scaleX = 1 / sqrt(scaleY)` 保持体积视觉守恒（Y 方向变大一点，X 方向
就同步收窄一点）。挤压回弹用的是 SwiftUI 的 `.spring(response: 0.35,
dampingFraction: 0.6)`，不是 `SpringValue`——因为这是"离散事件触发一次
插值"，交给 SwiftUI 动画系统更省事。

## 调试：手感对比预览

`Debug/DebugCompareView.swift` 是专门用来对比两个角色"手感"的调试视图：
同屏并排显示比熊和狸花猫，并提供两个滑块手动控制内存占用 / 网络活跃度这两个
归一化指标，不需要真的去吃内存、跑网速就能直接对比两只宠物在同一组数值下的
呼吸节奏、眨眼频率、耳朵抽动手感、尾巴甩动软硬程度差异。两种打开方式：

1. 在 Xcode 里直接打开 `DebugCompareView.swift`，用画布左下角的 Canvas
   Preview 查看（`#Preview` 已经内置）；
2. 运行 App 之后，从菜单栏选择"调试：手感对比预览"，会打开一个独立的
   普通窗口（`MenuBarController.openDebugCompareWindow()`）承载同一个视图——
   这个窗口和无边框透明的悬浮宠物窗口是两套完全独立的窗口体系，互不影响，
   `LSUIElement` App 一样可以正常弹出普通窗口。

## 调整体感参数

- 比熊的空闲判定阈值：`BichonView.swift` 里的 `idleThreshold`（目前
  `metrics.networkActivity < 0.04` 就算空闲、暂停走路循环）。比熊的其余
  体感参数（走路速度、肚子大小等）现在都在 `dog.riv` 内部，要改需要回到
  Rive 编辑器，不在这份 Swift 代码里。
- 猫的肚子缩放范围：`TabbyCatView.swift` 里的 `bellyScale` 计算属性
  （0.85x~1.35x）。
- 网速映射的"满速"参考值：`Characters/PetMetrics.swift` 里
  `from(monitor:referencePeakSpeed:)` 的默认参数（目前 5 MB/s）。
- 猫的摆腿/尾巴摇摆频率：`TabbyCatView.swift` 里的 `runLegFrequency` /
  `runLegAmplitude` 以及各 `CatActivity` 分支里的数字。
- 系统指标采集间隔：`Monitoring/SystemMonitor.swift` 里的
  `refreshInterval`（目前 1.5 秒，符合 1~2 秒的需求区间）。
- 猫的待机手感（呼吸/眨眼/耳朵/尾巴/彩蛋）：`Animation/PetPersonality.swift`
  里的 `.tabbyCat` 预设，数值和视觉幅度大致成线性关系，想要更夸张或更细腻
  的手感直接改这里的数字即可（`.bichon` 预设还在，但比熊换成 Rive 之后
  暂时没有代码在读它）。

## Rive 集成（比熊）

比熊犬这一版换成了 [Rive](https://rive.app) 素材驱动，不再是纯 SwiftUI
矢量绘制。`BichonView.swift` 用 `RiveViewModel(fileName: "dog", animationName:
"dog-walk-cycle")` 加载并播放 `Resources/dog.riv`。

**`dog.riv` 里实际有什么**（因为沙盒里没有 Rive 解析工具，是用 `strings`
命令读二进制文件里的可读字符串反推出来的，不是看 Rive 编辑器得到的，如果和
你在 Rive 编辑器里看到的实际结构有出入，以你在编辑器里看到的为准）：

- 一个叫 `Hond`（荷兰语"狗"）的 artboard；
- 一段循环时间轴动画，名字精确是 `dog-walk-cycle`；
- 一个 `State Machine 1`，里面是三组点击/悬停触发的"反应"状态
  （摸耳朵 `Hit Oor`、摸尾巴 `Hit Staart`、摸舌头 `Hit Tong`，各自都有
  In/Out 子状态），这一版**没有接入**，纯粹是走路循环在跑；
- 没有找到任何看起来像"连续数值输入"（Number/Boolean input）的东西，
  所以没法用它做"内存越大肚子越大"这种连续驱动效果。

**当前接入的行为**：网络空闲 → `riveViewModel.pause()`（站定不动）；网络
有活动 → `riveViewModel.play()`（播放走路循环）。这两个方法是从 Rive 官方
"Playing / Pausing" 文档示例里确认过的，可以放心用。

**故意没做的两件事**（不是漏掉，是刻意留给你确认后再接）：

1. **网速越快走得越快**（连续调速播放）——没能找到 `RiveViewModel`（或更
   底层的 `RiveLinearAnimationInstance`）是否暴露 `.speed` / `setSpeed`
   之类的属性的确切签名，官方文档和能搜到的资料都没有给出定论。这个环境
   里没有 Swift 编译器，没法验证一个猜出来的 API 到底能不能编译通过，所以
   没有直接写。等你在 Xcode 里把 `RiveRuntime` 包解析完，麻烦 Cmd+click
   点进 `RiveViewModel` 看一下（或者直接翻
   https://github.com/rive-app/rive-ios 源码），如果确实有类似的成员，
   告诉我签名，我再把网速→播放速度这段接上。
2. **内存越大肚子越大**——`dog.riv` 没有对应的可控参数，需要回到 Rive
   编辑器里给 `Hond` 加一个 Number 类型的 State Machine Input（比如叫
   `bellyScale`）绑定到肚子部分的缩放，导出后 `BichonView.swift` 里用
   `riveViewModel.setInput("bellyScale", value: metrics.memoryFraction)`
   （具体方法名同样需要你在 Xcode 里确认）就能连续驱动。

如果之后想让点击耳朵/尾巴/舌头触发对应的 Rive 反应动画（`Hit Oor` /
`Hit Staart` / `Hit Tong`），需要用 `RiveViewModel` 暴露的 State Machine
trigger 接口配合 `.onTapGesture` 或 Rive 自带的命中区域，这一版也还没做。

针对旧版矢量比熊的"白色在白背景下看不清"问题：Rive 素材本身的描边/配色是在
Rive 编辑器里画好的，代码这边目前没有做任何额外的兜底描边或投影，如果实际
用起来发现可见度不够，需要回到 Rive 编辑器里调整，而不是在 `BichonView.swift`
里加 SwiftUI 的 `.shadow(...)`（那样只会给整个 Rive 画布加投影，不会改变
素材内部描边）。

## 自主行为状态机（狸花猫）

`TabbyCatView.swift` 里的猫不是简单地"闲置就坐下"，而是有一套 `CatActivity` 状态机：

- 网络活跃时固定是 `.run`，真正快速奔跑（写法和比熊同源：四条腿对角步态 +
  弹跳 + 抖动）；
- 网络空闲时，按累计闲置时长在 `resolveActivity(idleDuration:)` 里跑一遍
  固定"节目单"：溜达（`.pace`，会在画布内小范围来回走动）→ 坐下 → 舔爪子
  （抬起前腿、眯眼）→ 伸懒腰（弓背、前腿伸直）→ 追鸟（画面上方飞过一只
  简化的小鸟精灵，猫抬头快速小跳追逐）→ 坐下，循环往复；
- 闲置超过 46 秒后固定进入 `.sleep`，蜷起来闭眼睡觉、飘 "z" 字，直到网络
  重新活跃才会醒来重新开始节目单。

这套"节目单"完全是 `idleDuration`（累计闲置时长）的纯函数，不需要额外的
Timer 或随机数状态，和整个项目"TimelineView 驱动"的风格保持一致。在这套
确定性节目单之上，猫还叠加了 `IdleAnimator` 的随机彩蛋（`quirkPulse`），
被解读成独立于"舔爪子"这个节目之外的"尾尖突然抽动一下"，两者互不冲突。

**已知范围限制**：溜达、追鸟这些"自己动起来"的效果目前只是在固定的
170×150 画布内做局部位移，并不会真的把桌面悬浮窗拖着到处走。如果想做成
"猫真的在桌面上走来走去"，需要在 `FloatingPanelController` 里新增一个
"由角色驱动窗口位置"的接口，让 `TabbyCatView` 能反向通知窗口移动——这个联动
目前还没有做，属于合理的下一步扩展方向。
