//
//  DebugCompareView.swift
//  DesktopPet
//
//  调试用的"手感对比"预览：同时显示小花狗和狸花猫，并提供两个滑块手动
//  控制内存占用 / 网络活跃度这两个归一化指标，方便在不用真的去吃内存、
//  跑网速的情况下，直接对比两只宠物在同一组数值下的表现差异。
//
//  小花狗现在是整张矢量插画（SpottedDogView），没有耳朵抽动/尾巴甩动这些
//  局部动画了，能对比的只剩呼吸节奏、待机摇晃、奔跑弹跳/抖动这些"整只
//  宠物一起动"的效果；狸花猫（TabbyCatView）仍然是逐部件手绘，两边不再
//  是完全对等的比较，这里主要用来看猫的 PetPersonality.tabbyCat 参数。
//
//  用法一：在 Xcode 里直接打开这个文件，用画布左下角的 Preview 就能看到；
//  用法二：运行 App 之后，从菜单栏选择"调试：手感对比预览"打开一个独立
//  的悬浮窗口（见 MenuBarController 里新增的 openDebugCompareWindow）。
//
//  这个视图完全独立于正式的悬浮窗渲染路径（PetContainerView），
//  不会影响 App 正常运行时的外观和性能。
//

import SwiftUI

struct DebugCompareView: View {
    @State private var memoryFraction: Double = 0.3
    @State private var networkActivity: Double = 0.0

    private var metrics: PetMetrics {
        PetMetrics(memoryFraction: memoryFraction, networkActivity: networkActivity)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("待机 / spring 手感对比")
                .font(.headline)

            HStack(alignment: .top, spacing: 40) {
                VStack {
                    Text("小花狗").font(.subheadline).foregroundColor(.secondary)
                    SpottedDogView(metrics: metrics, personality: .spottedDog)
                        .frame(width: 150, height: 170)
                        .background(Color(white: 0.97))
                        .cornerRadius(12)
                }

                VStack {
                    Text("狸花猫").font(.subheadline).foregroundColor(.secondary)
                    TabbyCatView(
                        metrics: metrics,
                        bodyColor: Color(red: 0.78, green: 0.70, blue: 0.58),
                        personality: .tabbyCat
                    )
                    .frame(width: 170, height: 150)
                    .background(Color(white: 0.97))
                    .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading) {
                    Text("内存占用（体型大小）：\(Int(memoryFraction * 100))%")
                        .font(.caption)
                    Slider(value: $memoryFraction, in: 0...1)
                }
                VStack(alignment: .leading) {
                    Text("网络活跃度（奔跑/自主行为强度）：\(Int(networkActivity * 100))%")
                        .font(.caption)
                    Slider(value: $networkActivity, in: 0...1)
                }
            }
            .frame(width: 320)

            Text("小花狗是矢量插画整体驱动（呼吸/待机摇晃/奔跑弹跳），\n狸花猫仍然是 IdleAnimator / SpringValue 驱动的逐部件矢量绘制，\n两边手感不再直接可比，这里主要用来看猫的 PetPersonality.tabbyCat 参数。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(minWidth: 420, minHeight: 460)
    }
}

#Preview {
    DebugCompareView()
}
