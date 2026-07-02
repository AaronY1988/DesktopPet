//
//  TabbyCatPet.swift
//  DesktopPet
//
//  狸花猫（Chinese tabby cat）角色实现。和 BichonPet 一样实现 PetCharacter
//  协议，是"新增角色只需照着已有实现抄一遍协议成员"这条约定的第二个例子。
//

import SwiftUI

struct TabbyCatPet: PetCharacter {
    let id = "cat"
    let displayName = "狸花猫"
    let canvasSize = CGSize(width: 170, height: 150)
    let idleAnimation: PetIdleBehavior = .slowWalk

    /// 猫的性格参数：呼吸更沉稳、眨眼更频繁、耳朵更挺、尾巴长且软（见 PetPersonality.tabbyCat）
    let personality: PetPersonality = .tabbyCat

    func draw(metrics: PetMetrics) -> AnyView {
        AnyView(
            TabbyCatView(
                metrics: metrics,
                bodyColor: colorForTemperature(metrics.cpuTemperature),
                personality: personality
            )
        )
    }

    /// 狸花猫的底色是偏暖的灰棕色，温度越高，颜色越往暖橙色偏移。
    func colorForTemperature(_ celsius: Double?) -> Color {
        let base = Color(red: 0.78, green: 0.70, blue: 0.58)
        guard let celsius else { return base }
        let t = min(max((celsius - 35) / (75 - 35), 0), 1)
        return Color(red: 0.78 + 0.14 * t, green: 0.70 - 0.05 * t, blue: 0.58 - 0.18 * t)
    }
}
