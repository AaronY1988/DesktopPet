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
//  关于"背景色"和"狗的大小"（2026-07-02 补充）：
//  - dog.riv 这个 artboard 本身画了一块紫色/淡蓝紫色的背景矩形（不是代码
//    加的、也不是窗口没做透明），这块颜色是画在 Rive 素材内部的，Fit /
//    Alignment 这些运行时布局参数只能控制"artboard 在 view 里怎么缩放/
//    裁切"，没法单独隐藏 artboard 内部的某一层。想让宠物窗口保持透明背景，
//    需要回到 Rive 编辑器里把这个背景矩形删掉（或者把它的 Fill 透明度调成
//    0）再重新导出 dog.riv 覆盖 Resources/dog.riv，不需要改这份代码；
//    图层名字在 strings 里没扫到明显叫 "background" 的东西，需要你在编辑器
//    的 Hierarchy 面板里点开 Hond 这个 artboard 手动找一下。
//  - "狗看起来太小"这一半是能靠代码解决的：默认的 `fit` 是 `.contain`
//    （官方文档 Layout 一节里写的默认值），会把整个 artboard（含背景矩形
//    的留白）完整塞进 170×150 的画布，四周留白多、狗自然显得小。改成
//    `.cover`（同一份文档里确认的合法取值：.fill/.contain/.cover/
//    .fitWidth/.fitHeight/.scaleDown/.noFit）会按小边对齐、裁掉多余部分，
//    相当于把画面放大到填满画布，狗会明显变大，代价是背景矩形边缘会被
//    裁掉一部分而不是完全消失。

import SwiftUI
import RiveRuntime

struct BichonView: View {
    let metrics: PetMetrics
    let personality: PetPersonality

    /// 用 @StateObject 保证同一个 Rive 实例在 body 反复求值时不会被重新创建
    /// （不然每次系统指标刷新都会重新加载一次 .riv 文件）。
    /// fit: .cover 是让狗看起来更大的关键——具体原理见上面文件头注释。
    @StateObject private var riveViewModel = RiveViewModel(
        fileName: "dog",
        animationName: "dog-walk-cycle",
        fit: .cover
    )

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
