//
//  CatPoses.swift
//  DesktopPet
//
//  小橘猫（橘白奶牛猫）的六个姿态矢量数据——按用户提供的姿态参考图
//  逐个手工描摹建模，由 tools/cat-rig/emit_cat.py 生成。
//
//  设计要点：
//  - 这套画风是"纯色块 + 粗描边"，每个姿态是一组有序部件（先画的在下面）；
//    部件 = 路径 + 填充色/描边色，橙色斑块通过 clip 到身体/头部路径实现
//    "色块贴在轮廓内"的效果。
//  - 眼睛刻意不烘焙进静态路径，由视图按 face 定位参数化绘制，才能眨眼；
//    舔毛姿态 eyesClosed = true，画舒服眯眼弧线。
//  - 尾巴是"描边管道"（粗描边色 + 细橙色两笔叠加），单独成组，绕
//    tailPivot 小幅旋转就是摆尾；行走姿态的四条腿、舔毛姿态的爪子
//    也各自成组，配套支点在 legPivots / pawPivot。
//
//  ⚠️ 数值请勿手改——想调整造型请改生成脚本后重新生成。
//

import SwiftUI

enum CatColors {
    static let outline = Color(red: 0.227, green: 0.204, blue: 0.188) // #3a3430 描边
    static let orange  = Color(red: 0.941, green: 0.604, blue: 0.369) // #f09a5e 橘色斑块
    static let stripe  = Color(red: 0.898, green: 0.475, blue: 0.239) // #e5793d 深橘条纹
    static let cream   = Color(red: 0.992, green: 0.957, blue: 0.902) // #fdf4e6 奶油底色
    static let blush   = Color(red: 0.949, green: 0.702, blue: 0.647) // #f2b3a5 腮红
    static let earPink = Color(red: 0.976, green: 0.824, blue: 0.769) // #f9d2c4 耳内粉
}

enum CatRig {
    static let viewW: CGFloat = 200
    static let viewH: CGFloat = 180
    static func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: p.x / viewW, y: p.y / viewH)
    }
}

/// 可独立驱动的部件分组
enum CatPartGroup {
    case base, tail, paw, legFF, legRF, legFN, legRN
}

struct CatPart {
    let path: Path
    let fill: Color?
    let stroke: Color?
    let lineWidth: CGFloat
    let clip: Path?
    let group: CatPartGroup
}

/// 眼睛的参数化定位（姿态坐标空间）
struct CatFaceSpec {
    let center: CGPoint
    let scale: CGFloat
    let rotationDegrees: CGFloat
    let eyesClosed: Bool
    let look: CGPoint
}

struct CatPoseData {
    let parts: [CatPart]
    let face: CatFaceSpec?
    let tailPivot: CGPoint
    let pawPivot: CGPoint?
    let legPivots: [CatPartGroup: CGPoint]
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

enum CatPoses {
    static let sitFront: CatPoseData = {
        let p0: Path = {
            var p = Path()
            p.move(to: P(128, 150))
            p.addCurve(to: P(154, 158), control1: P(132.68, 151.44), control2: P(145.72, 157.64))
            p.addCurve(to: P(174, 152), control1: P(162.28, 158.36), control2: P(168.06, 154.88))
            p.addCurve(to: P(187, 142), control1: P(179.94, 149.12), control2: P(184.66, 143.8))
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(128, 150))
            p.addCurve(to: P(154, 158), control1: P(132.68, 151.44), control2: P(145.72, 157.64))
            p.addCurve(to: P(174, 152), control1: P(162.28, 158.36), control2: P(168.06, 154.88))
            p.addCurve(to: P(187, 142), control1: P(179.94, 149.12), control2: P(184.66, 143.8))
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(152.28, 157.13))
            p.addLine(to: P(162.99, 159.02))
            p.addCurve(to: P(163.72, 154.87), control1: P(165.74, 159.51), control2: P(166.48, 155.35))
            p.addLine(to: P(153.01, 152.98))
            p.addCurve(to: P(152.28, 157.13), control1: P(150.26, 152.49), control2: P(149.52, 156.65))
            p.closeSubpath()
            p.move(to: P(166.17, 151.12))
            p.addLine(to: P(176.39, 154.84))
            p.addCurve(to: P(177.83, 150.88), control1: P(179.02, 155.8), control2: P(180.46, 151.84))
            p.addLine(to: P(167.61, 147.16))
            p.addCurve(to: P(166.17, 151.12), control1: P(164.98, 146.2), control2: P(163.54, 150.16))
            p.closeSubpath()
            p.move(to: P(178.33, 141.61))
            p.addLine(to: P(187.25, 147.85))
            p.addCurve(to: P(189.67, 144.39), control1: P(189.54, 149.45), control2: P(191.95, 146))
            p.addLine(to: P(180.75, 138.15))
            p.addCurve(to: P(178.33, 141.61), control1: P(178.46, 136.55), control2: P(176.05, 140))
            p.closeSubpath()
            return p
        }()
        let p3: Path = {
            var p = Path()
            p.move(to: P(56.78, 26.94))
            p.addCurve(to: P(63.35, -4.63), control1: P(50.82, 21.52), control2: P(55.74, -2.16))
            p.addCurve(to: P(87.22, 17.06), control1: P(70.96, -7.1), control2: P(88.86, 9.16))
            p.addCurve(to: P(56.78, 26.94), control1: P(85.58, 24.95), control2: P(62.75, 32.37))
            p.closeSubpath()
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(64.18, 18.65))
            p.addCurve(to: P(66.64, 5.49), control1: P(61.75, 16.35), control2: P(63.59, 6.48))
            p.addCurve(to: P(76.36, 14.7), control1: P(69.68, 4.5), control2: P(76.97, 11.41))
            p.addCurve(to: P(64.18, 18.65), control1: P(75.74, 17.99), control2: P(66.61, 20.95))
            p.closeSubpath()
            return p
        }()
        let p5: Path = {
            var p = Path()
            p.move(to: P(112.78, 17.06))
            p.addCurve(to: P(136.65, -4.63), control1: P(111.14, 9.16), control2: P(129.04, -7.1))
            p.addCurve(to: P(143.22, 26.94), control1: P(144.26, -2.16), control2: P(149.18, 21.52))
            p.addCurve(to: P(112.78, 17.06), control1: P(137.25, 32.37), control2: P(114.42, 24.95))
            p.closeSubpath()
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(123.64, 14.7))
            p.addCurve(to: P(133.36, 5.49), control1: P(123.03, 11.41), control2: P(130.32, 4.5))
            p.addCurve(to: P(135.82, 18.65), control1: P(136.41, 6.48), control2: P(138.25, 16.35))
            p.addCurve(to: P(123.64, 14.7), control1: P(133.39, 20.95), control2: P(124.26, 17.99))
            p.closeSubpath()
            return p
        }()
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(100, 74))
            p.addCurve(to: P(69, 86), control1: P(88.84, 74), control2: P(76.92, 76.64))
            p.addCurve(to: P(56, 126), control1: P(61.08, 95.36), control2: P(56.9, 113.4))
            p.addCurve(to: P(64, 156), control1: P(55.1, 138.6), control2: P(56.08, 148.8))
            p.addCurve(to: P(100, 166), control1: P(71.92, 163.2), control2: P(87.04, 166))
            p.addCurve(to: P(136, 156), control1: P(112.96, 166), control2: P(128.08, 163.2))
            p.addCurve(to: P(144, 126), control1: P(143.92, 148.8), control2: P(144.9, 138.6))
            p.addCurve(to: P(131, 86), control1: P(143.1, 113.4), control2: P(138.92, 95.36))
            p.addCurve(to: P(100, 74), control1: P(123.08, 76.64), control2: P(111.16, 74))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(124, 82))
            p.addCurve(to: P(146, 100), control1: P(130.84, 78.76), control2: P(142.04, 89.2))
            p.addCurve(to: P(146, 142), control1: P(149.96, 110.8), control2: P(150.32, 131.2))
            p.addCurve(to: P(122, 160), control1: P(141.68, 152.8), control2: P(128.84, 164.32))
            p.addCurve(to: P(108, 118), control1: P(115.16, 155.68), control2: P(107.64, 132.04))
            p.addCurve(to: P(124, 82), control1: P(108.36, 103.96), control2: P(117.16, 85.24))
            p.closeSubpath()
            return p
        }()
        let p9: Path = {
            var p = Path()
            p.move(to: P(80, 142))
            p.addCurve(to: P(65, 161), control1: P(80, 152.49), control2: P(73.28, 161))
            p.addCurve(to: P(50, 142), control1: P(56.72, 161), control2: P(50, 152.49))
            p.addCurve(to: P(65, 123), control1: P(50, 131.51), control2: P(56.72, 123))
            p.addCurve(to: P(80, 142), control1: P(73.28, 123), control2: P(80, 131.51))
            p.closeSubpath()
            return p
        }()
        let p10: Path = {
            var p = Path()
            p.move(to: P(87, 118))
            p.addLine(to: P(87, 151))
            p.addQuadCurve(to: P(96, 160), control: P(87, 160))
            p.move(to: P(113, 118))
            p.addLine(to: P(113, 151))
            p.addQuadCurve(to: P(104, 160), control: P(113, 160))
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(100, 12))
            p.addCurve(to: P(66, 21), control1: P(87.76, 12), control2: P(74.1, 14.88))
            p.addCurve(to: P(55, 46), control1: P(57.9, 27.12), control2: P(55.54, 37.18))
            p.addCurve(to: P(63, 70), control1: P(54.46, 54.82), control2: P(54.9, 63.88))
            p.addCurve(to: P(100, 80), control1: P(71.1, 76.12), control2: P(86.68, 80))
            p.addCurve(to: P(137, 70), control1: P(113.32, 80), control2: P(128.9, 76.12))
            p.addCurve(to: P(145, 46), control1: P(145.1, 63.88), control2: P(145.54, 54.82))
            p.addCurve(to: P(134, 21), control1: P(144.46, 37.18), control2: P(142.1, 27.12))
            p.addCurve(to: P(100, 12), control1: P(125.9, 14.88), control2: P(112.24, 12))
            p.closeSubpath()
            return p
        }()
        let p12: Path = {
            var p = Path()
            p.move(to: P(50, 52))
            p.addCurve(to: P(70, 40), control1: P(53.24, 57.04), control2: P(61, 41.44))
            p.addCurve(to: P(100, 44), control1: P(79, 38.56), control2: P(89.2, 44))
            p.addCurve(to: P(130, 40), control1: P(110.8, 44), control2: P(121, 38.56))
            p.addCurve(to: P(150, 52), control1: P(139, 41.44), control2: P(146.76, 57.04))
            p.addCurve(to: P(148, 12), control1: P(153.24, 46.96), control2: P(165.64, 19.2))
            p.addCurve(to: P(52, 12), control1: P(130.36, 4.8), control2: P(69.64, 4.8))
            p.addCurve(to: P(50, 52), control1: P(34.36, 19.2), control2: P(46.76, 46.96))
            p.closeSubpath()
            return p
        }()
        let p13: Path = {
            var p = Path()
            p.move(to: P(83.96, 12.84))
            p.addLine(to: P(86.45, 22.12))
            p.addCurve(to: P(90.04, 21.16), control1: P(87.08, 24.5), control2: P(90.68, 23.54))
            p.addLine(to: P(87.55, 11.88))
            p.addCurve(to: P(83.96, 12.84), control1: P(86.92, 9.5), control2: P(83.32, 10.46))
            p.closeSubpath()
            p.move(to: P(98.14, 9.2))
            p.addLine(to: P(98.14, 18.8))
            p.addCurve(to: P(101.86, 18.8), control1: P(98.14, 21.27), control2: P(101.86, 21.27))
            p.addLine(to: P(101.86, 9.2))
            p.addCurve(to: P(98.14, 9.2), control1: P(101.86, 6.73), control2: P(98.14, 6.73))
            p.closeSubpath()
            p.move(to: P(112.45, 11.88))
            p.addLine(to: P(109.96, 21.16))
            p.addCurve(to: P(113.55, 22.12), control1: P(109.32, 23.54), control2: P(112.92, 24.5))
            p.addLine(to: P(116.04, 12.84))
            p.addCurve(to: P(112.45, 11.88), control1: P(116.68, 10.46), control2: P(113.08, 9.5))
            p.closeSubpath()
            return p
        }()
        let p14: Path = {
            var p = Path()
            p.move(to: P(98, 59.5))
            p.addLine(to: P(102, 59.5))
            p.addLine(to: P(100, 62))
            p.closeSubpath()
            return p
        }()
        let p15: Path = {
            var p = Path()
            p.move(to: P(79.8, 59.5))
            p.addCurve(to: P(74, 62.9), control1: P(79.8, 61.38), control2: P(77.2, 62.9))
            p.addCurve(to: P(68.2, 59.5), control1: P(70.8, 62.9), control2: P(68.2, 61.38))
            p.addCurve(to: P(74, 56.1), control1: P(68.2, 57.62), control2: P(70.8, 56.1))
            p.addCurve(to: P(79.8, 59.5), control1: P(77.2, 56.1), control2: P(79.8, 57.62))
            p.closeSubpath()
            return p
        }()
        let p16: Path = {
            var p = Path()
            p.move(to: P(131.8, 59.5))
            p.addCurve(to: P(126, 62.9), control1: P(131.8, 61.38), control2: P(129.2, 62.9))
            p.addCurve(to: P(120.2, 59.5), control1: P(122.8, 62.9), control2: P(120.2, 61.38))
            p.addCurve(to: P(126, 56.1), control1: P(120.2, 57.62), control2: P(122.8, 56.1))
            p.addCurve(to: P(131.8, 59.5), control1: P(129.2, 56.1), control2: P(131.8, 57.62))
            p.closeSubpath()
            return p
        }()
        let p17: Path = {
            var p = Path()
            p.move(to: P(73, 49))
            p.addLine(to: P(54, 47.25))
            p.move(to: P(73, 54))
            p.addLine(to: P(54, 53.5))
            p.move(to: P(73, 59))
            p.addLine(to: P(54, 59.75))
            p.move(to: P(127, 49))
            p.addLine(to: P(146, 47.25))
            p.move(to: P(127, 54))
            p.addLine(to: P(146, 53.5))
            p.move(to: P(127, 59))
            p.addLine(to: P(146, 59.75))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: p0, fill: nil, stroke: CatColors.outline, lineWidth: 18.8, clip: nil, group: .tail),
            CatPart(path: p1, fill: nil, stroke: CatColors.orange, lineWidth: 13, clip: nil, group: .tail),
            CatPart(path: p2, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: p3, fill: CatColors.orange, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p4, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p5, fill: CatColors.orange, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p6, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p8, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p9, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p10, fill: nil, stroke: CatColors.outline, lineWidth: 3.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p12, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p13, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p14, fill: CatColors.outline, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p15, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p16, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p17, fill: nil, stroke: CatColors.outline, lineWidth: 1.5, clip: nil, group: .base),
            ],
            face: CatFaceSpec(center: P(100, 50), scale: 1, rotationDegrees: 0, eyesClosed: false, look: P(0, 0)),
            tailPivot: P(128, 150),
            pawPivot: nil,
            legPivots: [:]
        )
    }()

    static let loaf: CatPoseData = {
        let p0: Path = {
            var p = Path()
            p.move(to: P(146, 140))
            p.addCurve(to: P(168, 140), control1: P(149.96, 140), control2: P(161.52, 141.26))
            p.addCurve(to: P(182, 133), control1: P(174.48, 138.74), control2: P(178.22, 135.34))
            p.addCurve(to: P(189, 127), control1: P(185.78, 130.66), control2: P(187.74, 128.08))
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(146, 140))
            p.addCurve(to: P(168, 140), control1: P(149.96, 140), control2: P(161.52, 141.26))
            p.addCurve(to: P(182, 133), control1: P(174.48, 138.74), control2: P(178.22, 135.34))
            p.addCurve(to: P(189, 127), control1: P(185.78, 130.66), control2: P(187.74, 128.08))
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(165.06, 140.43))
            p.addLine(to: P(174.62, 141.27))
            p.addCurve(to: P(174.94, 137.57), control1: P(177.08, 141.49), control2: P(177.4, 137.78))
            p.addLine(to: P(165.38, 136.73))
            p.addCurve(to: P(165.06, 140.43), control1: P(162.92, 136.51), control2: P(162.6, 140.22))
            p.closeSubpath()
            p.move(to: P(175.85, 134.11))
            p.addLine(to: P(184.87, 137.39))
            p.addCurve(to: P(186.15, 133.89), control1: P(187.19, 138.23), control2: P(188.46, 134.74))
            p.addLine(to: P(177.13, 130.61))
            p.addCurve(to: P(175.85, 134.11), control1: P(174.81, 129.77), control2: P(173.54, 133.26))
            p.closeSubpath()
            p.move(to: P(182.91, 127.21))
            p.addLine(to: P(191.23, 132.01))
            p.addCurve(to: P(193.09, 128.79), control1: P(193.36, 133.24), control2: P(195.22, 130.02))
            p.addLine(to: P(184.77, 123.99))
            p.addCurve(to: P(182.91, 127.21), control1: P(182.64, 122.76), control2: P(180.78, 125.98))
            p.closeSubpath()
            return p
        }()
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(36, 148))
            p.addCurve(to: P(34, 118), control1: P(33.84, 140.44), control2: P(30.76, 127.36))
            p.addCurve(to: P(54, 96), control1: P(37.24, 108.64), control2: P(43.92, 101.58))
            p.addCurve(to: P(90, 87), control1: P(64.08, 90.42), control2: P(77.04, 87.54))
            p.addCurve(to: P(126, 93), control1: P(102.96, 86.46), control2: P(115.02, 88.68))
            p.addCurve(to: P(151, 111), control1: P(136.98, 97.32), control2: P(145.78, 102.54))
            p.addCurve(to: P(155, 140), control1: P(156.22, 119.46), control2: P(157.34, 131.18))
            p.addCurve(to: P(138, 160), control1: P(152.66, 148.82), control2: P(151.5, 155.68))
            p.addCurve(to: P(80, 164), control1: P(124.5, 164.32), control2: P(96.56, 164))
            p.addCurve(to: P(46, 160), control1: P(63.44, 164), control2: P(53.92, 162.88))
            p.addCurve(to: P(36, 148), control1: P(38.08, 157.12), control2: P(38.16, 155.56))
            p.closeSubpath()
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(35, 116))
            p.addCurve(to: P(60, 92), control1: P(39.14, 107.36), control2: P(47.94, 97.04))
            p.addCurve(to: P(102, 88), control1: P(72.06, 86.96), control2: P(96.24, 82.6))
            p.addCurve(to: P(92, 122), control1: P(107.76, 93.4), control2: P(99.56, 110.84))
            p.addCurve(to: P(60, 150), control1: P(84.44, 133.16), control2: P(69.9, 146.76))
            p.addCurve(to: P(37, 140), control1: P(50.1, 153.24), control2: P(41.5, 146.12))
            p.addCurve(to: P(35, 116), control1: P(32.5, 133.88), control2: P(30.86, 124.64))
            p.closeSubpath()
            return p
        }()
        let p5: Path = {
            var p = Path()
            p.move(to: P(102, 161))
            p.addQuadCurve(to: P(126, 156), control: P(112, 151))
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(65.73, 46.64))
            p.addCurve(to: P(71.97, 17.27), control1: P(60.16, 41.61), control2: P(64.83, 19.59))
            p.addCurve(to: P(94.27, 37.36), control1: P(79.1, 14.95), control2: P(95.82, 30.02))
            p.addCurve(to: P(65.73, 46.64), control1: P(92.71, 44.71), control2: P(71.31, 51.66))
            p.closeSubpath()
            return p
        }()
        let p7: Path = {
            var p = Path()
            p.move(to: P(72.69, 38.91))
            p.addCurve(to: P(75.02, 26.67), control1: P(70.42, 36.78), control2: P(72.17, 27.6))
            p.addCurve(to: P(84.1, 35.2), control1: P(77.87, 25.74), control2: P(84.68, 32.14))
            p.addCurve(to: P(72.69, 38.91), control1: P(83.52, 38.26), control2: P(74.96, 41.04))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(115.58, 37.87))
            p.addCurve(to: P(137.17, 17.01), control1: P(113.77, 30.58), control2: P(129.96, 14.94))
            p.addCurve(to: P(144.42, 46.13), control1: P(144.38, 19.07), control2: P(149.82, 40.92))
            p.addCurve(to: P(115.58, 37.87), control1: P(139.02, 51.35), control2: P(117.39, 45.15))
            p.closeSubpath()
            return p
        }()
        let p9: Path = {
            var p = Path()
            p.move(to: P(125.67, 35.35))
            p.addCurve(to: P(134.44, 26.5), control1: P(124.98, 32.31), control2: P(131.56, 25.68))
            p.addCurve(to: P(137.2, 38.66), control1: P(137.33, 27.33), control2: P(139.4, 36.44))
            p.addCurve(to: P(125.67, 35.35), control1: P(135.01, 40.87), control2: P(126.36, 38.39))
            p.closeSubpath()
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(104, 32))
            p.addCurve(to: P(72, 40), control1: P(92.48, 32), control2: P(79.56, 34.24))
            p.addCurve(to: P(62, 64), control1: P(64.44, 45.76), control2: P(62.36, 55.72))
            p.addCurve(to: P(70, 86), control1: P(61.64, 72.28), control2: P(62.44, 80.42))
            p.addCurve(to: P(104, 95), control1: P(77.56, 91.58), control2: P(91.94, 95))
            p.addCurve(to: P(137, 86), control1: P(116.06, 95), control2: P(129.62, 91.58))
            p.addCurve(to: P(145, 64), control1: P(144.38, 80.42), control2: P(145.18, 72.28))
            p.addCurve(to: P(136, 40), control1: P(144.82, 55.72), control2: P(143.38, 45.76))
            p.addCurve(to: P(104, 32), control1: P(128.62, 34.24), control2: P(115.52, 32))
            p.closeSubpath()
            return p
        }()
        let p11: Path = {
            var p = Path()
            p.move(to: P(58, 70))
            p.addCurve(to: P(76, 58), control1: P(60.88, 74.68), control2: P(67.72, 59.44))
            p.addCurve(to: P(104, 62), control1: P(84.28, 56.56), control2: P(93.92, 62))
            p.addCurve(to: P(132, 58), control1: P(114.08, 62), control2: P(123.9, 56.56))
            p.addCurve(to: P(149, 70), control1: P(140.1, 59.44), control2: P(146.48, 74.68))
            p.addCurve(to: P(146, 32), control1: P(151.52, 65.32), control2: P(162.02, 38.84))
            p.addCurve(to: P(60, 32), control1: P(129.98, 25.16), control2: P(75.84, 25.16))
            p.addCurve(to: P(58, 70), control1: P(44.16, 38.84), control2: P(55.12, 65.32))
            p.closeSubpath()
            return p
        }()
        let p12: Path = {
            var p = Path()
            p.move(to: P(87.96, 32.84))
            p.addLine(to: P(90.45, 42.12))
            p.addCurve(to: P(94.04, 41.16), control1: P(91.08, 44.5), control2: P(94.68, 43.54))
            p.addLine(to: P(91.55, 31.88))
            p.addCurve(to: P(87.96, 32.84), control1: P(90.92, 29.5), control2: P(87.32, 30.46))
            p.closeSubpath()
            p.move(to: P(102.14, 29.2))
            p.addLine(to: P(102.14, 38.8))
            p.addCurve(to: P(105.86, 38.8), control1: P(102.14, 41.27), control2: P(105.86, 41.27))
            p.addLine(to: P(105.86, 29.2))
            p.addCurve(to: P(102.14, 29.2), control1: P(105.86, 26.73), control2: P(102.14, 26.73))
            p.closeSubpath()
            p.move(to: P(116.45, 31.88))
            p.addLine(to: P(113.96, 41.16))
            p.addCurve(to: P(117.55, 42.12), control1: P(113.32, 43.54), control2: P(116.92, 44.5))
            p.addLine(to: P(120.04, 32.84))
            p.addCurve(to: P(116.45, 31.88), control1: P(120.68, 30.46), control2: P(117.08, 29.5))
            p.closeSubpath()
            return p
        }()
        let p13: Path = {
            var p = Path()
            p.move(to: P(102, 77.5))
            p.addLine(to: P(106, 77.5))
            p.addLine(to: P(104, 80))
            p.closeSubpath()
            return p
        }()
        let p14: Path = {
            var p = Path()
            p.move(to: P(83.8, 77.5))
            p.addCurve(to: P(78, 80.9), control1: P(83.8, 79.38), control2: P(81.2, 80.9))
            p.addCurve(to: P(72.2, 77.5), control1: P(74.8, 80.9), control2: P(72.2, 79.38))
            p.addCurve(to: P(78, 74.1), control1: P(72.2, 75.62), control2: P(74.8, 74.1))
            p.addCurve(to: P(83.8, 77.5), control1: P(81.2, 74.1), control2: P(83.8, 75.62))
            p.closeSubpath()
            return p
        }()
        let p15: Path = {
            var p = Path()
            p.move(to: P(135.8, 77.5))
            p.addCurve(to: P(130, 80.9), control1: P(135.8, 79.38), control2: P(133.2, 80.9))
            p.addCurve(to: P(124.2, 77.5), control1: P(126.8, 80.9), control2: P(124.2, 79.38))
            p.addCurve(to: P(130, 74.1), control1: P(124.2, 75.62), control2: P(126.8, 74.1))
            p.addCurve(to: P(135.8, 77.5), control1: P(133.2, 74.1), control2: P(135.8, 75.62))
            p.closeSubpath()
            return p
        }()
        let p16: Path = {
            var p = Path()
            p.move(to: P(77, 67))
            p.addLine(to: P(58, 65.25))
            p.move(to: P(77, 72))
            p.addLine(to: P(58, 71.5))
            p.move(to: P(77, 77))
            p.addLine(to: P(58, 77.75))
            p.move(to: P(131, 67))
            p.addLine(to: P(150, 65.25))
            p.move(to: P(131, 72))
            p.addLine(to: P(150, 71.5))
            p.move(to: P(131, 77))
            p.addLine(to: P(150, 77.75))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: p0, fill: nil, stroke: CatColors.outline, lineWidth: 17.8, clip: nil, group: .tail),
            CatPart(path: p1, fill: nil, stroke: CatColors.orange, lineWidth: 12, clip: nil, group: .tail),
            CatPart(path: p2, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p4, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p5, fill: nil, stroke: CatColors.outline, lineWidth: 3, clip: nil, group: .base),
            CatPart(path: p6, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p7, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p8, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p9, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p11, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p12, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p13, fill: CatColors.outline, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p14, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p15, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p16, fill: nil, stroke: CatColors.outline, lineWidth: 1.5, clip: nil, group: .base),
            ],
            face: CatFaceSpec(center: P(104, 68), scale: 1, rotationDegrees: 0, eyesClosed: false, look: P(0, 0)),
            tailPivot: P(146, 140),
            pawPivot: nil,
            legPivots: [:]
        )
    }()

    static let groom: CatPoseData = {
        let p0: Path = {
            var p = Path()
            p.move(to: P(114, 124))
            p.addCurve(to: P(94, 148), control1: P(110.4, 128.32), control2: P(101.2, 141.16))
            p.addCurve(to: P(74, 162), control1: P(86.8, 154.84), control2: P(80.48, 158.58))
            p.addCurve(to: P(58, 167), control1: P(67.52, 165.42), control2: P(60.88, 166.1))
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(114, 124))
            p.addCurve(to: P(94, 148), control1: P(110.4, 128.32), control2: P(101.2, 141.16))
            p.addCurve(to: P(74, 162), control1: P(86.8, 154.84), control2: P(80.48, 158.58))
            p.addCurve(to: P(58, 167), control1: P(67.52, 165.42), control2: P(60.88, 166.1))
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(85.68, 156.59))
            p.addLine(to: P(92.81, 150.17))
            p.addCurve(to: P(90.32, 147.41), control1: P(94.64, 148.52), control2: P(92.15, 145.76))
            p.addLine(to: P(83.19, 153.83))
            p.addCurve(to: P(85.68, 156.59), control1: P(81.36, 155.48), control2: P(83.85, 158.24))
            p.closeSubpath()
            p.move(to: P(68.25, 165.52))
            p.addLine(to: P(77.15, 161.93))
            p.addCurve(to: P(75.75, 158.48), control1: P(79.43, 161), control2: P(78.04, 157.55))
            p.addLine(to: P(66.85, 162.07))
            p.addCurve(to: P(68.25, 165.52), control1: P(64.57, 163), control2: P(65.96, 166.45))
            p.closeSubpath()
            p.move(to: P(55.6, 168.67))
            p.addLine(to: P(65.05, 167))
            p.addCurve(to: P(64.4, 163.33), control1: P(67.48, 166.57), control2: P(66.83, 162.91))
            p.addLine(to: P(54.95, 165))
            p.addCurve(to: P(55.6, 168.67), control1: P(52.52, 165.43), control2: P(53.17, 169.09))
            p.closeSubpath()
            return p
        }()
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(82, 56))
            p.addCurve(to: P(122, 50), control1: P(92.08, 49.88), control2: P(109.4, 46.04))
            p.addCurve(to: P(152, 78), control1: P(134.6, 53.96), control2: P(145.52, 65.76))
            p.addCurve(to: P(158, 118), control1: P(158.48, 90.24), control2: P(161.24, 105.4))
            p.addCurve(to: P(134, 148), control1: P(154.76, 130.6), control2: P(144.8, 141.88))
            p.addCurve(to: P(98, 152), control1: P(123.2, 154.12), control2: P(109.16, 156.68))
            p.addCurve(to: P(72, 122), control1: P(86.84, 147.32), control2: P(77.76, 134.24))
            p.addCurve(to: P(66, 84), control1: P(66.24, 109.76), control2: P(64.2, 95.88))
            p.addCurve(to: P(82, 56), control1: P(67.8, 72.12), control2: P(71.92, 62.12))
            p.closeSubpath()
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(120, 52))
            p.addCurve(to: P(152, 82), control1: P(127.92, 49.48), control2: P(145.88, 69.76))
            p.addCurve(to: P(154, 120), control1: P(158.12, 94.24), control2: P(158.32, 108.48))
            p.addCurve(to: P(128, 146), control1: P(149.68, 131.52), control2: P(136.28, 150.32))
            p.addCurve(to: P(108, 96), control1: P(119.72, 141.68), control2: P(109.44, 112.92))
            p.addCurve(to: P(120, 52), control1: P(106.56, 79.08), control2: P(112.08, 54.52))
            p.closeSubpath()
            return p
        }()
        let p5: Path = {
            var p = Path()
            p.move(to: P(32.26, 39.83))
            p.addCurve(to: P(21.01, 12), control1: P(24.83, 38.78), control2: P(16.39, 17.91))
            p.addCurve(to: P(50.73, 16.19), control1: P(25.63, 6.09), control2: P(47.92, 9.23))
            p.addCurve(to: P(32.26, 39.83), control1: P(53.55, 23.15), control2: P(39.7, 40.88))
            p.closeSubpath()
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(33.71, 29.54))
            p.addCurve(to: P(28.8, 18.09), control1: P(30.63, 29.04), control2: P(26.95, 20.45))
            p.addCurve(to: P(41.1, 20.08), control1: P(30.64, 15.72), control2: P(39.87, 17.22))
            p.addCurve(to: P(33.71, 29.54), control1: P(42.32, 22.94), control2: P(36.78, 30.03))
            p.closeSubpath()
            return p
        }()
        let p7: Path = {
            var p = Path()
            p.move(to: P(72.14, 5.51))
            p.addCurve(to: P(79.4, -23.61), control1: P(66.75, 0.3), control2: P(72.19, -21.55))
            p.addCurve(to: P(100.98, -2.76), control1: P(86.61, -25.68), control2: P(102.8, -10.04))
            p.addCurve(to: P(72.14, 5.51), control1: P(99.17, 4.53), control2: P(77.54, 10.73))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(79.36, -1.97))
            p.addCurve(to: P(82.12, -14.12), control1: P(77.17, -4.18), control2: P(79.24, -13.29))
            p.addCurve(to: P(90.9, -5.27), control1: P(85, -14.94), control2: P(91.59, -8.31))
            p.addCurve(to: P(79.36, -1.97), control1: P(90.21, -2.24), control2: P(81.56, 0.24))
            p.closeSubpath()
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(60.17, 10.94))
            p.addCurve(to: P(34.6, 32.18), control1: P(49.65, 15.63), control2: P(39.02, 23.51))
            p.addCurve(to: P(35.63, 59.08), control1: P(30.18, 40.84), control2: P(32.52, 51.21))
            p.addCurve(to: P(51.89, 75.93), control1: P(38.74, 66.96), control2: P(42.64, 73.74))
            p.addCurve(to: P(87.02, 71.23), control1: P(61.14, 78.11), control2: P(76, 76.14))
            p.addCurve(to: P(113.1, 48.68), control1: P(98.03, 66.33), control2: P(108.7, 56.94))
            p.addCurve(to: P(111.46, 25.32), control1: P(117.49, 40.41), control2: P(115.06, 32.98))
            p.addCurve(to: P(93.07, 6.15), control1: P(107.85, 17.67), control2: P(102.3, 8.73))
            p.addCurve(to: P(60.17, 10.94), control1: P(83.83, 3.56), control2: P(70.69, 6.25))
            p.closeSubpath()
            return p
        }()
        let p10: Path = {
            var p = Path()
            p.move(to: P(33.6, 64.36))
            p.addCurve(to: P(45.17, 46.08), control1: P(38.14, 67.47), control2: P(38.19, 50.76))
            p.addCurve(to: P(72.37, 38.35), control1: P(52.15, 41.4), control2: P(63.16, 42.45))
            p.addCurve(to: P(96.33, 23.3), control1: P(81.58, 34.25), control2: P(88.18, 25.36))
            p.addCurve(to: P(117.65, 26.94), control1: P(104.48, 21.25), control2: P(116.92, 32.39))
            p.addCurve(to: P(100.37, -6.96), control1: P(118.38, 21.5), control2: P(117.95, -7.3))
            p.addCurve(to: P(19.97, 28.84), control1: P(82.79, -6.62), control2: P(31.99, 16))
            p.addCurve(to: P(33.6, 64.36), control1: P(7.96, 41.67), control2: P(29.07, 61.26))
            p.closeSubpath()
            return p
        }()
        let p11: Path = {
            var p = Path()
            p.move(to: P(46.16, 18.41))
            p.addLine(to: P(51.8, 25.37))
            p.addCurve(to: P(54.5, 23.18), control1: P(53.25, 27.16), control2: P(55.95, 24.97))
            p.addLine(to: P(48.86, 16.22))
            p.addCurve(to: P(46.16, 18.41), control1: P(47.41, 14.43), control2: P(44.71, 16.62))
            p.closeSubpath()
            p.move(to: P(57.58, 9.38))
            p.addLine(to: P(61.22, 17.57))
            p.addCurve(to: P(64.39, 16.15), control1: P(62.16, 19.67), control2: P(65.33, 18.26))
            p.addLine(to: P(60.75, 7.97))
            p.addCurve(to: P(57.58, 9.38), control1: P(59.81, 5.87), control2: P(56.64, 7.28))
            p.closeSubpath()
            p.move(to: P(71.67, 6.07))
            p.addLine(to: P(73.07, 14.92))
            p.addCurve(to: P(76.5, 14.37), control1: P(73.43, 17.19), control2: P(76.86, 16.65))
            p.addLine(to: P(75.09, 5.52))
            p.addCurve(to: P(71.67, 6.07), control1: P(74.73, 3.25), control2: P(71.31, 3.79))
            p.closeSubpath()
            return p
        }()
        let p12: Path = {
            var p = Path()
            p.move(to: P(76.04, 55.49))
            p.addLine(to: P(79.69, 53.87))
            p.addLine(to: P(78.88, 56.96))
            p.closeSubpath()
            return p
        }()
        let p13: Path = {
            var p = Path()
            p.move(to: P(59.41, 62.89))
            p.addCurve(to: P(55.49, 68.36), control1: P(60.17, 64.61), control2: P(58.42, 67.06))
            p.addCurve(to: P(48.81, 67.61), control1: P(52.57, 69.66), control2: P(49.58, 69.33))
            p.addCurve(to: P(52.73, 62.15), control1: P(48.05, 65.9), control2: P(49.8, 63.45))
            p.addCurve(to: P(59.41, 62.89), control1: P(55.66, 60.84), control2: P(58.65, 61.18))
            p.closeSubpath()
            return p
        }()
        let p14: Path = {
            var p = Path()
            p.move(to: P(106.91, 41.74))
            p.addCurve(to: P(103, 47.21), control1: P(107.68, 43.46), control2: P(105.93, 45.91))
            p.addCurve(to: P(96.32, 46.46), control1: P(100.07, 48.51), control2: P(97.08, 48.18))
            p.addCurve(to: P(100.23, 41), control1: P(95.55, 44.75), control2: P(97.31, 42.3))
            p.addCurve(to: P(106.91, 41.74), control1: P(103.16, 39.69), control2: P(106.15, 40.03))
            p.closeSubpath()
            return p
        }()
        let p15: Path = {
            var p = Path()
            p.move(to: P(48.93, 56.07))
            p.addLine(to: P(30.86, 62.2))
            p.move(to: P(50.96, 60.64))
            p.addLine(to: P(33.4, 67.91))
            p.move(to: P(52.99, 65.2))
            p.addLine(to: P(35.94, 73.62))
            p.move(to: P(98.26, 34.1))
            p.addLine(to: P(114.9, 24.78))
            p.move(to: P(100.29, 38.67))
            p.addLine(to: P(117.45, 30.49))
            p.move(to: P(102.33, 43.24))
            p.addLine(to: P(119.99, 36.2))
            return p
        }()
        let p16: Path = {
            var p = Path()
            p.move(to: P(105.6, 84.2))
            p.addLine(to: P(92.6, 58.2))
            p.addCurve(to: P(77.4, 65.8), control1: P(87.56, 48.12), control2: P(72.36, 55.72))
            p.addLine(to: P(90.4, 91.8))
            p.addCurve(to: P(105.6, 84.2), control1: P(95.44, 101.88), control2: P(110.64, 94.28))
            p.closeSubpath()
            return p
        }()
        let p17: Path = {
            var p = Path()
            p.move(to: P(82, 68))
            p.addQuadCurve(to: P(90, 71), control: P(88, 66))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: p0, fill: nil, stroke: CatColors.outline, lineWidth: 17.8, clip: nil, group: .tail),
            CatPart(path: p1, fill: nil, stroke: CatColors.orange, lineWidth: 12, clip: nil, group: .tail),
            CatPart(path: p2, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p4, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p5, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p6, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p7, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p8, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p10, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p11, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p12, fill: CatColors.outline, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p13, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p14, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p15, fill: nil, stroke: CatColors.outline, lineWidth: 1.5, clip: nil, group: .base),
            CatPart(path: p16, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .paw),
            CatPart(path: p17, fill: nil, stroke: CatColors.outline, lineWidth: 2.2, clip: nil, group: .paw),
            ],
            face: CatFaceSpec(center: P(74, 46), scale: 1, rotationDegrees: -24, eyesClosed: true, look: P(0, 0)),
            tailPivot: P(114, 124),
            pawPivot: P(98, 88),
            legPivots: [:]
        )
    }()

    static let sitBack: CatPoseData = {
        let p0: Path = {
            var p = Path()
            p.move(to: P(118, 154))
            p.addCurve(to: P(146, 148), control1: P(123.04, 152.92), control2: P(137.72, 147.64))
            p.addCurve(to: P(164, 156), control1: P(154.28, 148.36), control2: P(160.58, 152.04))
            p.addCurve(to: P(165, 170), control1: P(167.42, 159.96), control2: P(164.82, 167.48))
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(118, 154))
            p.addCurve(to: P(146, 148), control1: P(123.04, 152.92), control2: P(137.72, 147.64))
            p.addCurve(to: P(164, 156), control1: P(154.28, 148.36), control2: P(160.58, 152.04))
            p.addCurve(to: P(165, 170), control1: P(167.42, 159.96), control2: P(164.82, 167.48))
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(142.88, 149.98))
            p.addLine(to: P(153.12, 149.98))
            p.addCurve(to: P(153.12, 146.02), control1: P(155.75, 149.98), control2: P(155.75, 146.02))
            p.addLine(to: P(142.88, 146.02))
            p.addCurve(to: P(142.88, 149.98), control1: P(140.25, 146.02), control2: P(140.25, 149.98))
            p.closeSubpath()
            p.move(to: P(155.57, 153.16))
            p.addLine(to: P(164.44, 158.28))
            p.addCurve(to: P(166.43, 154.84), control1: P(166.72, 159.59), control2: P(168.7, 156.16))
            p.addLine(to: P(157.56, 149.72))
            p.addCurve(to: P(155.57, 153.16), control1: P(155.28, 148.41), control2: P(153.3, 151.84))
            p.closeSubpath()
            p.move(to: P(161.38, 159.87))
            p.addLine(to: P(164.89, 169.49))
            p.addCurve(to: P(168.62, 168.13), control1: P(165.79, 171.96), control2: P(169.51, 170.6))
            p.addLine(to: P(165.11, 158.51))
            p.addCurve(to: P(161.38, 159.87), control1: P(164.21, 156.04), control2: P(160.49, 157.4))
            p.closeSubpath()
            return p
        }()
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(100, 64))
            p.addCurve(to: P(68, 76), control1: P(88.48, 64), control2: P(76.28, 67.36))
            p.addCurve(to: P(54, 112), control1: P(59.72, 84.64), control2: P(55.8, 99.04))
            p.addCurve(to: P(58, 148), control1: P(52.2, 124.96), control2: P(52.6, 138.28))
            p.addCurve(to: P(84, 166), control1: P(63.4, 157.72), control2: P(73.56, 162.76))
            p.addCurve(to: P(116, 166), control1: P(94.44, 169.24), control2: P(105.56, 169.24))
            p.addCurve(to: P(142, 148), control1: P(126.44, 162.76), control2: P(136.6, 157.72))
            p.addCurve(to: P(146, 112), control1: P(147.4, 138.28), control2: P(147.8, 124.96))
            p.addCurve(to: P(132, 76), control1: P(144.2, 99.04), control2: P(140.28, 84.64))
            p.addCurve(to: P(100, 64), control1: P(123.72, 67.36), control2: P(111.52, 64))
            p.closeSubpath()
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(53, 124))
            p.addCurve(to: P(58, 74), control1: P(50.12, 113.2), control2: P(49.54, 85.88))
            p.addCurve(to: P(100, 58), control1: P(66.46, 62.12), control2: P(85.24, 58.36))
            p.addCurve(to: P(140, 72), control1: P(114.76, 57.64), control2: P(131.18, 60.84))
            p.addCurve(to: P(149, 120), control1: P(148.82, 83.16), control2: P(152.96, 108.48))
            p.addCurve(to: P(118, 136), control1: P(145.04, 131.52), control2: P(131.5, 133.48))
            p.addCurve(to: P(74, 134), control1: P(104.5, 138.52), control2: P(85.7, 136.16))
            p.addCurve(to: P(53, 124), control1: P(62.3, 131.84), control2: P(55.88, 134.8))
            p.closeSubpath()
            return p
        }()
        let p5: Path = {
            var p = Path()
            p.move(to: P(65.51, 19.88))
            p.addCurve(to: P(73.27, -9.11), control1: P(60.21, 14.57), control2: P(66.03, -7.17))
            p.addCurve(to: P(94.49, 12.12), control1: P(80.52, -11.06), control2: P(96.43, 4.87))
            p.addCurve(to: P(65.51, 19.88), control1: P(92.55, 19.37), control2: P(70.82, 25.19))
            p.closeSubpath()
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(105.51, 12.12))
            p.addCurve(to: P(126.73, -9.11), control1: P(103.57, 4.87), control2: P(119.48, -11.06))
            p.addCurve(to: P(134.49, 19.88), control1: P(133.97, -7.17), control2: P(139.79, 14.57))
            p.addCurve(to: P(105.51, 12.12), control1: P(129.18, 25.19), control2: P(107.45, 19.37))
            p.closeSubpath()
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(100, 10))
            p.addCurve(to: P(74, 19), control1: P(90.64, 10), control2: P(80.3, 13.6))
            p.addCurve(to: P(65, 40), control1: P(67.7, 24.4), control2: P(65, 32.62))
            p.addCurve(to: P(74, 60), control1: P(65, 47.38), control2: P(67.7, 55.14))
            p.addCurve(to: P(100, 67), control1: P(80.3, 64.86), control2: P(90.64, 67))
            p.addCurve(to: P(126, 60), control1: P(109.36, 67), control2: P(119.7, 64.86))
            p.addCurve(to: P(135, 40), control1: P(132.3, 55.14), control2: P(135, 47.38))
            p.addCurve(to: P(126, 19), control1: P(135, 32.62), control2: P(132.3, 24.4))
            p.addCurve(to: P(100, 10), control1: P(119.7, 13.6), control2: P(109.36, 10))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(85.16, 11.12))
            p.addLine(to: P(87.48, 19.78))
            p.addCurve(to: P(90.84, 18.88), control1: P(88.08, 22), control2: P(91.43, 21.1))
            p.addLine(to: P(88.52, 10.22))
            p.addCurve(to: P(85.16, 11.12), control1: P(87.92, 8), control2: P(84.57, 8.9))
            p.closeSubpath()
            p.move(to: P(98.26, 7.52))
            p.addLine(to: P(98.26, 16.48))
            p.addCurve(to: P(101.74, 16.48), control1: P(98.26, 18.78), control2: P(101.74, 18.78))
            p.addLine(to: P(101.74, 7.52))
            p.addCurve(to: P(98.26, 7.52), control1: P(101.74, 5.22), control2: P(98.26, 5.22))
            p.closeSubpath()
            p.move(to: P(111.48, 10.22))
            p.addLine(to: P(109.16, 18.88))
            p.addCurve(to: P(112.52, 19.78), control1: P(108.57, 21.1), control2: P(111.92, 22))
            p.addLine(to: P(114.84, 11.12))
            p.addCurve(to: P(111.48, 10.22), control1: P(115.43, 8.9), control2: P(112.08, 8))
            p.closeSubpath()
            return p
        }()
        let p9: Path = {
            var p = Path()
            p.move(to: P(66, 42))
            p.addLine(to: P(52, 38))
            p.move(to: P(66, 48))
            p.addLine(to: P(53, 48))
            p.move(to: P(134, 42))
            p.addLine(to: P(148, 38))
            p.move(to: P(134, 48))
            p.addLine(to: P(147, 48))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: p0, fill: nil, stroke: CatColors.outline, lineWidth: 18.8, clip: nil, group: .tail),
            CatPart(path: p1, fill: nil, stroke: CatColors.orange, lineWidth: 13, clip: nil, group: .tail),
            CatPart(path: p2, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p4, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p5, fill: CatColors.orange, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p6, fill: CatColors.orange, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.orange, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p8, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p9, fill: nil, stroke: CatColors.outline, lineWidth: 1.5, clip: nil, group: .base),
            ],
            face: nil,
            tailPivot: P(118, 154),
            pawPivot: nil,
            legPivots: [:]
        )
    }()

    static let walk: CatPoseData = {
        let p0: Path = {
            var p = Path()
            p.move(to: P(150, 96))
            p.addCurve(to: P(168, 88), control1: P(153.24, 94.56), control2: P(162.6, 92.68))
            p.addCurve(to: P(180, 70), control1: P(173.4, 83.32), control2: P(177.3, 76.48))
            p.addCurve(to: P(183, 52), control1: P(182.7, 63.52), control2: P(182.46, 55.24))
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(150, 96))
            p.addCurve(to: P(168, 88), control1: P(153.24, 94.56), control2: P(162.6, 92.68))
            p.addCurve(to: P(180, 70), control1: P(173.4, 83.32), control2: P(177.3, 76.48))
            p.addCurve(to: P(183, 52), control1: P(182.7, 63.52), control2: P(182.46, 55.24))
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(167.35, 90.81))
            p.addLine(to: P(175.2, 84.23))
            p.addCurve(to: P(172.65, 81.19), control1: P(177.21, 82.54), control2: P(174.66, 79.5))
            p.addLine(to: P(164.8, 87.77))
            p.addCurve(to: P(167.35, 90.81), control1: P(162.79, 89.46), control2: P(165.34, 92.5))
            p.closeSubpath()
            p.move(to: P(178.63, 77.48))
            p.addLine(to: P(182.96, 68.2))
            p.addCurve(to: P(179.37, 66.52), control1: P(184.07, 65.81), control2: P(180.48, 64.14))
            p.addLine(to: P(175.04, 75.8))
            p.addCurve(to: P(178.63, 77.48), control1: P(173.93, 78.19), control2: P(177.52, 79.86))
            p.closeSubpath()
            p.move(to: P(184.06, 61.39))
            p.addLine(to: P(185.84, 51.3))
            p.addCurve(to: P(181.94, 50.61), control1: P(186.3, 48.71), control2: P(182.39, 48.02))
            p.addLine(to: P(180.16, 60.7))
            p.addCurve(to: P(184.06, 61.39), control1: P(179.7, 63.29), control2: P(183.61, 63.98))
            p.closeSubpath()
            return p
        }()
        let p3: Path = {
            var p = Path()
            p.move(to: P(78.34, 121.68))
            p.addLine(to: P(68.34, 154.68))
            p.addCurve(to: P(83.66, 159.32), control1: P(65.27, 164.83), control2: P(80.58, 169.47))
            p.addLine(to: P(93.66, 126.32))
            p.addCurve(to: P(78.34, 121.68), control1: P(96.73, 116.17), control2: P(81.42, 111.53))
            p.closeSubpath()
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(126.54, 126.89))
            p.addLine(to: P(138.54, 157.89))
            p.addCurve(to: P(153.46, 152.11), control1: P(142.37, 167.78), control2: P(157.29, 162))
            p.addLine(to: P(141.46, 121.11))
            p.addCurve(to: P(126.54, 126.89), control1: P(137.63, 111.22), control2: P(122.71, 117))
            p.closeSubpath()
            return p
        }()
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(56, 92))
            p.addCurve(to: P(100, 82), control1: P(65.36, 85.88), control2: P(83.8, 82.72))
            p.addCurve(to: P(146, 88), control1: P(116.2, 81.28), control2: P(134.48, 84.04))
            p.addCurve(to: P(164, 104), control1: P(157.52, 91.96), control2: P(161.84, 96.8))
            p.addCurve(to: P(158, 128), control1: P(166.16, 111.2), control2: P(166.28, 121.52))
            p.addCurve(to: P(118, 140), control1: P(149.72, 134.48), control2: P(132.76, 138.2))
            p.addCurve(to: P(76, 138), control1: P(103.24, 141.8), control2: P(88.6, 142.32))
            p.addCurve(to: P(48, 116), control1: P(63.4, 133.68), control2: P(51.6, 124.28))
            p.addCurve(to: P(56, 92), control1: P(44.4, 107.72), control2: P(46.64, 98.12))
            p.closeSubpath()
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(64, 84))
            p.addCurve(to: P(118, 76), control1: P(72.64, 79.68), control2: P(101.08, 74.56))
            p.addCurve(to: P(158, 92), control1: P(134.92, 77.44), control2: P(152.24, 84.8))
            p.addCurve(to: P(150, 116), control1: P(163.76, 99.2), control2: P(159, 114.92))
            p.addCurve(to: P(108, 98), control1: P(141, 117.08), control2: P(122.4, 100.88))
            p.addCurve(to: P(70, 100), control1: P(93.6, 95.12), control2: P(77.92, 102.52))
            p.addCurve(to: P(64, 84), control1: P(62.08, 97.48), control2: P(55.36, 88.32))
            p.closeSubpath()
            return p
        }()
        let p7: Path = {
            var p = Path()
            p.move(to: P(85.24, 123.94))
            p.addLine(to: P(77.24, 157.94))
            p.addCurve(to: P(94.76, 162.06), control1: P(74.51, 169.55), control2: P(92.03, 173.67))
            p.addLine(to: P(102.76, 128.06))
            p.addCurve(to: P(85.24, 123.94), control1: P(105.49, 116.45), control2: P(87.97, 112.33))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(117.54, 129.08))
            p.addLine(to: P(129.54, 162.08))
            p.addCurve(to: P(146.46, 155.92), control1: P(133.62, 173.29), control2: P(150.54, 167.14))
            p.addLine(to: P(134.46, 122.92))
            p.addCurve(to: P(117.54, 129.08), control1: P(130.38, 111.71), control2: P(113.46, 117.86))
            p.closeSubpath()
            return p
        }()
        let p9: Path = {
            var p = Path()
            p.move(to: P(29.21, 43.69))
            p.addCurve(to: P(32.24, 16.07), control1: P(23.57, 39.64), control2: P(25.84, 18.92))
            p.addCurve(to: P(54.79, 32.31), control1: P(38.63, 13.23), control2: P(55.55, 25.4))
            p.addCurve(to: P(29.21, 43.69), control1: P(54.03, 39.21), control2: P(34.85, 47.75))
            p.closeSubpath()
            return p
        }()
        let p10: Path = {
            var p = Path()
            p.move(to: P(34.93, 35.89))
            p.addCurve(to: P(35.95, 24.41), control1: P(32.63, 34.16), control2: P(33.39, 25.55))
            p.addCurve(to: P(45.16, 31.34), control1: P(38.51, 23.27), control2: P(45.42, 28.47))
            p.addCurve(to: P(34.93, 35.89), control1: P(44.91, 34.21), control2: P(37.24, 37.63))
            p.closeSubpath()
            return p
        }()
        let p11: Path = {
            var p = Path()
            p.move(to: P(74.14, 32.05))
            p.addCurve(to: P(91.34, 10.23), control1: P(71.51, 25.62), control2: P(84.41, 9.26))
            p.addCurve(to: P(101.86, 35.95), control1: P(98.27, 11.21), control2: P(106.16, 30.49))
            p.addCurve(to: P(74.14, 32.05), control1: P(97.56, 41.4), control2: P(76.77, 38.48))
            p.closeSubpath()
            return p
        }()
        let p12: Path = {
            var p = Path()
            p.move(to: P(83.12, 28.47))
            p.addCurve(to: P(90.07, 19.26), control1: P(82.09, 25.78), control2: P(87.3, 18.88))
            p.addCurve(to: P(94.21, 30.03), control1: P(92.84, 19.65), control2: P(95.95, 27.73))
            p.addCurve(to: P(83.12, 28.47), control1: P(92.48, 32.33), control2: P(84.16, 31.16))
            p.closeSubpath()
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(62, 28))
            p.addCurve(to: P(31, 38), control1: P(50.84, 28), control2: P(38.2, 31.88))
            p.addCurve(to: P(22, 62), control1: P(23.8, 44.12), control2: P(22, 53.54))
            p.addCurve(to: P(31, 85), control1: P(22, 70.46), control2: P(23.8, 78.88))
            p.addCurve(to: P(62, 96), control1: P(38.2, 91.12), control2: P(50.84, 96))
            p.addCurve(to: P(93, 85), control1: P(73.16, 96), control2: P(85.8, 91.12))
            p.addCurve(to: P(102, 62), control1: P(100.2, 78.88), control2: P(102, 70.46))
            p.addCurve(to: P(93, 38), control1: P(102, 53.54), control2: P(100.2, 44.12))
            p.addCurve(to: P(62, 28), control1: P(85.8, 31.88), control2: P(73.16, 28))
            p.closeSubpath()
            return p
        }()
        let p14: Path = {
            var p = Path()
            p.move(to: P(18, 68))
            p.addCurve(to: P(38, 56), control1: P(20.52, 73.04), control2: P(30.08, 57.44))
            p.addCurve(to: P(62, 60), control1: P(45.92, 54.56), control2: P(53.36, 60))
            p.addCurve(to: P(86, 56), control1: P(70.64, 60), control2: P(78.08, 54.56))
            p.addCurve(to: P(106, 68), control1: P(93.92, 57.44), control2: P(103.12, 73.04))
            p.addCurve(to: P(102, 28), control1: P(108.88, 62.96), control2: P(116.76, 35.2))
            p.addCurve(to: P(24, 28), control1: P(87.24, 20.8), control2: P(39.12, 20.8))
            p.addCurve(to: P(18, 68), control1: P(8.88, 35.2), control2: P(15.48, 62.96))
            p.closeSubpath()
            return p
        }()
        let p15: Path = {
            var p = Path()
            p.move(to: P(47.16, 29.12))
            p.addLine(to: P(49.48, 37.78))
            p.addCurve(to: P(52.84, 36.88), control1: P(50.08, 40), control2: P(53.43, 39.1))
            p.addLine(to: P(50.52, 28.22))
            p.addCurve(to: P(47.16, 29.12), control1: P(49.92, 26), control2: P(46.57, 26.9))
            p.closeSubpath()
            p.move(to: P(60.26, 25.52))
            p.addLine(to: P(60.26, 34.48))
            p.addCurve(to: P(63.74, 34.48), control1: P(60.26, 36.78), control2: P(63.74, 36.78))
            p.addLine(to: P(63.74, 25.52))
            p.addCurve(to: P(60.26, 25.52), control1: P(63.74, 23.22), control2: P(60.26, 23.22))
            p.closeSubpath()
            p.move(to: P(73.48, 28.22))
            p.addLine(to: P(71.16, 36.88))
            p.addCurve(to: P(74.52, 37.78), control1: P(70.57, 39.1), control2: P(73.92, 40))
            p.addLine(to: P(76.84, 29.12))
            p.addCurve(to: P(73.48, 28.22), control1: P(77.43, 26.9), control2: P(74.08, 26))
            p.closeSubpath()
            return p
        }()
        let p16: Path = {
            var p = Path()
            p.move(to: P(60.16, 72.74))
            p.addLine(to: P(63.84, 72.74))
            p.addLine(to: P(62, 75.04))
            p.closeSubpath()
            return p
        }()
        let p17: Path = {
            var p = Path()
            p.move(to: P(43.42, 72.74))
            p.addCurve(to: P(38.08, 75.87), control1: P(43.42, 74.47), control2: P(41.03, 75.87))
            p.addCurve(to: P(32.74, 72.74), control1: P(35.13, 75.87), control2: P(32.74, 74.47))
            p.addCurve(to: P(38.08, 69.61), control1: P(32.74, 71.01), control2: P(35.13, 69.61))
            p.addCurve(to: P(43.42, 72.74), control1: P(41.03, 69.61), control2: P(43.42, 71.01))
            p.closeSubpath()
            return p
        }()
        let p18: Path = {
            var p = Path()
            p.move(to: P(91.26, 72.74))
            p.addCurve(to: P(85.92, 75.87), control1: P(91.26, 74.47), control2: P(88.87, 75.87))
            p.addCurve(to: P(80.58, 72.74), control1: P(82.97, 75.87), control2: P(80.58, 74.47))
            p.addCurve(to: P(85.92, 69.61), control1: P(80.58, 71.01), control2: P(82.97, 69.61))
            p.addCurve(to: P(91.26, 72.74), control1: P(88.87, 69.61), control2: P(91.26, 71.01))
            p.closeSubpath()
            return p
        }()
        let p19: Path = {
            var p = Path()
            p.move(to: P(37.16, 63.08))
            p.addLine(to: P(19.68, 61.47))
            p.move(to: P(37.16, 67.68))
            p.addLine(to: P(19.68, 67.22))
            p.move(to: P(37.16, 72.28))
            p.addLine(to: P(19.68, 72.97))
            p.move(to: P(86.84, 63.08))
            p.addLine(to: P(104.32, 61.47))
            p.move(to: P(86.84, 67.68))
            p.addLine(to: P(104.32, 67.22))
            p.move(to: P(86.84, 72.28))
            p.addLine(to: P(104.32, 72.97))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: p0, fill: nil, stroke: CatColors.outline, lineWidth: 18.8, clip: nil, group: .tail),
            CatPart(path: p1, fill: nil, stroke: CatColors.orange, lineWidth: 13, clip: nil, group: .tail),
            CatPart(path: p2, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: p3, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .legFF),
            CatPart(path: p4, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .legRF),
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p6, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p7, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .legFN),
            CatPart(path: p8, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .legRN),
            CatPart(path: p9, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p10, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p11, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p12, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p14, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p15, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p16, fill: CatColors.outline, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p17, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p18, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p19, fill: nil, stroke: CatColors.outline, lineWidth: 1.38, clip: nil, group: .base),
            ],
            face: CatFaceSpec(center: P(62, 64), scale: 0.92, rotationDegrees: 0, eyesClosed: false, look: P(0, 0)),
            tailPivot: P(150, 96),
            pawPivot: nil,
            legPivots: [.legFF: P(86, 124), .legRF: P(134, 124), .legFN: P(94, 126), .legRN: P(126, 126)]
        )
    }()

    static let lieSide: CatPoseData = {
        let clip_body: Path = {
            var p = Path()
            p.move(to: P(62, 100))
            p.addCurve(to: P(98, 86), control1: P(68.48, 90.64), control2: P(84.32, 88.16))
            p.addCurve(to: P(138, 88), control1: P(111.68, 83.84), control2: P(126.66, 84.58))
            p.addCurve(to: P(161, 105), control1: P(149.34, 91.42), control2: P(156.5, 97.08))
            p.addCurve(to: P(163, 132), control1: P(165.5, 112.92), control2: P(166.6, 123.54))
            p.addCurve(to: P(141, 152), control1: P(159.4, 140.46), control2: P(153.06, 147.68))
            p.addCurve(to: P(96, 156), control1: P(128.94, 156.32), control2: P(110.22, 158.52))
            p.addCurve(to: P(62, 138), control1: P(81.78, 153.48), control2: P(68.12, 148.08))
            p.addCurve(to: P(62, 100), control1: P(55.88, 127.92), control2: P(55.52, 109.36))
            p.closeSubpath()
            return p
        }()
        let p1: Path = {
            var p = Path()
            p.move(to: P(60, 102))
            p.addCurve(to: P(92, 88), control1: P(65.76, 94.08), control2: P(85.16, 84.76))
            p.addCurve(to: P(98, 120), control1: P(98.84, 91.24), control2: P(100.52, 110.28))
            p.addCurve(to: P(78, 142), control1: P(95.48, 129.72), control2: P(84.84, 139.84))
            p.addCurve(to: P(60, 132), control1: P(71.16, 144.16), control2: P(63.24, 139.2))
            p.addCurve(to: P(60, 102), control1: P(56.76, 124.8), control2: P(54.24, 109.92))
            p.closeSubpath()
            return p
        }()
        let p2: Path = {
            var p = Path()
            p.move(to: P(142, 92))
            p.addCurve(to: P(162, 108), control1: P(148.12, 90.56), control2: P(159.12, 100.08))
            p.addCurve(to: P(158, 136), control1: P(164.88, 115.92), control2: P(162.32, 128.8))
            p.addCurve(to: P(138, 148), control1: P(153.68, 143.2), control2: P(143.4, 151.6))
            p.addCurve(to: P(128, 116), control1: P(132.6, 144.4), control2: P(127.28, 126.08))
            p.addCurve(to: P(142, 92), control1: P(128.72, 105.92), control2: P(135.88, 93.44))
            p.closeSubpath()
            return p
        }()
        let p3: Path = {
            var p = Path()
            p.move(to: P(70, 118))
            p.addCurve(to: P(48, 142), control1: P(66.04, 122.32), control2: P(49.08, 134.26))
            p.addCurve(to: P(64, 161), control1: P(46.92, 149.74), control2: P(54.28, 156.68))
            p.addCurve(to: P(102, 166), control1: P(73.72, 165.32), control2: P(89.94, 166.54))
            p.addCurve(to: P(131, 158), control1: P(114.06, 165.46), control2: P(125.78, 159.44))
            return p
        }()
        let p4: Path = {
            var p = Path()
            p.move(to: P(70, 118))
            p.addCurve(to: P(48, 142), control1: P(66.04, 122.32), control2: P(49.08, 134.26))
            p.addCurve(to: P(64, 161), control1: P(46.92, 149.74), control2: P(54.28, 156.68))
            p.addCurve(to: P(102, 166), control1: P(73.72, 165.32), control2: P(89.94, 166.54))
            p.addCurve(to: P(131, 158), control1: P(114.06, 165.46), control2: P(125.78, 159.44))
            return p
        }()
        let p5: Path = {
            var p = Path()
            p.move(to: P(52.11, 153.49))
            p.addLine(to: P(55.62, 143.87))
            p.addCurve(to: P(51.89, 142.51), control1: P(56.51, 141.4), control2: P(52.79, 140.04))
            p.addLine(to: P(48.38, 152.13))
            p.addCurve(to: P(52.11, 153.49), control1: P(47.49, 154.6), control2: P(51.21, 155.96))
            p.closeSubpath()
            p.move(to: P(65.57, 163.24))
            p.addLine(to: P(75.46, 160.59))
            p.addCurve(to: P(74.43, 156.76), control1: P(78, 159.91), control2: P(76.97, 156.08))
            p.addLine(to: P(64.54, 159.41))
            p.addCurve(to: P(65.57, 163.24), control1: P(62, 160.09), control2: P(63.03, 163.92))
            p.closeSubpath()
            p.move(to: P(90.88, 166.98))
            p.addLine(to: P(101.12, 166.98))
            p.addCurve(to: P(101.12, 163.02), control1: P(103.75, 166.98), control2: P(103.75, 163.02))
            p.addLine(to: P(90.88, 163.02))
            p.addCurve(to: P(90.88, 166.98), control1: P(88.25, 163.02), control2: P(88.25, 166.98))
            p.closeSubpath()
            p.move(to: P(116.61, 163.06))
            p.addLine(to: P(126.7, 164.84))
            p.addCurve(to: P(127.39, 160.94), control1: P(129.29, 165.3), control2: P(129.98, 161.39))
            p.addLine(to: P(117.3, 159.16))
            p.addCurve(to: P(116.61, 163.06), control1: P(114.71, 158.7), control2: P(114.02, 162.61))
            p.closeSubpath()
            return p
        }()
        let p6: Path = {
            var p = Path()
            p.move(to: P(88.91, 130.29))
            p.addLine(to: P(77.91, 151.29))
            p.addCurve(to: P(92.09, 158.71), control1: P(72.99, 160.68), control2: P(87.17, 168.11))
            p.addLine(to: P(103.09, 137.71))
            p.addCurve(to: P(88.91, 130.29), control1: P(108.01, 128.32), control2: P(93.83, 120.89))
            p.closeSubpath()
            return p
        }()
        let p7: Path = {
            var p = Path()
            p.move(to: P(96.56, 41.43))
            p.addCurve(to: P(100.63, 12.82), control1: P(90.85, 36.99), control2: P(93.91, 15.54))
            p.addCurve(to: P(123.44, 30.57), control1: P(107.36, 10.1), control2: P(124.46, 23.42))
            p.addCurve(to: P(96.56, 41.43), control1: P(122.42, 37.72), control2: P(102.26, 45.87))
            p.closeSubpath()
            return p
        }()
        let p8: Path = {
            var p = Path()
            p.move(to: P(102.75, 33.54))
            p.addCurve(to: P(104.19, 21.63), control1: P(100.42, 31.65), control2: P(101.5, 22.72))
            p.addCurve(to: P(113.5, 29.19), control1: P(106.88, 20.54), control2: P(113.87, 26.21))
            p.addCurve(to: P(102.75, 33.54), control1: P(113.14, 32.17), control2: P(105.08, 35.43))
            p.closeSubpath()
            return p
        }()
        let p9: Path = {
            var p = Path()
            p.move(to: P(142.37, 35.04))
            p.addCurve(to: P(164.55, 16.51), control1: P(141.11, 27.93), control2: P(157.74, 14.03))
            p.addCurve(to: P(169.63, 44.96), control1: P(171.36, 18.99), control2: P(175.17, 40.33))
            p.addCurve(to: P(142.37, 35.04), control1: P(164.08, 49.59), control2: P(143.64, 42.15))
            p.closeSubpath()
            return p
        }()
        let p10: Path = {
            var p = Path()
            p.move(to: P(152.26, 33.32))
            p.addCurve(to: P(161.3, 25.43), control1: P(151.8, 30.36), control2: P(158.58, 24.44))
            p.addCurve(to: P(163.16, 37.29), control1: P(164.03, 26.43), control2: P(165.42, 35.31))
            p.addCurve(to: P(152.26, 33.32), control1: P(160.9, 39.26), control2: P(152.72, 36.28))
            p.closeSubpath()
            return p
        }()
        let clip_head: Path = {
            var p = Path()
            p.move(to: P(133, 30))
            p.addCurve(to: P(102, 39), control1: P(121.84, 30), control2: P(109.2, 33.24))
            p.addCurve(to: P(93, 62), control1: P(94.8, 44.76), control2: P(93.18, 53.9))
            p.addCurve(to: P(101, 84), control1: P(92.82, 70.1), control2: P(93.8, 78.42))
            p.addCurve(to: P(133, 93), control1: P(108.2, 89.58), control2: P(121.66, 93))
            p.addCurve(to: P(164, 84), control1: P(144.34, 93), control2: P(156.98, 89.58))
            p.addCurve(to: P(172, 62), control1: P(171.02, 78.42), control2: P(172, 70.1))
            p.addCurve(to: P(164, 39), control1: P(172, 53.9), control2: P(171.02, 44.76))
            p.addCurve(to: P(133, 30), control1: P(156.98, 33.24), control2: P(144.16, 30))
            p.closeSubpath()
            return p
        }()
        let p12: Path = {
            var p = Path()
            p.move(to: P(89, 68))
            p.addCurve(to: P(106, 56), control1: P(91.52, 72.68), control2: P(98.08, 57.44))
            p.addCurve(to: P(133, 60), control1: P(113.92, 54.56), control2: P(123.28, 60))
            p.addCurve(to: P(160, 56), control1: P(142.72, 60), control2: P(152.26, 54.56))
            p.addCurve(to: P(176, 68), control1: P(167.74, 57.44), control2: P(173.66, 72.68))
            p.addCurve(to: P(173, 30), control1: P(178.34, 63.32), control2: P(188.12, 36.84))
            p.addCurve(to: P(92, 30), control1: P(157.88, 23.16), control2: P(107.12, 23.16))
            p.addCurve(to: P(89, 68), control1: P(76.88, 36.84), control2: P(86.48, 63.32))
            p.closeSubpath()
            return p
        }()
        let p13: Path = {
            var p = Path()
            p.move(to: P(117.16, 31.12))
            p.addLine(to: P(119.48, 39.78))
            p.addCurve(to: P(122.84, 38.88), control1: P(120.08, 42), control2: P(123.43, 41.1))
            p.addLine(to: P(120.52, 30.22))
            p.addCurve(to: P(117.16, 31.12), control1: P(119.92, 28), control2: P(116.57, 28.9))
            p.closeSubpath()
            p.move(to: P(131.26, 27.52))
            p.addLine(to: P(131.26, 36.48))
            p.addCurve(to: P(134.74, 36.48), control1: P(131.26, 38.78), control2: P(134.74, 38.78))
            p.addLine(to: P(134.74, 27.52))
            p.addCurve(to: P(131.26, 27.52), control1: P(134.74, 25.22), control2: P(131.26, 25.22))
            p.closeSubpath()
            p.move(to: P(145.48, 30.22))
            p.addLine(to: P(143.16, 38.88))
            p.addCurve(to: P(146.52, 39.78), control1: P(142.57, 41.1), control2: P(145.92, 42))
            p.addLine(to: P(148.84, 31.12))
            p.addCurve(to: P(145.48, 30.22), control1: P(149.43, 28.9), control2: P(146.08, 28))
            p.closeSubpath()
            return p
        }()
        let p14: Path = {
            var p = Path()
            p.move(to: P(131, 75.5))
            p.addLine(to: P(135, 75.5))
            p.addLine(to: P(133, 78))
            p.closeSubpath()
            return p
        }()
        let p15: Path = {
            var p = Path()
            p.move(to: P(112.8, 75.5))
            p.addCurve(to: P(107, 78.9), control1: P(112.8, 77.38), control2: P(110.2, 78.9))
            p.addCurve(to: P(101.2, 75.5), control1: P(103.8, 78.9), control2: P(101.2, 77.38))
            p.addCurve(to: P(107, 72.1), control1: P(101.2, 73.62), control2: P(103.8, 72.1))
            p.addCurve(to: P(112.8, 75.5), control1: P(110.2, 72.1), control2: P(112.8, 73.62))
            p.closeSubpath()
            return p
        }()
        let p16: Path = {
            var p = Path()
            p.move(to: P(164.8, 75.5))
            p.addCurve(to: P(159, 78.9), control1: P(164.8, 77.38), control2: P(162.2, 78.9))
            p.addCurve(to: P(153.2, 75.5), control1: P(155.8, 78.9), control2: P(153.2, 77.38))
            p.addCurve(to: P(159, 72.1), control1: P(153.2, 73.62), control2: P(155.8, 72.1))
            p.addCurve(to: P(164.8, 75.5), control1: P(162.2, 72.1), control2: P(164.8, 73.62))
            p.closeSubpath()
            return p
        }()
        let p17: Path = {
            var p = Path()
            p.move(to: P(106, 65))
            p.addLine(to: P(87, 63.25))
            p.move(to: P(106, 70))
            p.addLine(to: P(87, 69.5))
            p.move(to: P(106, 75))
            p.addLine(to: P(87, 75.75))
            p.move(to: P(160, 65))
            p.addLine(to: P(179, 63.25))
            p.move(to: P(160, 70))
            p.addLine(to: P(179, 69.5))
            p.move(to: P(160, 75))
            p.addLine(to: P(179, 75.75))
            return p
        }()
        return CatPoseData(
            parts: [
            CatPart(path: clip_body, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p1, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p2, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_body, group: .base),
            CatPart(path: p3, fill: nil, stroke: CatColors.outline, lineWidth: 18.8, clip: nil, group: .tail),
            CatPart(path: p4, fill: nil, stroke: CatColors.orange, lineWidth: 13, clip: nil, group: .tail),
            CatPart(path: p5, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: nil, group: .tail),
            CatPart(path: p6, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p7, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p8, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p9, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p10, fill: CatColors.earPink, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: clip_head, fill: CatColors.cream, stroke: CatColors.outline, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p12, fill: CatColors.orange, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p13, fill: CatColors.stripe, stroke: nil, lineWidth: 4.2, clip: clip_head, group: .base),
            CatPart(path: p14, fill: CatColors.outline, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p15, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p16, fill: CatColors.blush, stroke: nil, lineWidth: 4.2, clip: nil, group: .base),
            CatPart(path: p17, fill: nil, stroke: CatColors.outline, lineWidth: 1.5, clip: nil, group: .base),
            ],
            face: CatFaceSpec(center: P(133, 66), scale: 1, rotationDegrees: 0, eyesClosed: false, look: P(-2, 0)),
            tailPivot: P(70, 118),
            pawPivot: nil,
            legPivots: [:]
        )
    }()
}

/// 把姿态坐标空间（200x180）的路径等比缩放到画布
struct CatPartShape: Shape {
    let base: Path
    func path(in rect: CGRect) -> Path {
        let s = rect.width / CatRig.viewW
        return base.applying(CGAffineTransform(scaleX: s, y: s))
    }
}
