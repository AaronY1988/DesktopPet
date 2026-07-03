//
//  PetCharacter.swift
//  DesktopPet
//
//  桌宠角色协议。所有角色（小花狗、狸花猫等）都实现这个协议，
//  窗口管理（FloatingPanel）、系统监控（SystemMonitor）、菜单栏（MenuBarController）
//  都只依赖这个协议，不感知具体角色的绘制细节，从而实现"新增角色只需新增一个
//  实现该协议的类型"的可扩展架构。
//

import SwiftUI

// 注意：这里刻意不继承 Identifiable。如果继承 Identifiable，
// `id` 会同时满足协议自身声明的 `String` 类型要求与 Identifiable 的
// `associatedtype ID` 要求，虽然这种写法在具体类型上没问题，
// 但会让 `any PetCharacter`（本项目在 AppState / PetContainerView 里
// 大量使用的存在型类型）的关联类型解析变得不必要地复杂。
// 由于本项目并不需要用 SwiftUI 的 ForEach 等依赖 Identifiable 的机制
// 来遍历角色列表（菜单栏选项是用固定的 (id, name) 元组数组生成的），
// 直接声明 `id: String` 更简单、更保险。
protocol PetCharacter {
    /// 角色唯一标识，用于菜单栏切换、UserDefaults 持久化选中状态
    var id: String { get }

    /// 显示在菜单栏"切换角色"子菜单中的名字
    var displayName: String { get }

    /// 角色推荐的画布尺寸，FloatingPanel 会据此设置悬浮窗大小
    var canvasSize: CGSize { get }

    /// 闲置（网络活跃度接近 0）时的待机行为语义
    var idleAnimation: PetIdleBehavior { get }

    /// "性格"参数：呼吸/眨眼/耳朵及尾巴 spring 的手感全部由这里驱动。
    /// 协议提供了默认实现（见下方 extension），新角色不特别定制的话
    /// 会拿到一套中性参数；想要独特手感就在具体类型里覆盖这个属性
    /// （SpottedDogPet / TabbyCatPet 都是这么做的）。
    var personality: PetPersonality { get }

    /// 根据当前系统指标绘制角色。
    /// 优先考虑用纯 SwiftUI `Shape` / `Canvas` 矢量绘制身体各部件
    /// （身体、肚子、腿、耳朵、尾巴等作为可独立驱动的子视图/子路径），
    /// 这样能拿到最丰富的局部动画。狸花猫 `TabbyCatView` 是手绘部件；
    /// 小花狗 `SpottedDogView` 则是把用户提供的整张 SVG 插画用脚本
    /// （tools/dog-rig/）拆成分层部件（见 `SpottedDogParts.swift`），
    /// 两条路最终都实现了逐部件驱动。
    /// 如果美术资源是一整张实在不可拆分的插画，也可以直接包装展示，
    /// 只是只能做"整张图"级别的变换（缩放/位移/旋转），拿不到局部动画。
    func draw(metrics: PetMetrics) -> AnyView

    /// 根据可选的 CPU 温度，返回角色主体应该呈现的颜色。
    /// 当前版本没有接入真实温度采集，传入 nil 时应返回角色的默认配色。
    func colorForTemperature(_ celsius: Double?) -> Color
}

/// 闲置状态下的行为语义。角色可以据此在网络活跃度极低时切换到
/// "坐下不动"或"缓慢踱步"两种待机形态，具体如何表现由角色自行实现。
enum PetIdleBehavior {
    case sit
    case slowWalk
}

// MARK: - personality 的协议默认实现

extension PetCharacter {
    /// 默认返回中性参数。IdleAnimator / SpringValue（见 Animation/ 目录）
    /// 都是两个角色共用的通用组件，真正让不同角色"手感不同"的
    /// 只有这里返回的 PetPersonality 取值——这正是题目要求的
    /// "放在协议默认实现里，两个角色复用，只通过 personality 覆盖参数"。
    var personality: PetPersonality { .neutral }
}
