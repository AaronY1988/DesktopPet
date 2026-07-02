# DesktopPet

一个 macOS 桌面宠物：菜单栏常驻、透明悬浮窗、根据系统内存 / 网速实时驱动
宠物的表现。已经接入两个角色：小花狗（`SpottedDogPet`）和狸花猫
（`TabbyCatPet`），可以在菜单栏"切换角色"里互相切换。

两个角色目前用的是两套不同的绘制方式：小花狗是**整张矢量插画**驱动
（用户提供的 SVG 转成 PDF，放进 `Assets.xcassets`，见下方
[小花狗：矢量插画](#小花狗矢量插画) 一节），狸花猫仍然是**逐部件手绘的
纯 SwiftUI 矢量绘制**，接入了"待机微动画 + spring 次级运动"底层组件
（见下方[待机微动画 & spring 次级运动层](#待机微动画--spring-次级运动层通用组件)），
让猫在没有任何系统负载变化时也永远不会看起来"死住"。小花狗因为是整张
不可拆分的插画，只能做"整只宠物一起动"的效果（呼吸缩放、待机摇晃、
奔跑弹跳抖动），拿不到猫那种耳朵抽动/尾巴甩动级别的局部动画。

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
│   │   ├── SpottedDogPet.swift      # 小花狗角色实现（包装矢量插画）
│   │   └── TabbyCatPet.swift        # 狸花猫角色实现
│   ├── Animation/
│   │   ├── SpringValue.swift        # 1D 弹簧-阻尼模拟器（次级运动的物理内核）
│   │   ├── PetPersonality.swift     # 两个角色的"手感"参数表
│   │   ├── IdleAnimator.swift       # 待机微动画层：呼吸/重心晃/眨眼/耳朵抽动/彩蛋
│   │   └── TailSpringChain.swift    # 尾巴多节串联 spring（惯性甩动，目前只有猫在用）
│   ├── Views/
│   │   ├── PetContainerView.swift   # 悬浮窗承载的顶层视图
│   │   ├── SpottedDogView.swift     # 小花狗：矢量插画 + 整体级别动画
│   │   ├── SharedShapes.swift       # 两个角色共用的矢量 Shape（蓬松轮廓/汗滴）
│   │   └── TabbyCatView.swift       # 狸花猫矢量绘制 + 自主行为状态机
│   ├── MenuBar/
│   │   └── MenuBarController.swift  # 菜单栏：退出/自启/切换角色/穿透/调试预览
│   ├── Utilities/
│   │   └── LoginItemManager.swift   # 开机自启（SMAppService）
│   ├── Debug/
│   │   └── DebugCompareView.swift   # 两只宠物并排对比手感的调试视图
│   ├── Resources/
│   │   └── Assets.xcassets          # AppIcon 占位 + AccentColor + SpottedDog 矢量插画
│   └── Info.plist
└── README.md
```

## 运行方法

1. 用 Xcode 15+ 打开 `DesktopPet.xcodeproj`（需要 macOS 13 SDK 及以上）。
2. 选中 `DesktopPet` scheme，运行目标设为 **My Mac**。
3. 点 Run（⌘R）。首次运行看不到 Dock 图标是预期行为——`LSUIElement = YES`
   让它只出现在菜单栏（图标是系统的爪印符号 `pawprint.fill`）。
4. 桌面上会出现一只透明背景的小花狗悬浮窗，可以直接拖动它到任意位置，
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

- `PetCharacter` 协议里的 `colorForTemperature(_:)` 预留了根据 CPU 温度
  调整毛色的接口，但**没有接入真实温度采集**：macOS 上读取 CPU 温度需要
  访问 SMC（System Management Controller）的私有 IOKit 接口，使用私有 API
  有 App Store 审核被拒的风险，因此当前 `PetMetrics.cpuTemperature`
  始终为 `nil`，两个角色始终显示各自的默认配色。如果你只是自用、不打算上架，
  可以自行接入类似 `SMCKit` 这样的第三方私有 API 封装库。
- `Assets.xcassets` 里的 `AppIcon.appiconset` 只有尺寸占位、没有真实图片，
  因为猫的角色是代码绘制、没有对应的美术资源（小花狗现在有一张矢量插画，
  但没有额外导出一份方形的 App 图标版本）。由于是 `LSUIElement` App，
  平时也看不到 Dock 图标；如果想要一个像样的 App 图标（比如给"关于本机"
  或 Finder 里看），自行拖几张 PNG 进去即可。
- 猫的"溜达 / 追鸟"目前只是在固定的 170×150 画布内做局部位移，并不会真的
  把桌面悬浮窗拖着到处走（见下方"自主行为状态机"章节末尾的说明）。
- 曾经短暂把小花狗换成 Rive 素材驱动（`Resources/dog.riv` + RiveRuntime），
  后来放弃了：那个素材的 artboard 内部自带一块不透明背景矩形，Rive 的
  运行时 `fit`/`alignment` 参数只能控制整体缩放裁切，没法单独隐藏/去掉
  artboard 内部某一层，必须回到 Rive 编辑器里改，但当时没有编辑权限，
  所以先退回了纯矢量实现，再换成了现在这张用户提供的矢量插画。如果以后
  想再试 Rive，找素材时提前确认 artboard 背景是透明的，或者自己有权限
  在编辑器里改。
- 小花狗现在是一整张不可拆分的矢量插画，耳朵抽动、尾巴甩动、四条腿摆动
  步态、坐下时腿缩短、眨眼这些效果都做不出来，只剩呼吸缩放、待机小幅
  摇晃、奔跑弹跳/抖动这些"整只宠物一起动"的效果（详见 `SpottedDogView.swift`
  开头注释）。如果想找回局部动画，要么请人把插画拆成分层矢量部件，要么
  补充几张不同姿势的插画做成姿势切换式动画。

## 新增角色的步骤（`TabbyCatPet` 就是照这个流程接进来的）

得益于 `PetCharacter` 协议 + `AppState` 注册表的架构，新增角色不需要碰
窗口管理、系统监控、菜单栏这些基础设施代码，只需要三步：

1. **实现协议**：新建 `Characters/XxxPet.swift`，可以直接参考
   `Characters/TabbyCatPet.swift`（结构和 `SpottedDogPet.swift` 基本一样）：

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

2. **实现对应的视图**，两条路都行：
   - **逐部件矢量绘制**（更丰富的局部动画，参考 `TabbyCatView.swift`）：
     拆出身体/耳朵/尾巴/腿等独立子视图，用 `metrics.memoryFraction` 驱动
     缩放、`metrics.networkActivity` 驱动摆腿/摇尾频率，并接入
     `IdleAnimator` + `TailSpringChain`（见下一节）获得待机微动画和惯性
     甩动效果。如果想让角色在网络空闲时"自己找事做"（像猫会溜达、追鸟、
     舔爪子那样），可以参考 `TabbyCatView.swift` 里
     `resolveActivity(idleDuration:)` 的写法：用累计闲置时长做一个纯
     时间驱动的固定"节目单"，不需要额外的定时器或随机数状态。
   - **包装一整张矢量插画**（更省事，但只能做整体级别动画，参考
     `SpottedDogView.swift`）：把 PDF/转换后的矢量图加进
     `Assets.xcassets`，用 `Image("XxxAssetName")` 显示，再叠加呼吸缩放、
     待机摇晃、奔跑弹跳/抖动这些作用在整张图上的变换。适合美术资源是
     "一整张画死的插画、没法拆部件"的情况。

3. **注册到 AppState**：在 `App/AppState.swift` 里把新角色加进
   `availableCharacters` 列表，并在 `character(for:)` 的 `switch` 里加一个分支
   （现在已经是小花狗 + 狸花猫两项，照着追加第三项即可）：

   ```swift
   static let availableCharacters: [(id: String, name: String)] = [
       (id: "dog", name: "小花狗"),
       (id: "cat", name: "狸花猫"),
   ]

   static func character(for id: String) -> any PetCharacter {
       switch id {
       case "dog": return SpottedDogPet()
       case "cat": return TabbyCatPet()
       default: return SpottedDogPet()
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

`Animation/` 目录下的四个文件是两个角色共用的底层动画组件（`TailSpringChain`
和耳朵 spring 目前只有狸花猫在用，小花狗换成整张矢量插画之后没有对应的
局部部件），和 `SystemMonitor` 那套"系统数据驱动"完全独立，专门负责让
角色在**没有任何系统指标变化**时也始终有细微的生命感：

- **`SpringValue`**：最基础的一维弹簧-阻尼数值积分器。每帧调用
  `update(dt:)`，`value` 会像挂在弹簧上一样滞后地追向 `target`，并带一点
  回弹过冲。它和 SwiftUI 自带的 `.spring()` 修饰符分工不同：`.spring()`
  用于一次性状态切换的插值（比如落地瞬间的挤压回弹），`SpringValue` 用于
  持续追踪一个不断变化目标的物理量（比如尾巴要一直跟着身体的摆动滞后甩动）。
- **`PetPersonality`**：把"待机手感"相关的可调参数收拢成一个配置结构体，
  `IdleAnimator` 和各角色的尾巴/耳朵 spring 都读这里的值。两个角色共用
  同一份 `IdleAnimator` / `SpringValue` 实现，纯靠这个结构体的不同取值
  制造出不同的"性格"：

  | 参数 | 小花狗 `.spottedDog` | 狸花猫 `.tabbyCat` |
  | --- | --- | --- |
  | 呼吸幅度 | 0.03（更明显） | 0.025（更沉稳内敛） |
  | 眨眼间隔 | 2~6 秒（无眨眼部件，字段暂时用不上） | 1.5~4 秒（更频繁） |
  | 耳朵刚度 | 120（无耳朵部件，字段暂时用不上） | 150（猫耳更挺、回位更快） |
  | 尾巴节数 / 刚度 | 2 节 / 高刚度（无尾巴部件，字段暂时用不上） | 3 节 / 低刚度（长尾、更灵活软甩） |
  | 待机彩蛋 | 偶尔整只狗小幅摇晃一下 | 偶尔"尾尖抽动"（叠加在尾巴角度上），加上有独立调度的"舔爪子"整套动作 |

- **`IdleAnimator`**：持有随机排期状态的 class（用 `@State` 持有实例，
  在 `TimelineView` 反复重算 `body` 时保持同一份状态）。每帧 `update(t:)`
  一次，输出 `IdleState { breathScale, swayX, swayVelocity, eyeOpenL/R,
  earTwitchL/R, quirkPulse }`：
  - 呼吸和重心微晃是两个周期不同（3.2s / 5.1s）的正弦波叠加，避免看起来
    在整体循环；
  - 眨眼不是正弦，是随机排期：到点后 120ms 内 1→0→1；
  - 耳朵抽动、待机彩蛋都是"低概率随机事件 + 给 spring 一个瞬时速度冲量"，
    冲量大小是用 Python 数值模拟 `SpringValue` 的积分过程反推校准过的
    （狸花猫耳朵抽动峰值约 16°；小花狗没有耳朵部件，这部分算出来的
    `earTwitchL/R` 目前直接丢弃不用）。
- **`TailSpringChain`**：N 节串联的 `SpringValue`，每一节的目标是上一节
  当前的值，一个扰动会像鞭子一样沿链条传递、放大/衰减。目前只有狸花猫在用：
  "目标角度由活跃状态/行为决定，实际渲染角度是这个目标喂给链条之后的
  输出"，这样尾巴摆动天然带有"跟不上身体、慢半拍甩过去"的惯性感。渲染上
  仍然是一整根 Capsule（用链条最后一节即"尾尖"的值驱动旋转角），没有做成
  真正可见的多关节尾巴——这是为了避免在没有实机预览的情况下引入高风险的
  多关节变换计算，如果想要更进一步可以在角色的 `tailView` 里把 `segments`
  逐节用起来（每节一个 Capsule，依次挂在上一节末端）。

**这一层和系统数据驱动层是相乘叠加、不是互相覆盖**：狸花猫最终的
躯干/肚子缩放是 `bellyScale（内存决定）× idleState.breathScale（呼吸）`；
小花狗因为是整张插画，把"内存决定的整体缩放"和呼吸缩放一起乘在整张图上
（`memoryScale × breathingCG`）。两个角色都会额外乘上一次落地/坐下瞬间
触发的挤压系数 `squashAmount`，并用 `scaleX = 1 / sqrt(scaleY)` 保持体积
视觉守恒（Y 方向变大一点，X 方向就同步收窄一点）。挤压回弹用的是 SwiftUI
的 `.spring(response: 0.35, dampingFraction: 0.6)`，不是 `SpringValue`——
因为这是"离散事件触发一次插值"，交给 SwiftUI 动画系统更省事。

## 调试：手感对比预览

`Debug/DebugCompareView.swift` 是专门用来对比两个角色表现的调试视图：
同屏并排显示小花狗和狸花猫，并提供两个滑块手动控制内存占用 / 网络活跃度这两个
归一化指标，不需要真的去吃内存、跑网速就能直接对比。小花狗换成矢量插画之后
能对比的只剩呼吸节奏、待机摇晃、奔跑弹跳/抖动这些整体效果，猫这边仍然能看到
眨眼频率、耳朵抽动手感、尾巴甩动软硬程度这些局部动画差异。两种打开方式：

1. 在 Xcode 里直接打开 `DebugCompareView.swift`，用画布左下角的 Canvas
   Preview 查看（`#Preview` 已经内置）；
2. 运行 App 之后，从菜单栏选择"调试：手感对比预览"，会打开一个独立的
   普通窗口（`MenuBarController.openDebugCompareWindow()`）承载同一个视图——
   这个窗口和无边框透明的悬浮宠物窗口是两套完全独立的窗口体系，互不影响，
   `LSUIElement` App 一样可以正常弹出普通窗口。

## 调整体感参数

- 整体/肚子缩放范围：小花狗是 `SpottedDogView.swift` 里的 `memoryScale`
  计算属性（0.9x~1.25x，整只狗一起变大）；猫是 `TabbyCatView.swift` 里的
  `bellyScale`（0.85x~1.35x，只有肚子变大）。
- 网速映射的"满速"参考值：`Characters/PetMetrics.swift` 里
  `from(monitor:referencePeakSpeed:)` 的默认参数（目前 5 MB/s）。
- 奔跑弹跳/抖动节奏：小花狗是 `SpottedDogView.swift` 的 `stepFrequency`
  （只驱动弹跳/抖动的节奏，不再驱动真的腿部摆动）；猫是
  `TabbyCatView.swift` 里的 `runLegFrequency` / `runLegAmplitude`
  以及各 `CatActivity` 分支里的数字（猫仍然有真的四条腿摆动步态）。
- 系统指标采集间隔：`Monitoring/SystemMonitor.swift` 里的
  `refreshInterval`（目前 1.5 秒，符合 1~2 秒的需求区间）。
- 待机手感（呼吸/眨眼/耳朵/尾巴/彩蛋）：`Animation/PetPersonality.swift`
  里的 `.spottedDog` / `.tabbyCat` 预设，数值和视觉幅度大致成线性关系，
  想要更夸张或更细腻的手感直接改这里的数字即可（`.spottedDog` 里
  ear*/tail* 相关字段目前没有代码在读，改了也不会有效果）。

## 小花狗：矢量插画

`SpottedDogView.swift` 包装的是一整张用户提供的矢量插画（SVG 转 PDF，加进
`Assets.xcassets/SpottedDog.imageset`，勾选了 Preserve Vector Data，
任意窗口缩放下都不会糊），不是逐部件手绘的 SwiftUI Shape，所以能做的都是
"整张图"级别的变换：

- 呼吸缩放：复用 `IdleAnimator.breathScale`，整只狗随呼吸微微鼓缩；
- 内存驱动的整体缩放：`memoryScale`（0.9x~1.25x），内存越大整只狗略微
  变大一圈——原来比熊是"肚子变大"，现在肚子和身体画在同一张图里分不开，
  只能做整体缩放的近似；
- 奔跑弹跳 + 高频抖动：`runningBounce` / `runningShake`，网速越快越明显，
  和猫的实现是同一套正弦波叠加手法；
- 待机彩蛋：`quirkPulse` 驱动一次小幅度的整体摇晃（`wiggle`），原来比熊是
  "甩头"，现在甩不了头，改成摇晃整只狗；
- 吐舌头喘气冒汗、打盹飘 "z" 字：这两个本来就是独立叠加在头部附近的浮层，
  不依赖对头部本身的形变，原样保留，只是坐标从"头部子视图的局部坐标"
  改成了"整张图的相对坐标估算头部大概在哪"；
- 落地/闲置切换瞬间的挤压回弹：`triggerSquash()`，作用对象从"身体形状"
  换成了整张插画，逻辑不变。

**彻底失去的效果**：耳朵抽动、尾巴 spring 甩动、四条腿摆动步态、坐下时腿
缩短的姿态切换、眨眼——这些都需要能单独控制局部部件才能做，单张矢量插画
做不到。如果之后想找回来，两个方向：一是请人把这只狗拆成分层的矢量部件
（身体/头/耳朵/尾巴/腿各一个文件），代码这边照抄 `TabbyCatView.swift` 的
做法接进来；二是补充几张不同姿势（站/坐/走）的插画，做成姿势切换式动画，
没有连续的物理惯性感，但比纯静止好。

## 自主行为状态机（狸花猫）

`TabbyCatView.swift` 里的猫不是简单地"闲置就坐下"，而是有一套 `CatActivity` 状态机：

- 网络活跃时固定是 `.run`，真正快速奔跑（四条腿对角步态 + 弹跳 + 抖动，
  弹跳/抖动的正弦波叠加手法和小花狗的 `runningBounce` / `runningShake`
  同源，但猫多了真的腿部摆动，狗现在只有整体弹跳没有腿）；
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
