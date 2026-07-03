//
//  DebugCompareView.swift
//  DesktopPet
//
//  调试用的"手感对比"预览：同时显示小花狗和小橘猫，并提供两个滑块手动
//  控制内存占用 / 网络活跃度这两个归一化指标，方便在不用真的去吃内存、
//  跑网速的情况下，直接对比两只宠物在同一组数值下的表现差异。
//
//  小花狗是分层矢量部件（SpottedDogParts.swift + SpottedDogView），四腿
//  双关节步态/耳朵抽动/尾巴 spring 甩动/眨眼齐全；小橘猫（TabbyCatView）
//  是六姿态循环 + 姿态内微动画（CatPoses.swift）。拖动网络滑块可以对比
//  两边的奔跑步态，放着不动可以对比各自的待机行为循环。
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
                        .frame(width: 190, height: 205) // 与 SpottedDogPet.canvasSize 一致
                        .background(Color(white: 0.97))
                        .cornerRadius(12)
                }

                VStack {
                    Text("小橘猫").font(.subheadline).foregroundColor(.secondary)
                    TabbyCatView(
                        metrics: metrics,
                        bodyColor: Color(red: 0.78, green: 0.70, blue: 0.58),
                        personality: .tabbyCat
                    )
                    .frame(width: 200, height: 185) // 与 TabbyCatPet.canvasSize 一致
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

            Text("小花狗：拆件骨骼动画（四腿双关节步态/尾巴 spring/甩头）；\n小橘猫：六姿态循环 + 姿态内微动画（尾巴/腿/舔毛爪子/眨眼）。\n放着不动可以对比两边的待机行为循环。")
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
