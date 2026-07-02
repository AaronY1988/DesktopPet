//
//  TabbyCatView.swift
//  DesktopPet
//
//  狸花猫的纯矢量绘制视图。这一版特意收回到一个朴素、克制的造型：
//  普通虎斑配色（不做深浅两色"面罩"）、耳朵是普通大小的三角形、
//  尾巴是简单的一根，不做夸张卷曲——本轮之前尝试过"头挪到最右边"
//  "尾巴大幅卷起来""参考图那种深色头罩+大眼睛"等好几版更花哨的设计，
//  但每一版都引入了新的位置/观感问题，所以这里退回到更简单、更容易
//  保证"每个部件都在该在的地方"的版本，只保留两处确认过的具体 bug 修复：
//  1）耳朵不做成又尖又长的"角"，用比较矮胖的三角形；
//  2）静态站姿下腿的长度足够长，能从身体轮廓下边缘露出来，不会变成
//     贴在身体表面的一颗颗肉疙瘩。
//
//  用的是 IdleAnimator / SpringValue / TailSpringChain 这套通用底层
//  动画组件（小花狗换成矢量插画之后不再逐部件绘制，只还在用 IdleAnimator
//  里"整只宠物"级别的呼吸/摇晃，耳朵 spring / TailSpringChain 这两个
//  依赖"独立部件"的组件目前只有猫在用），叠加了一层猫特有的"自主行为
//  状态机"：闲置时不是简单地坐着不动，而是会自己在画布里踱步、舔爪子、
//  伸懒腰、追一只飞过的小鸟，符合"没事儿的时候可以自己跑跑、追追小鸟、
//  舔舔爪子"的要求。
//
//  三层动画分工：
//  1) 待机微动画层（IdleAnimator + PetPersonality.tabbyCat）：呼吸、
//     重心微晃、眨眼、耳朵抽动（猫耳更挺、回弹更快）、随机彩蛋——这里
//     解读成"尾尖抽动"，叠加在尾巴 spring 输出上。
//  2) spring 次级运动层：尾巴用 3 节链条，甩起来更灵活、更有"液体感"。
//  3) 自主行为状态机（CatActivity）+ 系统数据层：网络活跃度决定"要不要
//     全力奔跑"，网络空闲时由纯时间驱动的 `resolveActivity` 在几种
//     猫的典型行为之间循环切换，不依赖随机数，方便预览时行为可复现。
//

import SwiftUI

// MARK: - 猫耳朵三角形 Shape（旋转 180° 复用为鼻子）

struct CatEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 自主行为状态机

/// 猫在"网络空闲"（没有需要表现的系统负载）时的典型行为。
/// 不依赖随机数，纯粹由"已经闲置了多久"这个时间量决定，
/// 这样同一个 idleDuration 总能复现同一个动作，方便调试预览对比。
enum CatActivity: Equatable {
    case sit
    case pace
    case lickPaw
    case stretch
    case chaseBird
    case sleep
    case run
}

/// 一个约 32 秒的行为循环：踱步 -> 坐下 -> 舔爪子 -> 伸懒腰 -> 追小鸟 -> 循环。
/// 闲置超过 46 秒之后切换到睡眠，不再参与循环，直到有新的系统活动打断。
private func resolveActivity(idleDuration: Double) -> CatActivity {
    if idleDuration > 46 { return .sleep }
    let cycle = idleDuration.truncatingRemainder(dividingBy: 32)
    switch cycle {
    case 0..<7: return .pace
    case 7..<10: return .sit
    case 10..<16: return .lickPaw
    case 16..<19: return .stretch
    case 19..<27: return .chaseBird
    default: return .sit
    }
}

// MARK: - 主视图

struct TabbyCatView: View {
    let metrics: PetMetrics
    let bodyColor: Color
    let personality: PetPersonality

    @State private var idleAnimator: IdleAnimator
    @State private var tailChain: TailSpringChain
    @State private var squashAmount: CGFloat = 1.0
    @State private var idleStartTime: Date?

    init(metrics: PetMetrics, bodyColor: Color, personality: PetPersonality) {
        self.metrics = metrics
        self.bodyColor = bodyColor
        self.personality = personality
        _idleAnimator = State(initialValue: IdleAnimator(personality: personality))
        _tailChain = State(initialValue: TailSpringChain(
            segmentCount: personality.tailSegmentCount,
            stiffness: personality.tailStiffness,
            damping: personality.tailDamping
        ))
    }

    private let outlineColor = Color.black.opacity(0.30)
    private let outlineWidth: CGFloat = 1.2

    private var bellyScale: CGFloat {
        0.85 + CGFloat(metrics.memoryFraction) * (1.35 - 0.85)
    }

    private let idleThreshold = 0.04
    private var isIdle: Bool { metrics.networkActivity < idleThreshold }

    /// 全力奔跑时的摆腿频率/幅度，只有网络活跃时才会用到
    private var runLegFrequency: Double { 1.0 + metrics.networkActivity * (4.0 - 1.0) }
    private var runLegAmplitude: Double { 14 + metrics.networkActivity * 16 }
    private var isPanting: Bool { !isIdle && metrics.networkActivity > 0.6 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idleDuration = idleStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0

            // 网络活跃 -> 直接判定为 .run（系统数据层优先于自主行为状态机）；
            // 网络空闲 -> 交给纯时间驱动的行为循环决定具体在干什么。
            let activity: CatActivity = isIdle ? resolveActivity(idleDuration: idleDuration) : .run

            // --- 第 1 层：待机微动画 ---
            let idleState = idleAnimator.update(t: t)
            let breathingCG = CGFloat(idleState.breathScale)

            // --- 第 2 层：尾巴 spring 链（3 节，长尾更软更灵活），
            //     再叠加 quirkPulse 解读出的"尾尖抽动"彩蛋 ---
            let tailTargetAngle = tailTargetAngle(t: t, activity: activity)
            let tailSegmentValues = tailChain.update(t: t, drivingTarget: tailTargetAngle)
            let tailTipFlick = idleState.quirkPulse * 12
            let tailAngle = (tailSegmentValues.last ?? tailTargetAngle) + tailTipFlick

            // --- 第 3 层：自主行为 + 系统数据驱动的位移/抖动表现 ---
            let paceOffset = paceOffsetX(t: t, activity: activity)
            let bounce = bodyBounce(t: t, activity: activity)
            let shake = runningShake(t: t, activity: activity)
            let stepIndex = activity == .run ? Int(t * runLegFrequency * 2) : -1

            ZStack {
                shadowView(bounce: bounce, activity: activity)

                ZStack {
                    backdropHalo

                    if activity == .chaseBird {
                        birdView(t: t)
                    }

                    tailView(tailAngle: tailAngle, activity: activity)
                    legsView(t: t, role: .backFar, activity: activity)
                    legsView(t: t, role: .frontFar, activity: activity)
                    bodyView(breathing: breathingCG, squashAmount: squashAmount, activity: activity)
                    neckConnector(breathing: breathingCG)
                    bellyView(breathing: breathingCG)
                    legsView(t: t, role: .backNear, activity: activity)
                    legsView(t: t, role: .frontNear, activity: activity)
                    headView(t: t, activity: activity, idleState: idleState)
                }
                .offset(x: paceOffset + shake.width + CGFloat(idleState.swayX), y: bounce + shake.height)
                .compositingGroup()
                .shadow(color: .black.opacity(0.2), radius: 2.5, x: 0, y: 1)
            }
            .frame(width: 170, height: 150)
            .onChange(of: isIdle) { nowIdle in
                idleStartTime = nowIdle ? Date() : nil
                triggerSquash()
            }
            .onChange(of: stepIndex) { _ in
                if activity == .run { triggerSquash() }
            }
            .onAppear {
                idleStartTime = isIdle ? Date() : nil
            }
        }
    }

    private func triggerSquash() {
        squashAmount = 0.85
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            squashAmount = 1.0
        }
    }

    // MARK: - 背景光晕 / 地面阴影

    private var backdropHalo: some View {
        Ellipse()
            .fill(Color.black.opacity(0.09))
            .frame(width: 116, height: 84)
            .blur(radius: 13)
            .position(x: 82, y: 84)
    }

    private func shadowView(bounce: CGFloat, activity: CatActivity) -> some View {
        let liftRatio = Double(min(abs(bounce) / 10, 1))
        return Ellipse()
            .fill(Color.black.opacity(0.14 - 0.04 * liftRatio))
            .frame(width: 80 * (1 - 0.12 * CGFloat(liftRatio)), height: 12)
            .position(x: 82, y: 134)
    }

    // MARK: - 身体（呼吸 + 落地挤压，体积守恒缩放）

    private func bodyView(breathing: CGFloat, squashAmount: CGFloat, activity: CatActivity) -> some View {
        let stretchExtra: CGFloat = activity == .stretch ? 1.1 : 1.0
        let scaleY = breathing * squashAmount
        let scaleX = (1 / sqrt(scaleY)) * stretchExtra

        return FluffyBlobShape(bumpCount: 14, bumpDepth: 0.04)
            .fill(bodyColor)
            .overlay(
                FluffyBlobShape(bumpCount: 14, bumpDepth: 0.04)
                    .stroke(outlineColor, lineWidth: outlineWidth)
            )
            .overlay(tabbyStripes)
            .frame(width: 96, height: 52)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .position(x: 82, y: 94)
    }

    /// 狸花猫标志性的深色条纹：几条弧形短线叠在身体轮廓上，纯矢量绘制。
    private var tabbyStripes: some View {
        Canvas { context, size in
            let stripeColor = Color.black.opacity(0.14)
            for i in 0..<4 {
                let x = size.width * (0.24 + Double(i) * 0.18)
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height * 0.15))
                path.addQuadCurve(
                    to: CGPoint(x: x + size.width * 0.05, y: size.height * 0.55),
                    control: CGPoint(x: x - size.width * 0.03, y: size.height * 0.35)
                )
                context.stroke(path, with: .color(stripeColor), lineWidth: 2.5)
            }
        }
    }

    /// 脖子过渡色块：把头和身体两个独立蓬松轮廓之间的接缝盖住，
    /// 纯粹是拼接细节、不改变整体造型比例。
    private func neckConnector(breathing: CGFloat) -> some View {
        Ellipse()
            .fill(bodyColor)
            .frame(width: 26, height: 18)
            .scaleEffect(breathing, anchor: .bottom)
            .position(x: 93, y: 65)
    }

    private func bellyView(breathing: CGFloat) -> some View {
        Ellipse()
            .fill(Color(red: 0.93, green: 0.89, blue: 0.82))
            .overlay(Ellipse().stroke(outlineColor.opacity(0.5), lineWidth: 1))
            .frame(width: 34, height: 22)
            .scaleEffect(bellyScale * breathing, anchor: .center)
            .position(x: 80, y: 100)
    }

    // MARK: - 腿（四条独立部件，按当前行为切换姿态）

    private enum LegRole {
        case frontNear, frontFar, backNear, backFar

        var isFar: Bool {
            switch self {
            case .frontFar, .backFar: return true
            case .frontNear, .backNear: return false
            }
        }

        var isFront: Bool {
            switch self {
            case .frontFar, .frontNear: return true
            case .backFar, .backNear: return false
            }
        }
    }

    private func legsView(t: TimeInterval, role: LegRole, activity: CatActivity) -> some View {
        let baseX: CGFloat
        switch role {
        case .frontNear: baseX = 106
        case .frontFar: baseX = 101
        case .backNear: baseX = 42
        case .backFar: baseX = 47
        }
        let hipY: CGFloat = 92
        let sizeScale: CGFloat = role.isFar ? 0.8 : 1.0
        let legWidth: CGFloat = 10 * sizeScale
        let pawDiameter: CGFloat = 11 * sizeScale

        var swingDegrees: Double = 0
        // 静态/慢速姿态统一用 22 这个长度（不再单独给坐姿一个很短的腿长）。
        // 之前坐姿腿长只有 12，腿加爪子的总长度还不够到身体轮廓下边缘，
        // 爪子整个被身体盖住，看起来像贴在身上的肉疙瘩——统一用这个更长
        // 的默认值，就不会出现这个问题，也不需要额外隐藏后腿。
        var legLength: CGFloat = 22 * sizeScale
        var lift: CGFloat = 0

        switch activity {
        case .run:
            let phaseOffset: Double
            switch role {
            case .frontNear, .backFar: phaseOffset = 0
            case .frontFar, .backNear: phaseOffset = .pi
            }
            let phase = t * runLegFrequency * 2 * .pi + phaseOffset
            swingDegrees = sin(phase) * runLegAmplitude
            lift = CGFloat(max(0, sin(phase))) * 4.5

        case .pace:
            // 悠闲踱步：频率明显低于全力奔跑，幅度也更小
            let phaseOffset: Double
            switch role {
            case .frontNear, .backFar: phaseOffset = 0
            case .frontFar, .backNear: phaseOffset = .pi
            }
            let phase = t * 1.1 * 2 * .pi + phaseOffset
            swingDegrees = sin(phase) * 10
            lift = CGFloat(max(0, sin(phase))) * 2.5

        case .stretch:
            // 经典猫伸懒腰：前腿向前压低伸直，后腿缩短、臀部抬高
            if role.isFront {
                swingDegrees = -34
                legLength = 26 * sizeScale
            } else {
                swingDegrees = 6
                legLength = 15 * sizeScale
            }

        case .lickPaw:
            // 抬起一只前近侧腿舔爪子，其余腿保持静止支撑
            if role == .frontNear {
                let phase = t * 2.4
                swingDegrees = -70 + sin(phase) * 6
                legLength = 18 * sizeScale
            } else {
                legLength = 20 * sizeScale
            }

        case .chaseBird:
            // 抬头张望追小鸟，腿部保持警觉的小幅快速踏步
            let phase = t * 5
            swingDegrees = sin(phase) * 8
            legLength = 19 * sizeScale

        case .sit, .sleep:
            break // 用上面统一的默认 legLength，不再单独变短
        }

        let totalHeight = legLength + pawDiameter

        return VStack(spacing: 0) {
            Capsule()
                .fill(bodyColor)
                .overlay(Capsule().stroke(outlineColor, lineWidth: outlineWidth))
                .frame(width: legWidth, height: legLength)
            Circle()
                .fill(Color(red: 0.93, green: 0.89, blue: 0.82))
                .frame(width: pawDiameter, height: pawDiameter)
                .overlay(Circle().stroke(outlineColor.opacity(0.7), lineWidth: 1))
                .offset(y: -2.5 * sizeScale)
        }
        .frame(height: totalHeight, alignment: .top)
        .rotationEffect(.degrees(swingDegrees), anchor: .top)
        .position(x: baseX, y: hipY + totalHeight / 2)
        .offset(y: -lift)
        .colorMultiply(role.isFar ? Color(white: 0.88) : Color.white)
    }

    // MARK: - 尾巴（简单的一根，按行为决定摆动角度，spring 链条负责滞后甩动）

    private func tailTargetAngle(t: TimeInterval, activity: CatActivity) -> Double {
        switch activity {
        case .run:
            return sin(t * runLegFrequency * 2 * .pi) * 20
        case .pace:
            return sin(t * 1.1 * 2 * .pi) * 14 - 10
        case .chaseBird:
            return sin(t * 6) * 26
        case .stretch:
            return -18
        case .lickPaw:
            return sin(t * 0.8) * 6 - 6
        case .sit:
            return sin(t * 2 * .pi / 4.5) * 8
        case .sleep:
            return 0
        }
    }

    /// 尾巴的旋转支点（VStack 顶部）放在贴着身体左边缘、和后腿差不多高度
    /// 的地方，读起来像"从屁股长出来"，而不是从肩膀或者身体中段凭空
    /// 长出来。不做夸张的大幅度卷曲，就是一根简单的、会摆动的尾巴。
    private func tailView(tailAngle: Double, activity: CatActivity) -> some View {
        let puffed = activity == .chaseBird
        return Capsule()
            .fill(bodyColor)
            .overlay(Capsule().stroke(outlineColor, lineWidth: outlineWidth))
            .overlay(
                Canvas { context, size in
                    let stripeColor = Color.black.opacity(0.16)
                    for i in 0..<3 {
                        let y = size.height * (0.2 + Double(i) * 0.28)
                        let rect = CGRect(x: 0, y: y, width: size.width, height: size.height * 0.08)
                        context.fill(Path(rect), with: .color(stripeColor))
                    }
                }
            )
            .frame(width: puffed ? 14 : 9, height: 40)
            .rotationEffect(.degrees(-20 + tailAngle), anchor: .top)
            .position(x: 40, y: 116)
    }

    // MARK: - 头部

    private func headView(t: TimeInterval, activity: CatActivity, idleState: IdleState) -> some View {
        var headTilt = 0.0
        var headOffsetY: CGFloat = 0

        switch activity {
        case .run:
            headTilt = sin(t * runLegFrequency * 2 * .pi) * 4
        case .pace:
            headTilt = sin(t * 1.1 * 2 * .pi) * 3
        case .chaseBird:
            headTilt = sin(t * 3) * 10
            headOffsetY = -4
        case .stretch:
            headTilt = -8
            headOffsetY = 3
        case .lickPaw:
            headTilt = -12
            headOffsetY = 2
        case .sit:
            headTilt = 0
        case .sleep:
            headTilt = 6
            headOffsetY = 4
        }

        let headShake = idleState.quirkPulse * 8
        let isSleepy = activity == .sleep
        let eyeOpenL = isSleepy ? min(idleState.eyeOpenL, 0.08) : idleState.eyeOpenL
        let eyeOpenR = isSleepy ? min(idleState.eyeOpenR, 0.08) : idleState.eyeOpenR

        return ZStack {
            // 耳朵用比较矮胖的三角形（20×18，不是又尖又长的 22×24），
            // 角度也收着点（±12°），不会看起来像两只角。
            catEarView(rotation: -12, x: 92, y: 33, twitch: idleState.earTwitchL)
            catEarView(rotation: 12, x: 114, y: 31, twitch: idleState.earTwitchR)

            FluffyBlobShape(bumpCount: 10, bumpDepth: 0.045)
                .fill(bodyColor)
                .overlay(
                    FluffyBlobShape(bumpCount: 10, bumpDepth: 0.045)
                        .stroke(outlineColor, lineWidth: outlineWidth)
                )
                .frame(width: 50, height: 44)
                .position(x: 103, y: 50)

            // 额头 "M" 虎斑纹路：位置离眼睛留够距离（不紧贴着眼睛），
            // 免得看起来像皱眉；线条用平滑弧线，颜色也比较淡。
            Path { path in
                path.move(to: CGPoint(x: 89, y: 26))
                path.addQuadCurve(to: CGPoint(x: 103, y: 24), control: CGPoint(x: 95, y: 32))
                path.addQuadCurve(to: CGPoint(x: 117, y: 26), control: CGPoint(x: 109, y: 32))
            }
            .stroke(Color.black.opacity(0.14), lineWidth: 1.3)

            // 胡须
            Path { path in
                for dy: CGFloat in [-4, 0, 4] {
                    path.move(to: CGPoint(x: 79, y: 56 + dy))
                    path.addLine(to: CGPoint(x: 61, y: 54 + dy))
                    path.move(to: CGPoint(x: 125, y: 56 + dy))
                    path.addLine(to: CGPoint(x: 143, y: 54 + dy))
                }
            }
            .stroke(Color.black.opacity(0.35), lineWidth: 0.8)

            // 鼻子：三角形旋转 180°
            CatEarShape()
                .fill(Color(red: 0.85, green: 0.55, blue: 0.55))
                .frame(width: 7, height: 6)
                .rotationEffect(.degrees(180))
                .position(x: 103, y: 57)

            // 嘴巴
            Path { path in
                path.move(to: CGPoint(x: 103, y: 60))
                path.addQuadCurve(to: CGPoint(x: 97, y: 64), control: CGPoint(x: 101, y: 64))
                path.move(to: CGPoint(x: 103, y: 60))
                path.addQuadCurve(to: CGPoint(x: 109, y: 64), control: CGPoint(x: 105, y: 64))
            }
            .stroke(Color.black.opacity(0.4), lineWidth: 1)

            if isPanting {
                sweatView(t: t)
            }

            // 眼睛：猫眼是竖直的椭圆瞳孔，眨眼依旧用纵向缩放
            eyeView(eyeOpen: eyeOpenL)
                .position(x: 93, y: 48)
            eyeView(eyeOpen: eyeOpenR)
                .position(x: 111, y: 48)

            if isSleepy {
                sleepyZs(t: t)
            }
        }
        .rotationEffect(.degrees(headTilt + headShake), anchor: .bottom)
        .offset(y: headOffsetY)
    }

    private func eyeView(eyeOpen: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.72, green: 0.78, blue: 0.42))
                .frame(width: 8, height: 7)
            Ellipse()
                .fill(Color.black.opacity(0.85))
                .frame(width: 2.6, height: 6)
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1.6, height: 1.6)
                .offset(x: -1.4, y: -1.6)
        }
        .scaleEffect(x: 1, y: CGFloat(eyeOpen), anchor: .center)
    }

    private func catEarView(rotation: Double, x: CGFloat, y: CGFloat, twitch: Double) -> some View {
        CatEarShape()
            .fill(bodyColor)
            .overlay(CatEarShape().stroke(outlineColor, lineWidth: outlineWidth))
            .frame(width: 20, height: 18)
            .rotationEffect(.degrees(rotation + twitch))
            .position(x: x, y: y)
    }

    private func sleepyZs(t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let period = 2.4
                let phase = (t + Double(index) * 0.8).truncatingRemainder(dividingBy: period) / period
                let riseY = -CGFloat(phase) * 20
                let fadeOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.8 ? (1 - phase) / 0.2 : 1.0)

                Text("z")
                    .font(.system(size: 8 + CGFloat(index) * 3, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.7))
                    .position(x: 125 + CGFloat(index) * 5, y: 18 + riseY)
                    .opacity(fadeOpacity)
            }
        }
    }

    private func sweatView(t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let period = 0.9
                let phase = (t + Double(index) * 0.45).truncatingRemainder(dividingBy: period) / period
                let dropY = CGFloat(phase) * 14
                let dropOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.75 ? (1 - phase) / 0.25 : 1.0)

                SweatDropShape()
                    .fill(Color(red: 0.55, green: 0.78, blue: 0.95))
                    .overlay(SweatDropShape().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 6, height: 9)
                    .position(x: 85 + CGFloat(index) * 34, y: 36 + dropY)
                    .opacity(dropOpacity)
            }
        }
    }

    // MARK: - 追小鸟：一只简单的飞鸟精灵，只在 chaseBird 状态下出现

    private func birdView(t: TimeInterval) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 3) / 3
        let x = 20 + CGFloat(phase) * 130
        let y: CGFloat = 20 + CGFloat(sin(phase * .pi * 4)) * 8
        let wingFlap = sin(t * 14)

        return ZStack {
            Ellipse()
                .fill(Color(red: 0.35, green: 0.32, blue: 0.3))
                .frame(width: 12, height: 7)
            Path { path in
                path.move(to: CGPoint(x: -2, y: 0))
                path.addLine(to: CGPoint(x: -10, y: CGFloat(-wingFlap) * 5))
            }
            .stroke(Color(red: 0.35, green: 0.32, blue: 0.3), lineWidth: 2)
        }
        .position(x: x, y: y)
    }

    // MARK: - 踱步位移 / 奔跑弹跳抖动

    /// 悠闲踱步时在画布内小范围来回走动的横向位移（三角波，端点自然折返）。
    private func paceOffsetX(t: TimeInterval, activity: CatActivity) -> CGFloat {
        guard activity == .pace else { return 0 }
        let period = 6.0
        let phase = (t.truncatingRemainder(dividingBy: period)) / period // 0...1
        let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2 // 0->1->0
        return CGFloat((triangle - 0.5) * 24)
    }

    private func bodyBounce(t: TimeInterval, activity: CatActivity) -> CGFloat {
        guard activity == .run else { return 0 }
        let phase = t * runLegFrequency * 2 * 2 * .pi
        let height = 2.5 + metrics.networkActivity * 4
        return CGFloat(-abs(sin(phase)) * height)
    }

    private func runningShake(t: TimeInterval, activity: CatActivity) -> CGSize {
        guard activity == .run else { return .zero }
        let intensity = metrics.networkActivity
        let amplitude = 2.0 + intensity * 4.5
        let dx = (sin(t * 43) + sin(t * 71 + 1.1) * 0.6) / 1.6 * amplitude
        let dy = (sin(t * 57 + 0.5) + sin(t * 29) * 0.6) / 1.6 * amplitude * 0.6
        return CGSize(width: CGFloat(dx), height: CGFloat(dy))
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        TabbyCatView(metrics: PetMetrics(memoryFraction: 0.3, networkActivity: 0.0), bodyColor: Color(red: 0.78, green: 0.70, blue: 0.58), personality: .tabbyCat)
        TabbyCatView(metrics: PetMetrics(memoryFraction: 0.7, networkActivity: 0.85), bodyColor: Color(red: 0.78, green: 0.70, blue: 0.58), personality: .tabbyCat)
    }
    .padding()
    .background(Color.white)
}
