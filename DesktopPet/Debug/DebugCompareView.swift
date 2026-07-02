//
//  DebugCompareView.swift
//  DesktopPet
//
//  调试用的"手感对比"预览：同时显示比熊和狸花猫，并提供两个滑块手动
//  控制内存占用 / 网络活跃度这两个归一化指标，方便在不用真的去吃内存、
//  跑网速的情况下，直接对比两只宠物在同一组数值下的呼吸节奏、眨眼频率、
//  耳朵抽动手感、尾巴甩动软硬程度差异——这正是 PetPersonality.bichon
//  与 .tabbyCat 两套参数想要体现的差异。
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
                    Text("比熊犬").font(.subheadline).foregroundColor(.secondary)
                    BichonView(metrics: metrics, bodyColor: .white, personality: .bichon)
                        .frame(width: 170, height: 150)
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
                    Text("内存占用（肚子大小）：\(Int(memoryFraction * 100))%")
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

            Text("两只宠物共用同一套 IdleAnimator / SpringValue 组件，\n手感差异完全来自 PetPersonality.bichon 与 .tabbyCat 的参数取值。")
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
