//
//  AppState.swift
//  DesktopPet
//
//  管理"当前选中角色"这一全局状态，并提供角色注册表。
//  新增角色时（`SpottedDogPet` / `TabbyCatPet` 就是两个已经接入的例子），只需：
//    1. 实现一个新的 `XxxPet: PetCharacter`
//    2. 在 `availableCharacters` 中追加一项 (id, 显示名)
//    3. 在 `character(for:)` 的 switch 中追加一个分支
//  菜单栏、悬浮窗渲染代码都不需要任何改动。
//

import Foundation

final class AppState: ObservableObject {
    static let shared = AppState()

    private static let storageKey = "DesktopPet.selectedCharacterID"

    /// 当前选中的角色 ID，会持久化到 UserDefaults，下次启动自动恢复。
    @Published var selectedCharacterID: String {
        didSet { UserDefaults.standard.set(selectedCharacterID, forKey: Self.storageKey) }
    }

    /// 是否忽略鼠标事件（点击穿透）。开启后悬浮窗不会拦截鼠标点击/拖动，
    /// 方便宠物"趴"在其他窗口上层时不影响操作。
    @Published var ignoresMouseEvents: Bool = false

    /// 角色注册表：菜单栏"切换角色"子菜单据此生成选项。
    static let availableCharacters: [(id: String, name: String)] = [
        (id: "dog", name: "小花狗"),
        (id: "cat", name: "狸花猫"),
    ]

    private init() {
        selectedCharacterID = UserDefaults.standard.string(forKey: Self.storageKey) ?? "dog"
    }

    /// 返回当前选中角色的具体实现实例。
    func currentCharacter() -> any PetCharacter {
        Self.character(for: selectedCharacterID)
    }

    /// 根据 ID 构造角色实例。新增角色时在这里追加分支。
    static func character(for id: String) -> any PetCharacter {
        switch id {
        case "dog":
            return SpottedDogPet()
        case "cat":
            return TabbyCatPet()
        default:
            return SpottedDogPet()
        }
    }
}
