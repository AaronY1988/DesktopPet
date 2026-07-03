//
//  SpottedDogPet.swift
//  DesktopPet
//
//  小花狗角色实现——分层矢量部件版。用户提供的 SVG 插画已经用
//  tools/dog-rig/ 里的脚本拆成了独立部件（SpottedDogParts.swift）：
//  四条腿各分大腿/小腿两段（髋部+膝盖双关节）、头、双耳、尾巴、眼睛
//  都能单独驱动，奔跑步态/耳朵抽动/尾巴 spring 甩动/眨眼等局部动画
//  全部恢复，具体见 SpottedDogView.swift。
//
//  （旧版曾经是包装一整张 Assets.xcassets/SpottedDog 矢量插画，只能做
//  整图级别的缩放/位移；那套资源仍留在 asset catalog 里，代码已不再引用。）
//

import SwiftUI

struct SpottedDogPet: PetCharacter {
    let id = "dog"
    let displayName = "小花狗"
    // 画布 = 悬浮窗大小，必须容得下最坏情况的组合动作：
    // 肚子鼓胀（内存驱动）+ 奔跑弹跳/抖动 + 踱步位移 + 扑跪整体旋转
    // + 睡觉 z 字上飘。旧的 150x170 会在这些动作时裁掉头顶/耳朵/z 字，
    // 改成 190x205 后全部动作都有余量。
    let canvasSize = CGSize(width: 190, height: 205)
    let idleAnimation: PetIdleBehavior = .sit

    /// 小花狗的性格参数（见 PetPersonality.spottedDog）。拆件之后
    /// ear*/tail* 这些 spring 字段全部真正生效了：耳朵随机抽动、
    /// 尾巴 2 节链条滞后甩动。
    let personality: PetPersonality = .spottedDog

    func draw(metrics: PetMetrics) -> AnyView {
        AnyView(SpottedDogView(metrics: metrics, personality: personality))
    }

    /// 插画的配色固定在部件路径的填充色里（SpottedDogColors），
    /// 暂不随温度变化。保留这个方法只是为了满足协议。
    func colorForTemperature(_ celsius: Double?) -> Color {
        .white
    }
}
