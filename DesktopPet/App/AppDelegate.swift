//
//  AppDelegate.swift
//  DesktopPet
//
//  应用启动入口：配置无 Dock 图标的运行模式，创建悬浮窗与菜单栏，
//  启动系统指标采集。
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panelController: FloatingPanelController!
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 不显示 Dock 图标、不出现在 Cmd+Tab 应用切换器里，只保留菜单栏入口。
        // 与 Info.plist 中的 LSUIElement = YES 是同一件事的两种设置方式，
        // 这里显式再设置一遍以确保在各种启动路径下都生效。
        NSApp.setActivationPolicy(.accessory)

        panelController = FloatingPanelController()
        panelController.setup(contentSize: AppState.shared.currentCharacter().canvasSize)
        panelController.setIgnoresMouseEvents(AppState.shared.ignoresMouseEvents)

        menuBarController = MenuBarController(panelController: panelController)

        SystemMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SystemMonitor.shared.stop()
    }

    /// 保留窗口的可恢复状态支持（macOS 建议显式声明）
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
