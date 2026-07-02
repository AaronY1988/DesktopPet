//
//  BichonPet.swift
//  DesktopPet
//
//  白色比熊犬（Bichon Frise）角色实现。
//  这是 PetCharacter 协议的第一个实现，其他角色（如 TabbyCatPet）
//  只需照着这个文件的结构，实现同样的协议成员即可，无需改动其他模块。
//

import SwiftUI

struct BichonPet: PetCharacter {
    let id = "bichon"
    let displayName = "比熊犬"
    let canvasSize = CGSize(width: 170, height: 150)
    let idleAnimation: PetIdleBehavior = .sit

    /// 比熊的性格参数：呼吸更明显、尾巴短蓬刚度高、偶尔甩头（见 PetPersonality.bichon）
    let personality: PetPersonality = .bichon

    func draw(metrics: PetMetrics) -> AnyView {
        AnyView(
            BichonView(
                metrics: metrics,
                bodyColor: colorForTemperature(metrics.cpuTemperature),
                personality: personality
            )
        )
    }

    /// 比熊本身是纯白色的，这里保留一个"温度越高越偏暖色"的插值效果，
    /// 用于未来接入真实 CPU 温度采集时可以直接生效；
    /// 目前 metrics.cpuTemperature 始终为 nil，因此始终呈现纯白。
    func colorForTemperature(_ celsius: Double?) -> Color {
        guard let celsius else { return .white }
        let t = min(max((celsius - 35) / (75 - 35), 0), 1)
        return Color(red: 1.0, green: 1.0 - 0.12 * t, blue: 1.0 - 0.4 * t)
    }
}
