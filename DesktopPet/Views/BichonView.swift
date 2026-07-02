//
//  BichonView.swift
//  DesktopPet
//
//  比熊犬视图——包装 `Resources/dog.riv`（Rive 素材），不再是纯 SwiftUI
//  矢量绘制。dog.riv 是一个叫 "Hond" 的角色，里面有：
//  - 一段循环走路时间轴动画 `dog-walk-cycle`
//  - 一个 State Machine（点击耳朵/尾巴/舌头触发反应动画），这一版暂时没用上
//
//  和系统指标的对应关系（当前版本，比之前矢量版简化很多）：
//  - 网络空闲 -> 暂停走路动画（站定不动）；网络有活动 -> 播放走路循环。
//    用的是 `RiveViewModel.play() / .pause()`，这两个方法在 Rive 官方文档
//    "Playing / Pausing" 一节里有明确示例，可以放心用。
//  - "网速越快、走得越快"（连续调速）目前 **没有实现**：Rive 的旧版
//    RiveViewModel 有没有直接暴露"播放速度倍率"这个属性，官方文档和能
//    搜到的资料里都没有给出确切签名，我没办法在没有编译器的环境里瞎猜
//    一个可能不存在的 API、写出编译不过的代码。等你在 Xcode 里把
//    RiveRuntime 包加进来之后，麻烦 Cmd+click 点进 `RiveViewModel`
//    （或者直接看 https://github.com/rive-app/rive-ios 源码）确认一下
//    有没有类似 `speed` / `setSpeed` 的成员，告诉我，我再把这段接上。
//  - "内存越大肚子越大"这个效果这一版**没有实现**：dog.riv 里没有对应
//    肚子的可控参数（不是 State Machine Number 输入），需要重新在 Rive
//    编辑器里加一个才能连续驱动，见和你聊过的备选方案。
//

import SwiftUI
import RiveRuntime

struct BichonView: View {
    let metrics: PetMetrics
    let personality: PetPersonality

    /// 用 @StateObject 保证同一个 Rive 实例在 body 反复求值时不会被重新创建
    /// （不然每次系统指标刷新都会重新加载一次 .riv 文件）。
    @StateObject private var riveViewModel = RiveViewModel(fileName: "dog", animationName: "dog-walk-cycle")

    private let idleThreshold = 0.04
    private var isIdle: Bool { metrics.networkActivity < idleThreshold }

    var body: some View {
        riveViewModel.view()
            .frame(width: 170, height: 150)
            .onChange(of: isIdle) { nowIdle in
                if nowIdle {
                    riveViewModel.pause()
                } else {
                    riveViewModel.play()
                }
            }
            .onAppear {
                if isIdle {
                    riveViewModel.pause()
                }
            }
    }
}
