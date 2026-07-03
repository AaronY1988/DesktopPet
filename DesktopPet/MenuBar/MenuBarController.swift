//
//  MenuBarController.swift
//  DesktopPet
//
//  菜单栏控制器。由于 App 没有 Dock 图标（LSUIElement / .accessory），
//  菜单栏是用户与 App 交互的唯一入口：退出、开机自启开关、切换角色、
//  切换鼠标点击穿透。
//

import AppKit
import Combine
import SwiftUI

final class MenuBarController: NSObject, NSMenuDelegate {

    /// 角色子菜单每次展开前刷新勾选状态，保证与 AppState 一致
    func menuNeedsUpdate(_ menu: NSMenu) {
        let selectedID = AppState.shared.selectedCharacterID
        for item in menu.items {
            guard let id = item.representedObject as? String else { continue }
            item.state = (id == selectedID) ? .on : .off
        }
    }

    private var statusItem: NSStatusItem!
    private let panelController: FloatingPanelController
    private var cancellables = Set<AnyCancellable>()

    /// 调试对比窗口的强引用：不持有的话窗口关闭后 NSWindow 会被立刻释放。
    /// 这个窗口和正式的悬浮宠物窗口（FloatingPanelController 管理的那个）
    /// 完全独立，只是开发者/用户想直接对比两只宠物手感时用一下，随时可关。
    private var debugCompareWindow: NSWindow?

    init(panelController: FloatingPanelController) {
        self.panelController = panelController
        super.init()
        setupStatusItem()
        observeCharacterChanges()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            // 使用系统 SF Symbol 做菜单栏图标，避免额外引入图片资源
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "DesktopPet")
        }
        statusItem.menu = buildMenu(selectedID: AppState.shared.selectedCharacterID)
    }

    private func buildMenu(selectedID: String) -> NSMenu {
        let menu = NSMenu()

        // --- 切换角色 ---
        let characterItem = NSMenuItem(title: "切换角色", action: nil, keyEquivalent: "")
        let characterSubmenu = NSMenu()
        // delegate 让子菜单每次展开前都按 AppState 刷新勾选，
        // 即使中途有其他路径改了选中角色，菜单也不会显示过期状态
        characterSubmenu.delegate = self
        for entry in AppState.availableCharacters {
            let item = NSMenuItem(title: entry.name, action: #selector(selectCharacter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id
            item.state = (entry.id == selectedID) ? .on : .off
            characterSubmenu.addItem(item)
        }
        characterItem.submenu = characterSubmenu
        menu.addItem(characterItem)

        menu.addItem(.separator())

        // --- 鼠标点击穿透 ---
        let clickThroughItem = NSMenuItem(
            title: "鼠标点击穿透",
            action: #selector(toggleClickThrough(_:)),
            keyEquivalent: ""
        )
        clickThroughItem.target = self
        clickThroughItem.state = AppState.shared.ignoresMouseEvents ? .on : .off
        menu.addItem(clickThroughItem)

        // --- 开机自启 ---
        let loginItem = NSMenuItem(
            title: "开机自动启动",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LoginItemManager.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // --- 调试：手感对比预览 ---
        let debugCompareItem = NSMenuItem(
            title: "调试：手感对比预览",
            action: #selector(openDebugCompareWindow),
            keyEquivalent: ""
        )
        debugCompareItem.target = self
        menu.addItem(debugCompareItem)

        menu.addItem(.separator())

        // --- 退出 ---
        let quitItem = NSMenuItem(title: "退出 DesktopPet", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// 切换角色后：重新生成菜单（更新勾选状态）+ 通知悬浮窗更新画布尺寸。
    ///
    /// ⚠️ @Published 是在 willSet 阶段发布的：sink 回调执行时
    /// `AppState.shared.selectedCharacterID` 还是旧值！之前这里直接读
    /// 属性，导致菜单勾选滞后一步、悬浮窗按旧角色的画布改尺寸——
    /// 就是"切换时有点混乱"的根源。必须用回调参数里的新值。
    private func observeCharacterChanges() {
        AppState.shared.$selectedCharacterID
            .dropFirst()
            .sink { [weak self] newID in
                guard let self else { return }
                self.statusItem.menu = self.buildMenu(selectedID: newID)
                self.panelController.updateContentSize(AppState.character(for: newID).canvasSize)
            }
            .store(in: &cancellables)
    }

    @objc private func selectCharacter(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AppState.shared.selectedCharacterID = id
    }

    @objc private func toggleClickThrough(_ sender: NSMenuItem) {
        let newValue = !AppState.shared.ignoresMouseEvents
        AppState.shared.ignoresMouseEvents = newValue
        panelController.setIgnoresMouseEvents(newValue)
        sender.state = newValue ? .on : .off
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let newValue = !LoginItemManager.isEnabled
        LoginItemManager.setEnabled(newValue)
        sender.state = LoginItemManager.isEnabled ? .on : .off
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 打开（或重新激活）"手感对比预览"调试窗口。这个窗口是一个普通的
    /// 有边框、可关闭的 NSWindow，和无边框透明的悬浮宠物窗口是两套独立
    /// 的窗口体系，互不影响；LSUIElement 应用一样可以正常显示普通窗口。
    @objc private func openDebugCompareWindow() {
        if let window = debugCompareWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: DebugCompareView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "调试：手感对比预览"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        debugCompareWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
