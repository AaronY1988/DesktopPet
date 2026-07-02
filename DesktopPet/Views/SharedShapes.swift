//
//  SharedShapes.swift
//  DesktopPet
//
//  两个角色共用的纯矢量 Shape 定义。之所以单独拆出一个文件，是因为
//  BichonPet 换成 Rive 驱动之后，BichonView.swift 本身不再需要这些
//  形状了，但 TabbyCatView.swift 的身体/头部轮廓（FluffyBlobShape）
//  和奔跑冒汗特效（SweatDropShape）仍然依赖它们——拆到独立文件，
//  避免"猫的绘制依赖一个几乎已经空了的比熊文件"这种别扭的耦合。
//

import SwiftUI

// MARK: - 蓬松轮廓 Shape

/// 通用的"蓬松云朵状"轮廓 Shape，通过在椭圆边缘叠加正弦波纹模拟卷毛/绒毛质感，
/// 目前狸花猫的身体、头部轮廓基于这一个 Shape 参数化生成，不需要任何位图资源。
struct FluffyBlobShape: Shape {
    /// 边缘凸起的数量（卷毛簇的数量）
    var bumpCount: Int = 10
    /// 凸起深度，相对半径的比例。数值越小卷毛质感越细腻柔和，
    /// 数值越大越像锯齿/星星。
    var bumpDepth: CGFloat = 0.06

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        var path = Path()

        let samples = max(bumpCount * 8, 64)
        for i in 0...samples {
            let angle = (CGFloat(i) / CGFloat(samples)) * 2 * .pi
            let bump = 1 + sin(angle * CGFloat(bumpCount)) * bumpDepth
            let point = CGPoint(
                x: center.x + radiusX * bump * cos(angle),
                y: center.y + radiusY * bump * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// 一滴"汗水"的水滴形状：顶部尖、底部圆，经典卡通汗滴造型。
/// 给跑得很拼命（吐舌头喘气）的角色用。
struct SweatDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + height * 0.55),
            control: CGPoint(x: rect.maxX, y: rect.minY + height * 0.12)
        )
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + height * 0.62),
            radius: width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY + height * 0.12)
        )
        path.closeSubpath()
        return path
    }
}
