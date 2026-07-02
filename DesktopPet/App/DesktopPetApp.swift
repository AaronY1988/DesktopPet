//
//  DesktopPetApp.swift
//  DesktopPet
//
//  App 入口。真正的界面（悬浮透明窗口 + 菜单栏）由 AppDelegate 手动创建，
//  这里只是 SwiftUI App 协议要求的最小占位。
//

import SwiftUI

@main
struct DesktopPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI 的 App 协议要求至少提供一个 Scene，
        // 但本 App 不需要任何标准窗口/文档窗口，
        // 用一个空的 Settings 场景占位即可（不会弹出任何界面）。
        Settings {
            EmptyView()
        }
    }
}
