//
//  FloatingPanel.swift
//  DesktopPet
//
//  承载桌宠的悬浮透明窗口。使用 NSPanel 而不是普通 NSWindow，
//  是因为 NSPanel 更适合做"永远浮在最上层、不参与常规窗口循环、
//  不需要成为 key window"的辅助型窗口。
//

import AppKit
import SwiftUI

/// 自定义 NSPanel：
/// - `.nonactivatingPanel`：点击宠物不会把本 App 激活到前台 / 抢占其他 App 的焦点
/// - `canBecomeKey = false`：宠物窗口本身不接受键盘输入，避免误抢首个 responder
/// - 依然支持通过拖拽窗口背景来移动位置（`isMovableByWindowBackground`）
final class FloatingPetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 悬浮窗控制器：负责创建/配置 FloatingPetPanel，并把 SwiftUI 内容
/// 通过 NSHostingView 挂载进去。
/// 继承 NSObject 是必须的：下面用 `NotificationCenter.addObserver(_:selector:...)`
/// 监听窗口移动事件，selector 派发依赖 Objective-C 运行时，
/// 观察者必须是 NSObject 的子类，否则 `@objc` 方法无法被正确调用。
final class FloatingPanelController: NSObject {

    private(set) var panel: FloatingPetPanel!
    private var hostingView: NSHostingView<PetContainerView>?
    private let positionDefaultsKey = "DesktopPet.windowOrigin"

    /// 创建并展示悬浮窗。
    /// - Parameter size: 初始内容尺寸，通常取自当前角色的 `canvasSize`。
    func setup(contentSize: CGSize) {
        let panel = FloatingPetPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            // .borderless：无标题栏、无边框，只显示自定义内容
            // .nonactivatingPanel：不参与常规的应用激活/窗口层级循环
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // --- 透明悬浮窗的核心配置（对应需求逐项设置） ---
        panel.isOpaque = false                         // 允许透明
        panel.backgroundColor = .clear                 // 背景透明，只露出宠物本身
        panel.hasShadow = false                         // 阴影由角色视图自己画（更可控）
        panel.level = .floating                         // 悬浮在大多数普通窗口之上
        panel.isMovableByWindowBackground = true         // 支持拖拽窗口本体来移动宠物
        panel.ignoresMouseEvents = false                 // 默认拦截鼠标（可通过菜单切换成穿透）

        // 允许在所有 Space 间跟随显示，并可以叠加在全屏 App 之上
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary // 切换 Space 时不跟随触发动画，直接静止显示在当前 Space
        ]

        panel.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: PetContainerView())
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.hostingView = hosting

        self.panel = panel

        restorePositionOrDefault(size: contentSize)
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    /// 切换鼠标点击穿透：开启后宠物窗口不拦截任何鼠标事件，
    /// 方便宠物"趴"在其他窗口上层时不影响下方 App 的操作。
    func setIgnoresMouseEvents(_ ignores: Bool) {
        panel.ignoresMouseEvents = ignores
    }

    /// 角色切换后画布尺寸可能变化，重新设置窗口内容大小（保持左上角位置不变）。
    func updateContentSize(_ size: CGSize) {
        guard let panel else { return }
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true)
        hostingView?.frame = NSRect(origin: .zero, size: size)
    }

    // MARK: - 位置持久化

    @objc private func windowDidMove() {
        guard let origin = panel?.frame.origin else { return }
        let dict = ["x": origin.x, "y": origin.y]
        UserDefaults.standard.set(dict, forKey: positionDefaultsKey)
    }

    private func restorePositionOrDefault(size: CGSize) {
        if let saved = UserDefaults.standard.dictionary(forKey: positionDefaultsKey) as? [String: CGFloat],
           let x = saved["x"], let y = saved["y"] {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        // 默认放在主屏幕右下角附近
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - size.width - 40,
                y: visible.minY + 60
            )
            panel.setFrameOrigin(origin)
        }
    }
}
