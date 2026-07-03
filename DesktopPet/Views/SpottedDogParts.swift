//
//  SpottedDogParts.swift
//  DesktopPet
//
//  小花狗的分层矢量部件——由 tools/dog-rig/dogparts.py 从用户提供的原始
//  SVG 插画自动拆解生成（原图里头/身体/四条腿是一条画死的大路径，
//  脚本用 de Casteljau 在髋部/膝盖处精确切开贝塞尔边，并给每个关节
//  加了"以关节为圆心的半圆帽"，保证任意旋转角度下部件之间都不露缝）。
//
//  坐标全部保留在原 SVG 的 180.03 x 203.21 viewBox 空间里；每个部件的
//  Shape 都按整张画布等比缩放绘制，因此旋转锚点直接用
//  SpottedDogRig.anchor(_:) 把 viewBox 坐标换算成 UnitPoint 即可。
//
//  ⚠️ 数值请勿手改——想调整拆分方式请改生成脚本后重新生成。
//

import SwiftUI

// MARK: - 骨骼（关节支点，viewBox 坐标）

enum SpottedDogRig {
    static let viewW: CGFloat = 180.03
    static let viewH: CGFloat = 203.21

    static let neck = CGPoint(x: 30, y: 74)
    static let earFloppy = CGPoint(x: 31, y: 15)
    static let earSmall = CGPoint(x: 46.5, y: 11.5)
    static let tail = CGPoint(x: 121, y: 101.5)
    static let hipFrontFar = CGPoint(x: 15, y: 150)
    static let hipFrontNear = CGPoint(x: 40, y: 150)
    static let hipRearNear = CGPoint(x: 133.5, y: 142)
    static let hipRearFar = CGPoint(x: 113, y: 158)
    static let kneeFrontFar = CGPoint(x: 13.76, y: 178)
    static let kneeFrontNear = CGPoint(x: 40.38, y: 180)
    static let kneeRearNear = CGPoint(x: 132.76, y: 183)
    static let kneeRearFar = CGPoint(x: 112.43, y: 184)
    static let eyeCenter = CGPoint(x: 57.58, y: 38.3)

    /// viewBox 坐标 -> rotationEffect 用的 UnitPoint 锚点
    static func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: p.x / viewW, y: p.y / viewH)
    }
}

// MARK: - 配色（原 SVG 的 class 色板）

enum SpottedDogColors {
    static let cream      = Color(red: 0.914, green: 0.812, blue: 0.725) // #e9cfb9 主体
    static let creamDark  = Color(red: 0.757, green: 0.678, blue: 0.608) // #c1ad9b 远侧后腿
    static let orange     = Color(red: 0.714, green: 0.365, blue: 0.176) // #b65d2d 斑块/耳朵/尾巴
    static let darkBrown  = Color(red: 0.447, green: 0.173, blue: 0.106) // #722c1b 鼻子/尾巴纹理
    static let deepBrown  = Color(red: 0.376, green: 0.153, blue: 0.141) // #602724 瞳孔/嘴线
    static let shade      = Color(red: 0.545, green: 0.227, blue: 0.133) // #8b3a22 阴影叠层
    static let blushPink  = Color(red: 0.945, green: 0.675, blue: 0.592) // #f1ac97 腮红
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - 部件路径（viewBox 空间，静态构建一次）

enum SpottedDogPaths {
    static let tail: Path = {
        var p = Path()
        p.move(to: P(117.28, 99.74))
        p.addCurve(to: P(150.24, 96.34), control1: P(128.34, 101.37), control2: P(139.87, 101.52))
        p.addCurve(to: P(171.06, 65.65), control1: P(160.61, 91.16), control2: P(169.62, 79.72))
        p.addCurve(to: P(172.91, 61.7), control1: P(171.23, 64), control2: P(171.62, 61.89))
        p.addCurve(to: P(174.94, 63.08), control1: P(173.7, 61.59), control2: P(174.4, 62.33))
        p.addCurve(to: P(178.96, 80.37), control1: P(178.26, 67.65), control2: P(179.79, 74.23))
        p.addCurve(to: P(170.62, 94.94), control1: P(178.13, 86.51), control2: P(174.95, 92.06))
        p.addCurve(to: P(180.02, 93.74), control1: P(173.75, 94.54), control2: P(176.88, 94.14))
        p.addCurve(to: P(166.92, 103.89), control1: P(178.12, 100.34), control2: P(172.4, 104.78))
        p.addCurve(to: P(174.8, 109.25), control1: P(169.78, 104.4), control2: P(172.81, 106.58))
        p.addCurve(to: P(155.48, 112.37), control1: P(168.7, 112.34), control2: P(161.99, 113.43))
        p.addCurve(to: P(159.84, 117.79), control1: P(157.68, 111.91), control2: P(159.69, 114.95))
        p.addCurve(to: P(136.55, 116.47), control1: P(152.46, 121.65), control2: P(143.92, 120.34))
        p.addCurve(to: P(117.27, 99.75), control1: P(129.18, 112.6), control2: P(123.61, 105.9))
        p.closeSubpath()
        return p
    }()

    static let tailDetail: Path = {
        var p = Path()
        p.move(to: P(140.55, 108.3))
        p.addCurve(to: P(130.52, 106.76), control1: P(136.71, 108.3), control2: P(133.41, 107.79))
        p.addCurve(to: P(130.22, 106.13), control1: P(130.27, 106.67), control2: P(130.13, 106.39))
        p.addCurve(to: P(130.85, 105.83), control1: P(130.31, 105.88), control2: P(130.59, 105.75))
        p.addCurve(to: P(143.45, 107.22), control1: P(134.33, 107.07), control2: P(138.45, 107.53))
        p.addCurve(to: P(146.26, 106.63), control1: P(144.42, 107.16), control2: P(145.44, 107.07))
        p.addCurve(to: P(147.55, 104.62), control1: P(146.94, 106.27), control2: P(147.63, 105.49))
        p.addCurve(to: P(147.35, 104.08), control1: P(147.53, 104.43), control2: P(147.46, 104.25))
        p.addCurve(to: P(145.65, 103.59), control1: P(146.77, 103.96), control2: P(146.21, 103.79))
        p.addCurve(to: P(145.33, 103.16), control1: P(145.47, 103.52), control2: P(145.34, 103.35))
        p.addCurve(to: P(145.6, 102.7), control1: P(145.32, 102.96), control2: P(145.43, 102.78))
        p.addCurve(to: P(147.34, 102.8), control1: P(146.13, 102.44), control2: P(146.77, 102.47))
        p.addCurve(to: P(147.87, 103.2), control1: P(147.54, 102.91), control2: P(147.72, 103.05))
        p.addCurve(to: P(161, 98.24), control1: P(152.68, 104.11), control2: P(158.01, 102.14))
        p.addLine(to: P(157.75, 98.42))
        p.addCurve(to: P(157.27, 98.02), control1: P(157.51, 98.42), control2: P(157.31, 98.25))
        p.addCurve(to: P(157.61, 97.47), control1: P(157.23, 97.78), control2: P(157.37, 97.54))
        p.addCurve(to: P(165.08, 89.55), control1: P(161.24, 96.35), control2: P(164.17, 93.24))
        p.addCurve(to: P(165.67, 89.19), control1: P(165.15, 89.29), control2: P(165.42, 89.13))
        p.addCurve(to: P(166.03, 89.78), control1: P(165.93, 89.25), control2: P(166.09, 89.52))
        p.addCurve(to: P(160.37, 97.3), control1: P(165.26, 92.92), control2: P(163.14, 95.67))
        p.addLine(to: P(161.95, 97.22))
        p.addCurve(to: P(162.4, 97.46), control1: P(162.12, 97.19), control2: P(162.31, 97.3))
        p.addCurve(to: P(162.39, 97.97), control1: P(162.49, 97.62), control2: P(162.49, 97.81))
        p.addCurve(to: P(148.48, 104.29), control1: P(159.49, 102.5), control2: P(153.77, 104.97))
        p.addCurve(to: P(148.52, 104.55), control1: P(148.5, 104.37), control2: P(148.51, 104.46))
        p.addCurve(to: P(146.71, 107.51), control1: P(148.64, 105.87), control2: P(147.7, 106.99))
        p.addCurve(to: P(143.5, 108.21), control1: P(145.71, 108.04), control2: P(144.57, 108.15))
        p.addCurve(to: P(140.54, 108.3), control1: P(142.48, 108.27), control2: P(141.49, 108.3))
        p.closeSubpath()
        return p
    }()

    static let farRearThigh: Path = {
        var p = Path()
        p.move(to: P(108.99, 160.31))
        p.addCurve(to: P(108.25, 184), control1: P(108.83, 166.6), control2: P(108.66, 175.9))
        p.addCurve(to: P(116.62, 184), control1: P(108.25, 189.58), control2: P(116.62, 189.58))
        p.addCurve(to: P(118.93, 158), control1: P(117.42, 174.95), control2: P(118.24, 165.64))
        p.addCurve(to: P(108.99, 160.31), control1: P(117.39, 151.38), control2: P(107.45, 153.69))
        p.closeSubpath()
        return p
    }()

    static let farRearShank: Path = {
        var p = Path()
        p.move(to: P(108.25, 184))
        p.addCurve(to: P(107.55, 193.54), control1: P(108.07, 187.52), control2: P(107.84, 190.82))
        p.addCurve(to: P(99.42, 196.02), control1: P(104.78, 193.01), control2: P(101.74, 194.42))
        p.addCurve(to: P(94.14, 202.98), control1: P(97.1, 197.62), control2: P(94.63, 200.2))
        p.addLine(to: P(94.15, 202.97))
        p.addLine(to: P(114.93, 202.97))
        p.addCurve(to: P(116.62, 184), control1: P(115.43, 197.32), control2: P(116.02, 190.74))
        p.addCurve(to: P(108.25, 184), control1: P(116.62, 178.42), control2: P(108.25, 178.42))
        p.closeSubpath()
        return p
    }()

    static let farFrontThigh: Path = {
        var p = Path()
        p.move(to: P(10.1, 142))
        p.addCurve(to: P(8.44, 178), control1: P(9.52, 154.02), control2: P(8.96, 166.03))
        p.addCurve(to: P(19.07, 178), control1: P(8.44, 185.08), control2: P(19.07, 185.08))
        p.addCurve(to: P(20.43, 165.82), control1: P(19.52, 173.94), control2: P(19.98, 169.88))
        p.addCurve(to: P(21.68, 160.04), control1: P(20.65, 163.85), control2: P(20.88, 161.85))
        p.addLine(to: P(20, 150))
        p.addCurve(to: P(10.1, 142), control1: P(25.33, 143.4), control2: P(15.43, 135.4))
        p.closeSubpath()
        return p
    }()

    static let farFrontShank: Path = {
        var p = Path()
        p.move(to: P(8.44, 178))
        p.addCurve(to: P(7.84, 192.54), control1: P(8.23, 182.85), control2: P(8.03, 187.7))
        p.addCurve(to: P(0, 200.05), control1: P(3.18, 191.8), control2: P(0.63, 195.41))
        p.addLine(to: P(16.65, 200.67))
        p.addCurve(to: P(16.99, 196.52), control1: P(16.88, 199.37), control2: P(16.84, 197.83))
        p.addCurve(to: P(19.07, 178), control1: P(17.68, 190.35), control2: P(18.38, 184.17))
        p.addCurve(to: P(8.44, 178), control1: P(19.07, 170.92), control2: P(8.44, 170.92))
        p.closeSubpath()
        return p
    }()

    static let body: Path = {
        var p = Path()
        p.move(to: P(39.21, 72.89))
        p.addCurve(to: P(54.62, 93.75), control1: P(40.25, 81.82), control2: P(46.71, 89.48))
        p.addCurve(to: P(80.7, 99.44), control1: P(62.53, 98.02), control2: P(71.72, 99.31))
        p.addCurve(to: P(107.64, 98.76), control1: P(89.68, 99.57), control2: P(98.66, 98.63))
        p.addCurve(to: P(130.65, 105.59), control1: P(115.82, 98.88), control2: P(124.55, 100.14))
        p.addCurve(to: P(139.7, 136.04), control1: P(138.79, 112.88), control2: P(139.71, 125.11))
        p.addQuadCurve(to: P(128.2, 158.05), control: P(142.5, 152))
        p.addCurve(to: P(46.51, 159.49), control1: P(102.55, 171.69), control2: P(66.65, 170.43))
        p.addLine(to: P(33.51, 160.27))
        p.addCurve(to: P(25.86, 156.12), control1: P(31.95, 157.58), control2: P(28.87, 155.36))
        p.addCurve(to: P(21.68, 160.04), control1: P(23.95, 156.6), control2: P(22.48, 158.23))
        p.addQuadCurve(to: P(9.76, 149), control: P(13, 156))
        p.addCurve(to: P(14.07, 58), control1: P(11.21, 118.66), control2: P(12.8, 88.21))
        p.addLine(to: P(39.21, 72.89))
        p.closeSubpath()
        return p
    }()

    static let spotSaddle: Path = {
        var p = Path()
        p.move(to: P(60.35, 98.41))
        p.addCurve(to: P(60.6, 96.34), control1: P(60.39, 97.72), control2: P(60.49, 97.03))
        p.addCurve(to: P(80.68, 99.42), control1: P(66.98, 98.55), control2: P(73.89, 99.31))
        p.addCurve(to: P(107.62, 98.74), control1: P(89.66, 99.55), control2: P(98.64, 98.61))
        p.addCurve(to: P(117.23, 99.58), control1: P(110.8, 98.79), control2: P(114.07, 99.01))
        p.addCurve(to: P(102.01, 119.35), control1: P(114.53, 107.65), control2: P(109.26, 114.92))
        p.addCurve(to: P(74.55, 121.38), control1: P(93.86, 124.34), control2: P(83.21, 125.43))
        p.addCurve(to: P(60.34, 98.41), control1: P(65.89, 117.33), control2: P(59.75, 107.95))
        p.closeSubpath()
        return p
    }()

    static let spotChest: Path = {
        var p = Path()
        p.move(to: P(33.05, 102.02))
        p.addCurve(to: P(41.14, 96.34), control1: P(35.69, 99.91), control2: P(37.77, 96.42))
        p.addCurve(to: P(47.83, 100.74), control1: P(43.91, 96.27), control2: P(46.07, 98.6))
        p.addCurve(to: P(51.01, 105.41), control1: P(49.03, 102.2), control2: P(50.25, 103.68))
        p.addCurve(to: P(51.32, 110.91), control1: P(51.78, 107.14), control2: P(52.05, 109.17))
        p.addCurve(to: P(48.51, 114.37), control1: P(50.74, 112.29), control2: P(49.61, 113.35))
        p.addCurve(to: P(35.1, 121.97), control1: P(44.65, 117.93), control2: P(40.34, 121.69))
        p.addCurve(to: P(25, 116.93), control1: P(31.17, 122.18), control2: P(27.19, 120.2))
        p.addCurve(to: P(24.21, 108.51), control1: P(23.35, 114.46), control2: P(22.75, 111.1))
        p.addCurve(to: P(33.05, 102.02), control1: P(26.02, 105.29), control2: P(30.16, 104.32))
        p.closeSubpath()
        return p
    }()

    static let spotChestLow: Path = {
        var p = Path()
        p.move(to: P(14.3, 142.54))
        p.addCurve(to: P(10.02, 143.02), control1: P(12.91, 142.99), control2: P(11.46, 143.13))
        p.addCurve(to: P(11.62, 110.18), control1: P(10.55, 132.08), control2: P(11.09, 121.13))
        p.addCurve(to: P(21.78, 127.07), control1: P(16.79, 114.45), control2: P(20.51, 120.48))
        p.addCurve(to: P(21.48, 135.55), control1: P(22.32, 129.88), control2: P(22.43, 132.85))
        p.addCurve(to: P(14.29, 142.54), control1: P(20.33, 138.82), control2: P(17.59, 141.48))
        p.closeSubpath()
        return p
    }()

    static let bodyShade: Path = {
        var p = Path()
        p.move(to: P(47.25, 159.52))
        p.addCurve(to: P(95.71, 161.11), control1: P(63.36, 160.97), control2: P(79.57, 162.31))
        p.addCurve(to: P(139.48, 149.17), control1: P(110.91, 159.98), control2: P(126.15, 156.5))
        p.addQuadCurve(to: P(128.2, 158.05), control: P(140, 156))
        p.addCurve(to: P(46.51, 159.49), control1: P(102.55, 171.69), control2: P(66.65, 170.43))
        p.closeSubpath()
        return p
    }()

    static let nearRearThigh: Path = {
        var p = Path()
        p.move(to: P(127, 140))
        p.addLine(to: P(128.2, 158.05))
        p.addCurve(to: P(128.09, 183), control1: P(128.21, 166.53), control2: P(127.76, 174.73))
        p.addCurve(to: P(137.43, 183), control1: P(128.09, 189.23), control2: P(137.43, 189.23))
        p.addCurve(to: P(139.66, 142), control1: P(138.73, 169.37), control2: P(139.48, 155.69))
        p.addCurve(to: P(127, 140), control1: P(140.99, 133.56), control2: P(128.33, 131.56))
        p.closeSubpath()
        return p
    }()

    static let nearRearThighShade: Path = {
        var p = Path()
        p.move(to: P(128.2, 158.05))
        p.addCurve(to: P(128.09, 183), control1: P(128.21, 166.53), control2: P(127.76, 174.73))
        p.addCurve(to: P(137.43, 183), control1: P(128.09, 189.23), control2: P(137.43, 189.23))
        p.addCurve(to: P(139.42, 152), control1: P(138.42, 172.69), control2: P(139.08, 162.35))
        p.addLine(to: P(128.2, 158.05))
        p.closeSubpath()
        return p
    }()

    static let spotRearThigh: Path = {
        var p = Path()
        p.move(to: P(131.32, 139.78))
        p.addCurve(to: P(139.37, 127.07), control1: P(131.89, 134.64), control2: P(135.29, 130.43))
        p.addCurve(to: P(139.69, 136.02), control1: P(139.62, 130.07), control2: P(139.69, 133.09))
        p.addCurve(to: P(139.31, 154.6), control1: P(139.69, 142.22), control2: P(139.55, 148.41))
        p.addCurve(to: P(138.57, 154.14), control1: P(139.06, 154.45), control2: P(138.81, 154.3))
        p.addCurve(to: P(131.32, 139.78), control1: P(133.86, 151.04), control2: P(130.71, 145.39))
        p.closeSubpath()
        return p
    }()

    static let nearRearShank: Path = {
        var p = Path()
        p.move(to: P(128.09, 183))
        p.addCurve(to: P(129.04, 193.63), control1: P(128.23, 186.52), control2: P(128.51, 190.06))
        p.addCurve(to: P(128.85, 194.53), control1: P(129.1, 193.42), control2: P(128.79, 194.74))
        p.addCurve(to: P(121.66, 196.16), control1: P(127.12, 193.5), control2: P(125.42, 194.58))
        p.addCurve(to: P(118.75, 198.21), control1: P(120.55, 196.63), control2: P(119.47, 197.25))
        p.addCurve(to: P(116.65, 202.57), control1: P(118.02, 199.17), control2: P(116.13, 201.49))
        p.addCurve(to: P(135.11, 202.99), control1: P(117.17, 203.65), control2: P(131.54, 203.11))
        p.addCurve(to: P(137.43, 183), control1: P(136.02, 196.34), control2: P(136.79, 189.68))
        p.addCurve(to: P(128.09, 183), control1: P(137.43, 176.77), control2: P(128.09, 176.77))
        p.closeSubpath()
        return p
    }()

    static let nearRearShankShade: Path = {
        var p = Path()
        p.move(to: P(128.09, 183))
        p.addCurve(to: P(129.04, 193.63), control1: P(128.23, 186.52), control2: P(128.51, 190.06))
        p.addCurve(to: P(128.85, 194.53), control1: P(129.1, 193.42), control2: P(128.79, 194.74))
        p.addCurve(to: P(121.66, 196.16), control1: P(127.12, 193.5), control2: P(125.42, 194.58))
        p.addCurve(to: P(118.75, 198.21), control1: P(120.55, 196.63), control2: P(119.47, 197.25))
        p.addCurve(to: P(116.65, 202.57), control1: P(118.02, 199.17), control2: P(116.13, 201.49))
        p.addCurve(to: P(135.11, 202.99), control1: P(117.17, 203.65), control2: P(131.54, 203.11))
        p.addCurve(to: P(137.43, 183), control1: P(136.02, 196.34), control2: P(136.79, 189.68))
        p.addCurve(to: P(128.09, 183), control1: P(137.43, 176.77), control2: P(128.09, 176.77))
        p.closeSubpath()
        return p
    }()

    static let nearFrontThigh: Path = {
        var p = Path()
        p.move(to: P(33.2, 146))
        p.addLine(to: P(33.51, 160.27))
        p.addCurve(to: P(35.12, 180), control1: P(35.22, 163.22), control2: P(35.19, 172.13))
        p.addCurve(to: P(45.64, 180), control1: P(35.12, 187.01), control2: P(45.64, 187.01))
        p.addCurve(to: P(46.51, 159.49), control1: P(45.81, 173.34), control2: P(45.99, 166.67))
        p.addLine(to: P(46.3, 146))
        p.addCurve(to: P(33.2, 146), control1: P(46.3, 137.27), control2: P(33.2, 137.27))
        p.closeSubpath()
        return p
    }()

    static let nearFrontShank: Path = {
        var p = Path()
        p.move(to: P(35.12, 180))
        p.addCurve(to: P(35.46, 192.4), control1: P(35.08, 185.36), control2: P(35.01, 190.23))
        p.addCurve(to: P(28.58, 193.3), control1: P(33.27, 191.27), control2: P(30.4, 191.64))
        p.addCurve(to: P(27.37, 200.76), control1: P(26.76, 194.96), control2: P(26.44, 198.47))
        p.addLine(to: P(44.77, 200.76))
        p.addCurve(to: P(45.64, 180), control1: P(45.3, 193.49), control2: P(45.47, 186.75))
        p.addCurve(to: P(35.12, 180), control1: P(45.64, 172.99), control2: P(35.12, 172.99))
        p.closeSubpath()
        return p
    }()

    static let head: Path = {
        var p = Path()
        p.move(to: P(39.21, 72.89))
        p.addCurve(to: P(45.79, 58.49), control1: P(38.56, 67.28), control2: P(40.64, 60.82))
        p.addCurve(to: P(64.4, 62.7), control1: P(51.81, 55.78), control2: P(58.52, 59.71))
        p.addCurve(to: P(114.55, 67.83), control1: P(79.72, 70.5), control2: P(97.97, 72.36))
        p.addCurve(to: P(137.82, 47.87), control1: P(124.94, 64.99), control2: P(135.66, 58.42))
        p.addCurve(to: P(137.52, 37.19), control1: P(138.58, 44.15), control2: P(139.23, 41.1))
        p.addCurve(to: P(131.17, 34.26), control1: P(137.52, 37.19), control2: P(132.74, 34.53))
        p.addCurve(to: P(44.82, 17.54), control1: P(103.04, 29.47), control2: P(72.95, 22.33))
        p.addCurve(to: P(28.3, 18.52), control1: P(39.53, 16.64), control2: P(33.42, 16.92))
        p.addCurve(to: P(17.09, 29.34), control1: P(23.17, 20.12), control2: P(19.79, 24.7))
        p.addCurve(to: P(14.42, 49.44), control1: P(14.31, 34.11), control2: P(14.64, 43.92))
        p.addCurve(to: P(13.28, 76), control1: P(14.07, 58.27), control2: P(13.68, 67.13))
        p.addLine(to: P(39.21, 72.89))
        p.closeSubpath()
        return p
    }()

    static let neckShade: Path = {
        var p = Path()
        p.move(to: P(51.72, 56.74))
        p.addCurve(to: P(84.92, 67.91), control1: P(63.44, 57.25), control2: P(73.71, 64.43))
        p.addCurve(to: P(98.42, 70.27), control1: P(89.29, 69.27), control2: P(93.84, 70.06))
        p.addCurve(to: P(64.29, 62.75), control1: P(86.66, 70.64), control2: P(74.79, 68.09))
        p.addCurve(to: P(45.68, 58.54), control1: P(58.4, 59.76), control2: P(51.7, 55.82))
        p.addCurve(to: P(39.02, 69.81), control1: P(41.47, 60.44), control2: P(39.31, 65.11))
        p.addCurve(to: P(38.81, 68.31), control1: P(38.93, 69.31), control2: P(38.85, 68.81))
        p.addCurve(to: P(40.72, 60.62), control1: P(38.56, 65.61), control2: P(39.05, 62.75))
        p.addCurve(to: P(51.72, 56.74), control1: P(43.21, 57.43), control2: P(47.68, 56.56))
        p.closeSubpath()
        return p
    }()

    static let eyePatch: Path = {
        var p = Path()
        p.move(to: P(40.19, 40.87))
        p.addCurve(to: P(48.68, 26.52), control1: P(38.99, 34.94), control2: P(43.02, 28.65))
        p.addCurve(to: P(65.57, 30.11), control1: P(54.34, 24.39), control2: P(61.03, 26.11))
        p.addCurve(to: P(70.18, 43.63), control1: P(69.36, 33.45), control2: P(71.83, 38.85))
        p.addCurve(to: P(64.39, 50.12), control1: P(69.22, 46.43), control2: P(66.97, 48.66))
        p.addCurve(to: P(46.31, 49.47), control1: P(58.87, 53.25), control2: P(51.59, 52.99))
        p.addCurve(to: P(40.2, 40.86), control1: P(43.3, 47.47), control2: P(40.91, 44.4))
        p.closeSubpath()
        return p
    }()

    static let nose: Path = {
        var p = Path()
        p.move(to: P(138.13, 34.83))
        p.addCurve(to: P(138.43, 45.51), control1: P(139.84, 38.74), control2: P(139.19, 41.78))
        p.addCurve(to: P(136.21, 52.54), control1: P(138, 47.61), control2: P(137.25, 50.75))
        p.addCurve(to: P(120.89, 45.42), control1: P(130.6, 53.04), control2: P(124.71, 49.6))
        p.addCurve(to: P(115.8, 31.4), control1: P(117.44, 41.66), control2: P(115.69, 36.5))
        p.addCurve(to: P(130.67, 33.93), control1: P(120.76, 32.24), control2: P(125.71, 33.09))
        p.addCurve(to: P(138.13, 34.84), control1: P(132.24, 34.2), control2: P(138.13, 34.84))
        p.closeSubpath()
        return p
    }()

    static let smile: Path = {
        var p = Path()
        p.move(to: P(118.4, 63.51))
        p.addCurve(to: P(118.03, 63.8), control1: P(118.4, 63.51), control2: P(118.26, 63.62))
        p.addCurve(to: P(117.58, 64.11), control1: P(117.91, 63.89), control2: P(117.76, 63.99))
        p.addCurve(to: P(116.85, 64.42), control1: P(117.43, 64.24), control2: P(117.22, 64.37))
        p.addCurve(to: P(115.73, 64.65), control1: P(116.5, 64.49), control2: P(116.13, 64.57))
        p.addCurve(to: P(114.38, 64.64), control1: P(115.33, 64.75), control2: P(114.86, 64.66))
        p.addCurve(to: P(112.85, 64.4), control1: P(113.89, 64.59), control2: P(113.4, 64.59))
        p.addCurve(to: P(111.21, 63.92), control1: P(112.31, 64.24), control2: P(111.76, 64.08))
        p.addCurve(to: P(109.7, 63.11), control1: P(110.44, 63.53), control2: P(110.22, 63.39))
        p.addCurve(to: P(108.28, 62.15), control1: P(109.28, 62.92), control2: P(108.75, 62.5))
        p.addCurve(to: P(107.03, 61.07), control1: P(107.82, 61.79), control2: P(107.31, 61.44))
        p.addCurve(to: P(106.16, 60.05), control1: P(106.72, 60.71), control2: P(106.43, 60.37))
        p.addCurve(to: P(105.22, 58.48), control1: P(105.58, 59.44), control2: P(105.46, 58.84))
        p.addCurve(to: P(104.95, 57.89), control1: P(105.04, 58.1), control2: P(104.95, 57.89))
        p.addCurve(to: P(105.35, 57.4), control1: P(104.83, 57.6), control2: P(105.01, 57.37))
        p.addCurve(to: P(106.04, 57.76), control1: P(105.6, 57.42), control2: P(105.87, 57.56))
        p.addCurve(to: P(106.56, 58.36), control1: P(106.04, 57.76), control2: P(106.3, 58.06))
        p.addCurve(to: P(107.59, 59.52), control1: P(106.84, 58.65), control2: P(107.06, 59.09))
        p.addCurve(to: P(108.36, 60.24), control1: P(107.83, 59.74), control2: P(108.09, 59.98))
        p.addCurve(to: P(109.24, 60.89), control1: P(108.62, 60.52), control2: P(108.96, 60.64))
        p.addCurve(to: P(110.28, 61.57), control1: P(109.55, 61.11), control2: P(109.77, 61.35))
        p.addLine(to: P(111.49, 62.19))
        p.addLine(to: P(112.66, 62.58))
        p.addCurve(to: P(113.79, 62.82), control1: P(113.05, 62.76), control2: P(113.42, 62.76))
        p.addCurve(to: P(114.83, 62.96), control1: P(114.13, 62.84), control2: P(114.56, 63))
        p.addCurve(to: P(115.68, 62.96), control1: P(115.13, 62.96), control2: P(115.42, 62.96))
        p.addCurve(to: P(117.05, 62.73), control1: P(116.24, 63.03), control2: P(116.72, 62.76))
        p.addCurve(to: P(117.59, 62.62), control1: P(117.39, 62.66), control2: P(117.59, 62.62))
        p.addCurve(to: P(118.4, 62.99), control1: P(117.85, 62.57), control2: P(118.21, 62.73))
        p.addCurve(to: P(118.4, 63.49), control1: P(118.54, 63.19), control2: P(118.53, 63.39))
        p.closeSubpath()
        return p
    }()

    static let blush: Path = {
        var p = Path()
        p.move(to: P(32.84, 51.44))
        p.addCurve(to: P(37.56, 54.96), control1: P(32.84, 53.38), control2: P(34.95, 54.96))
        p.addCurve(to: P(42.28, 51.44), control1: P(40.17, 54.96), control2: P(42.28, 53.38))
        p.addCurve(to: P(37.56, 47.92), control1: P(42.28, 49.5), control2: P(40.17, 47.92))
        p.addCurve(to: P(32.84, 51.44), control1: P(34.95, 47.92), control2: P(32.84, 49.49))
        p.closeSubpath()
        return p
    }()

    static let noseShine: Path = {
        var p = Path()
        p.move(to: P(126.35, 35.02))
        p.addCurve(to: P(124.63, 35.31), control1: P(125.75, 34.94), control2: P(125.07, 34.9))
        p.addCurve(to: P(124.6, 37.1), control1: P(124.15, 35.76), control2: P(124.22, 36.58))
        p.addCurve(to: P(126.22, 38.16), control1: P(124.99, 37.63), control2: P(125.61, 37.92))
        p.addCurve(to: P(134.36, 39.12), control1: P(128.79, 39.16), control2: P(131.62, 39.5))
        p.addCurve(to: P(136.21, 38.51), control1: P(135.01, 39.03), control2: P(135.67, 38.89))
        p.addCurve(to: P(136.06, 36.59), control1: P(136.74, 38.13), control2: P(136.23, 37.22))
        p.addCurve(to: P(126.35, 35.01), control1: P(132.56, 35.84), control2: P(129.9, 35.46))
        p.closeSubpath()
        return p
    }()

    static let earTuft: Path = {
        var p = Path()
        p.move(to: P(49.42, 21.14))
        p.addCurve(to: P(57, 20.19), control1: P(51.85, 20.31), control2: P(54.44, 20))
        p.addCurve(to: P(51.59, 23.39), control1: P(55.36, 21.5), control2: P(53.53, 22.58))
        p.addCurve(to: P(49.26, 23.74), control1: P(50.85, 23.7), control2: P(50.03, 23.97))
        p.addCurve(to: P(48.28, 21.89), control1: P(48.49, 23.52), control2: P(47.89, 22.59))
        p.addCurve(to: P(49.42, 21.14), control1: P(48.51, 21.49), control2: P(48.98, 21.29))
        p.closeSubpath()
        return p
    }()

    static let earSmall: Path = {
        var p = Path()
        p.move(to: P(42.09, 8.53))
        p.addCurve(to: P(45.06, 2.47), control1: P(41.91, 8.02), control2: P(43.45, 4.17))
        p.addCurve(to: P(48.1, 0.01), control1: P(46.07, 1.4), control2: P(46.63, 0.16))
        p.addCurve(to: P(51.85, 1.34), control1: P(49.45, -0.12), control2: P(50.71, 0.62))
        p.addCurve(to: P(64.16, 12.32), control1: P(56.57, 4.29), control2: P(61.48, 7.44))
        p.addCurve(to: P(45.82, 11.08), control1: P(58.06, 13.34), control2: P(51.72, 12.91))
        p.addCurve(to: P(42.09, 8.53), control1: P(44.33, 10.62), control2: P(42.59, 10))
        p.closeSubpath()
        return p
    }()

    static let earSmallDetail: Path = {
        var p = Path()
        p.move(to: P(44.17, 3.4))
        p.addCurve(to: P(40.06, 17.14), control1: P(42.26, 7.79), control2: P(40.87, 12.42))
        p.addCurve(to: P(44.95, 17.26), control1: P(41.69, 17.18), control2: P(43.32, 17.22))
        p.addCurve(to: P(51.19, 9.44), control1: P(44.6, 13.59), control2: P(47.54, 9.91))
        p.addCurve(to: P(44.16, 3.4), control1: P(47.97, 8.97), control2: P(45.12, 6.52))
        p.closeSubpath()
        return p
    }()

    static let earFloppy: Path = {
        var p = Path()
        p.move(to: P(33.75, 20.17))
        p.addCurve(to: P(18.54, 25.16), control1: P(28.24, 20.09), control2: P(22.73, 21.45))
        p.addCurve(to: P(11.58, 31.36), control1: P(16.21, 27.23), control2: P(14.25, 29.8))
        p.addCurve(to: P(8.14, 32.03), control1: P(10.53, 31.98), control2: P(9.28, 32.43))
        p.addCurve(to: P(5.33, 27.83), control1: P(6.52, 31.47), control2: P(5.82, 29.53))
        p.addCurve(to: P(2.94, 15.32), control1: P(4.15, 23.74), control2: P(2.95, 19.59))
        p.addCurve(to: P(7.35, 3.84), control1: P(2.92, 11.06), control2: P(4.24, 6.59))
        p.addCurve(to: P(33.76, 20.16), control1: P(17.56, 5.48), control2: P(27.64, 10.79))
        p.closeSubpath()
        return p
    }()

    static let earFloppyInner: Path = {
        var p = Path()
        p.move(to: P(16.65, 22.73))
        p.addCurve(to: P(31.96, 31.61), control1: P(22.91, 22.93), control2: P(29.17, 26))
        p.addCurve(to: P(35.49, 29.35), control1: P(33.65, 31.97), control2: P(35.46, 31.07))
        p.addCurve(to: P(31.6, 17.08), control1: P(35.57, 24.98), control2: P(34.18, 20.6))
        p.addCurve(to: P(16.65, 22.73), control1: P(26.58, 17.43), control2: P(20.5, 19.49))
        p.closeSubpath()
        return p
    }()

    static let eyeWhite: Path = {
        var p = Path()
        p.move(to: P(64.51, 38.3))
        p.addCurve(to: P(57.58, 46.64), control1: P(64.51, 42.9), control2: P(61.41, 46.64))
        p.addCurve(to: P(50.65, 38.3), control1: P(53.75, 46.64), control2: P(50.65, 42.91))
        p.addCurve(to: P(57.58, 29.96), control1: P(50.65, 33.69), control2: P(53.75, 29.96))
        p.addCurve(to: P(64.51, 38.3), control1: P(61.41, 29.96), control2: P(64.51, 33.69))
        p.closeSubpath()
        return p
    }()

    static let pupil: Path = {
        var p = Path()
        p.move(to: P(63.92, 36.86))
        p.addCurve(to: P(60.16, 41.54), control1: P(63.92, 39.45), control2: P(62.24, 41.54))
        p.addCurve(to: P(56.4, 36.86), control1: P(58.08, 41.54), control2: P(56.4, 39.44))
        p.addCurve(to: P(60.16, 32.18), control1: P(56.4, 34.28), control2: P(58.08, 32.18))
        p.addCurve(to: P(63.92, 36.86), control1: P(62.24, 32.18), control2: P(63.92, 34.28))
        p.closeSubpath()
        return p
    }()

    /// 闭眼弧线（眨眼到底/睡觉时描边显示，非原 SVG 部件）
    static let eyelid: Path = {
        var p = Path()
        p.move(to: P(51.5, 39.5))
        p.addQuadCurve(to: P(63.7, 39), control: P(57.6, 44.5))
        return p
    }()
}

// MARK: - 通用部件 Shape：把 viewBox 路径等比缩放到画布

struct SpottedDogPartShape: Shape {
    let base: Path
    func path(in rect: CGRect) -> Path {
        let s = rect.width / SpottedDogRig.viewW
        return base.applying(CGAffineTransform(scaleX: s, y: s))
    }
}
