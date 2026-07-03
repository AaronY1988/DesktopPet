//
//  TabbyCatPet.swift
//  DesktopPet
//
//  小橘猫角色实现（id 沿用 "cat"，用户已持久化的选择不受影响）。
//  造型来自用户提供的六姿态参考图，逐个矢量化后按时间循环切换姿态，
//  数据在 CatPoses.swift（由 tools/cat-rig/ 生成），渲染与状态机在
//  TabbyCatView.swift。文件名/类型名沿用旧的 TabbyCat 前缀，避免
//  牵连改动工程注册与调用方。
//

import SwiftUI

struct TabbyCatPet: PetCharacter {
    let id = "cat"
    let displayName = "小橘猫"
    // 画布 = 悬浮窗大小，必须容得下最坏情况的组合动作（内存缩放 1.18×
    // 后猫高 159、比旧画布 150 还高，再叠加弹跳/踱步/wiggle/z 字）。
    // 旧的 170x150 会在这些动作时裁掉头顶，改成 200x185 后全有余量。
    let canvasSize = CGSize(width: 200, height: 185)
    let idleAnimation: PetIdleBehavior = .slowWalk

    /// 猫的性格参数：呼吸沉稳、眨眼频繁、尾巴长且软（见 PetPersonality.tabbyCat）
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

    /// 新版配色描摹自参考图、固定在 CatColors 里，这个方法只为满足协议保留
    /// （bodyColor 参数在 TabbyCatView 里已不再使用）。
    func colorForTemperature(_ celsius: Double?) -> Color {
        Color(red: 0.992, green: 0.957, blue: 0.902)
    }
}
