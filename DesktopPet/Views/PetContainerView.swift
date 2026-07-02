//
//  PetContainerView.swift
//  DesktopPet
//
//  悬浮窗承载的顶层 SwiftUI 视图：订阅 SystemMonitor（系统指标）与
//  AppState（当前选中角色），把归一化后的 PetMetrics 交给角色去绘制。
//  这一层完全不关心某个具体角色是怎么画的，因此切换/新增角色不需要动这里。
//

import SwiftUI

struct PetContainerView: View {
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        let character = appState.currentCharacter()
        let metrics = PetMetrics.from(monitor: monitor)

        character.draw(metrics: metrics)
            .frame(width: character.canvasSize.width, height: character.canvasSize.height)
            // 整个容器背景保持透明，露出桌面
            .background(Color.clear)
    }
}
