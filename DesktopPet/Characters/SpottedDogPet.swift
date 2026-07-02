//
//  SpottedDogPet.swift
//  DesktopPet
//
//  小花狗角色实现——包装一整张用户提供的矢量插画（转成 PDF 放进
//  Assets.xcassets/SpottedDog.imageset，勾选了 Preserve Vector Data，
//  任意窗口缩放下都不会糊），取代了之前纯 SwiftUI Shape 手绘的
//  白色比熊犬。具体能保留 / 失去哪些动画效果，见 SpottedDogView.swift
//  开头的详细说明。
//

import SwiftUI

struct SpottedDogPet: PetCharacter {
    let id = "dog"
    let displayName = "小花狗"
    let canvasSize = CGSize(width: 150, height: 170)
    let idleAnimation: PetIdleBehavior = .sit

    /// 小花狗的性格参数（见 PetPersonality.spottedDog）：呼吸/重心微晃/
    /// 待机彩蛋摇晃复用了原来比熊那套数值，耳朵/尾巴 spring 相关字段
    /// 目前没有对应的可动部件，保留字段只是为了不用另外定义一套结构体。
    let personality: PetPersonality = .spottedDog

    func draw(metrics: PetMetrics) -> AnyView {
        AnyView(SpottedDogView(metrics: metrics, personality: personality))
    }

    /// 插画本身的颜色是画死在矢量图里的，代码这边没有接口能覆盖它的配色
    /// （除非以后换成能做颜色替换的格式，比如给关键色块加 Data Binding）。
    /// 保留这个方法只是为了满足协议，目前不生效。
    func colorForTemperature(_ celsius: Double?) -> Color {
        .white
    }
}
