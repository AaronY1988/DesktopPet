//
//  LoginItemManager.swift
//  DesktopPet
//
//  开机自启动管理，基于 macOS 13+ 引入的 `SMAppService` API
//  （比旧版 `SMLoginItemSetEnabled` / 手动写登录项 plist 的方式更简单，
//  也是当前 Apple 推荐的做法）。
//
//  权限说明：`SMAppService.mainApp` 注册的是"主 App 自身"作为登录项，
//  不需要单独的 Login Item Helper 目标，也不需要申请额外 entitlement；
//  用户可以随时在"系统设置 > 通用 > 登录项与扩展"里看到并手动关闭。
//

import ServiceManagement
import Foundation

enum LoginItemManager {
    /// 当前是否已注册为登录项
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 注册 / 取消注册开机自启动
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // 常见失败原因：App 未签名 / 未安装到 /Applications 下、
            // 用户在系统设置里手动禁用过。这里只打日志，不打断主流程。
            print("[DesktopPet] 设置开机自启失败: \(error)")
        }
    }
}
