//
//  TabbyCatView.swift
//  DesktopPet
//
//  小橘猫（橘白猫）——姿态循环版，取代之前手绘的狸花猫造型。
//  六个姿态按用户提供的参考图矢量化（数据在 CatPoses.swift，由
//  tools/cat-rig/ 生成）：坐正、面包趴、舔毛、背对、行走、侧卧。
//
//  动画结构：
//  1) 姿态状态机：网络空闲时按时间循环 坐正 -> 溜达 -> 面包趴 -> 舔毛 ->
//     背对 -> 侧卧发呆，闲置超过 60 秒进入睡觉（侧卧 + 闭眼 + 飘 z）；
//     网络活跃时用行走姿态全力小跑。姿态切换用 0.3s 交叉淡入 + 一次落地
//     挤压，不做骨骼过渡（六个姿态的构图差异太大，淡入反而干净）。
//  2) 姿态内微动画：每个姿态不是静止贴图——尾巴是独立的"描边管道"部件，
//     由 TailSpringChain 驱动绕尾根摆动；行走姿态的四条腿各自绕腿根摆动；
//     舔毛姿态的爪子做舔的往复；眼睛参数化绘制，支持随机眨眼/睡觉闭眼。
//  3) 待机微动画层（IdleAnimator）：呼吸缩放、重心微晃、眨眼排期、
//     quirkPulse 解读为整体小摇晃。
//
//  bodyColor 参数保留只是为了兼容旧调用（DebugCompareView 等），新配色
//  固定在 CatColors 里（描摹自参考图），不再受温度/传入颜色影响。
//

import SwiftUI

// MARK: - 姿态状态机

enum CatActivity: Equatable {
    case sitFront   // 端正坐好（呼吸/眨眼/尾巴慢摆）
    case walkAbout  // 悠闲溜达（行走姿态 + 小范围来回走）
    case loaf       // 面包趴
    case groom      // 舔毛（爪子往复 + 眯眼）
    case sitBack    // 背对着看风景
    case lieRest    // 侧卧发呆
    case sleep      // 睡觉（侧卧 + 闭眼 + 飘 z）
    case run        // 网络活跃：小跑
}

/// 约 42 秒一轮的待机循环；闲置超过 60 秒睡觉。纯时间驱动，可复现。
private func resolveActivity(idleDuration: Double) -> CatActivity {
    if idleDuration > 60 { return .sleep }
    let cycle = idleDuration.truncatingRemainder(dividingBy: 42)
    switch cycle {
    case 0..<7:   return .sitFront
    case 7..<15:  return .walkAbout
    case 15..<21: return .loaf
    case 21..<27: return .groom
    case 27..<32: return .sitBack
    default:      return .lieRest
    }
}

/// 姿态内可动部件的瞬时角度/位移
private struct CatMotion {
    var legFF = 0.0, legRF = 0.0, legFN = 0.0, legRN = 0.0
    var pawAngle = 0.0
    var bounce = 0.0
    var paceX = 0.0
}

// MARK: - 主视图

struct TabbyCatView: View {
    let metrics: PetMetrics
    let bodyColor: Color // 兼容旧签名，新版不使用（配色见 CatColors）
    let personality: PetPersonality

    @State private var idleAnimator: IdleAnimator
    @State private var tailChain: TailSpringChain
    @State private var squashAmount: CGFloat = 1.0
    @State private var idleStartTime: Date?

    /// 姿态切换的交叉淡入：记录上一个姿态与切换时刻
    @State private var currentActivity: CatActivity = .sitFront
    @State private var previousActivity: CatActivity = .sitFront
    @State private var blendStartT: Double?

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

    /// 与 TabbyCatPet.canvasSize 保持一致。画布必须容得下最坏情况的
    /// 组合动作：内存缩放 1.18×（catH 135 放大后 159，比旧画布 150 还高）
    /// + 奔跑弹跳 + 踱步位移 + 彩蛋 wiggle 旋转 + 睡觉 z 字上飘，
    /// 否则悬浮窗会把超出的部件直接裁掉。
    private let canvasSize = CGSize(width: 200, height: 185)
    /// 猫的绘制宽度；姿态坐标空间是 200x180，等比缩放
    private let catW: CGFloat = 150
    private var catH: CGFloat { catW * CatRig.viewH / CatRig.viewW }
    /// 姿态空间的地面（y≈166）映射到画布后的落地基准线
    private var groundY: CGFloat { 165 }

    private let idleThreshold = 0.04
    private var isIdle: Bool { metrics.networkActivity < idleThreshold }
    private var isPanting: Bool { !isIdle && metrics.networkActivity > 0.6 }

    /// 小跑步频，网速越快越欢
    private var runFrequency: Double { 2.0 + metrics.networkActivity * 1.6 }

    /// 内存驱动的整体缩放（幅度收窄，避免出画布）
    private var memoryScale: CGFloat {
        0.9 + CGFloat(metrics.memoryFraction) * (1.18 - 0.9)
    }

    /// 姿态切换总时长。交叉淡入只占中段（见 body 里的 crossU），
    /// 首尾留给"下蹲蓄力/起身站稳"，整体比旧版 0.3s 硬淡入自然得多。
    private let blendDuration = 0.45

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idleDuration = idleStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            let activity: CatActivity = isIdle ? resolveActivity(idleDuration: idleDuration) : .run
            // onChange 下一帧才会记录切换，本帧先按旧姿态渲染避免闪变
            let shownActivity = activity == currentActivity ? activity : currentActivity

            let idleState = idleAnimator.update(t: t)
            let breathingCG = CGFloat(idleState.breathScale)

            let tailTarget = tailTargetAngle(t: t, activity: shownActivity)
            let tailValues = tailChain.update(t: t, drivingTarget: tailTarget)
            let tailAngle = (tailValues.last ?? tailTarget) + idleState.quirkPulse * 5

            let motion = self.motion(t: t, activity: shownActivity)
            let stepIndex = shownActivity == .run ? Int(t * runFrequency * 2) : -1
            let wiggle = idleState.quirkPulse * 4

            // 姿态切换进度（0-1 线性）
            let blendT: Double = {
                guard let start = blendStartT, previousActivity != shownActivity else { return 1 }
                return min((t - start) / blendDuration, 1)
            }()
            // 交叉淡入集中在中段：前 1/4 旧姿态原样保持，后 1/4 新姿态已
            // 站稳，中间一半时间完成换装。两张姿态同时半透明的窗口更短，
            // 而且正好发生在下蹲最深处，重影几乎看不出来。
            let crossU: Double = {
                let x = min(max((blendT - 0.25) / 0.5, 0), 1)
                return x * x * (3 - 2 * x)
            }()
            // 切换全程叠加一次"下蹲-回弹"（sin 半波，起止为 0）：躯干以
            // 脚底为锚点压扁再弹回，把换装藏进一个真实的蓄力动作里。
            let switchSquish = CGFloat(1 - 0.08 * sin(.pi * blendT))

            let scaleY = breathingCG * squashAmount * memoryScale * switchSquish
            let scaleX = (1 / sqrt(max(scaleY, 0.01))) * memoryScale

            ZStack {
                shadowView(bounce: CGFloat(motion.bounce))

                ZStack {
                    if blendT < 1 {
                        poseView(previousActivity, t: t, idleState: idleState,
                                 tailAngle: tailAngle, motion: self.motion(t: t, activity: previousActivity))
                            .opacity(1 - crossU)
                    }
                    poseView(shownActivity, t: t, idleState: idleState,
                             tailAngle: tailAngle, motion: motion)
                        .opacity(crossU)

                    if isPanting { sweatView(t: t) }
                    if shownActivity == .sleep { sleepyZs(t: t) }
                }
                .frame(width: catW, height: catH)
                .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
                .rotationEffect(.degrees(wiggle), anchor: .bottom)
                .offset(x: CGFloat(motion.paceX) + CGFloat(idleState.swayX),
                        y: CGFloat(motion.bounce))
                .compositingGroup()
                .shadow(color: .black.opacity(0.18), radius: 2.5, x: 0, y: 1)
                // 姿态空间的地面在 y=166/180 处，把它对齐到画布的 groundY
                .position(x: canvasSize.width / 2,
                          y: groundY - catH * (166.0 / 180.0) + catH / 2)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .animation(.easeInOut(duration: 0.3), value: memoryScale)
            .onChange(of: activity) { newActivity in
                previousActivity = currentActivity
                currentActivity = newActivity
                blendStartT = Date().timeIntervalSinceReferenceDate
                // 不再叠加 triggerSquash()：切换挤压由 switchSquish 按
                // blendT 确定性驱动，和交叉淡入严格同步（spring 版会抢跑）
            }
            .onChange(of: isIdle) { nowIdle in
                idleStartTime = nowIdle ? Date() : nil
            }
            .onChange(of: stepIndex) { _ in
                if shownActivity == .run { triggerSquash() }
            }
            .onAppear {
                idleStartTime = isIdle ? Date() : nil
                currentActivity = isIdle ? .sitFront : .run
                previousActivity = currentActivity
            }
        }
    }

    // MARK: - 姿态选择 / 微动画参数

    private func poseData(for activity: CatActivity) -> CatPoseData {
        switch activity {
        case .sitFront:        return CatPoses.sitFront
        case .walkAbout, .run: return CatPoses.walk
        case .loaf:            return CatPoses.loaf
        case .groom:           return CatPoses.groom
        case .sitBack:         return CatPoses.sitBack
        case .lieRest, .sleep: return CatPoses.lieSide
        }
    }

    private func motion(t: Double, activity: CatActivity) -> CatMotion {
        var m = CatMotion()
        switch activity {
        case .walkAbout:
            let phi = t * 1.4 * 2 * .pi
            let amp = 9.0
            m.legFN = amp * sin(phi); m.legRF = amp * sin(phi)
            m.legFF = -amp * sin(phi); m.legRN = -amp * sin(phi)
            m.bounce = -abs(sin(phi)) * 1.5
            let period = 8.0
            let phase = t.truncatingRemainder(dividingBy: period) / period
            let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            // ±10：踱步极端位置 + 内存最大缩放同时发生时仍留在画布内
            m.paceX = (triangle - 0.5) * 20
        case .run:
            let phi = t * runFrequency * 2 * .pi
            let amp = 14 + 10 * metrics.networkActivity
            m.legFN = amp * sin(phi); m.legRF = amp * sin(phi)
            m.legFF = -amp * sin(phi); m.legRN = -amp * sin(phi)
            m.bounce = -abs(sin(phi)) * (2.5 + 4 * metrics.networkActivity)
        case .groom:
            // 舔毛：爪子小幅往复，像在往脸上蹭
            m.pawAngle = 9 * sin(t * 1.7 * 2 * .pi) - 3
        default:
            break
        }
        return m
    }

    private func tailTargetAngle(t: Double, activity: CatActivity) -> Double {
        switch activity {
        case .sitFront:  return 7 * sin(t * 2 * .pi / 4.5)
        case .walkAbout: return 10 * sin(t * 1.4 * 2 * .pi + 1)
        case .run:       return 14 * sin(t * runFrequency * 2 * .pi + 1)
        case .loaf:      return 4 * sin(t * 0.7 * 2 * .pi)
        case .groom:     return 5 * sin(t * 1.1 * 2 * .pi)
        case .sitBack:   return 8 * sin(t * 0.55 * 2 * .pi)
        case .lieRest:   return 3 * sin(t * 0.5 * 2 * .pi)
        case .sleep:     return 0
        }
    }

    private func triggerSquash() {
        squashAmount = 0.94
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            squashAmount = 1.0
        }
    }

    // MARK: - 姿态渲染

    private func poseView(_ activity: CatActivity,
                          t: Double,
                          idleState: IdleState,
                          tailAngle: Double,
                          motion: CatMotion) -> some View {
        let data = poseData(for: activity)
        return ZStack {
            ForEach(Array(data.parts.enumerated()), id: \.offset) { _, part in
                partView(part, data: data, tailAngle: tailAngle, motion: motion)
            }
            if let face = data.face {
                faceView(face, activity: activity, idleState: idleState)
            }
        }
    }

    /// 单个部件：填充 + 描边（描边宽度按画布缩放），斑块 clip 到宿主轮廓，
    /// 再按所属分组套旋转（尾巴绕尾根、腿绕腿根、舔毛爪子绕腕部）。
    private func partView(_ part: CatPart,
                          data: CatPoseData,
                          tailAngle: Double,
                          motion: CatMotion) -> some View {
        let shape = CatPartShape(base: part.path)
        let sw = part.lineWidth * (catW / CatRig.viewW)

        var view = AnyView(ZStack {
            if let fill = part.fill {
                shape.fill(fill)
            }
            if let strokeColor = part.stroke {
                shape.stroke(strokeColor, style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))
            }
        })
        if let clip = part.clip {
            view = AnyView(view.clipShape(CatPartShape(base: clip)))
        }

        switch part.group {
        case .tail:
            view = AnyView(view.rotationEffect(.degrees(tailAngle), anchor: CatRig.anchor(data.tailPivot)))
        case .paw:
            if let pivot = data.pawPivot {
                view = AnyView(view.rotationEffect(.degrees(motion.pawAngle), anchor: CatRig.anchor(pivot)))
            }
        case .legFF, .legRF, .legFN, .legRN:
            if let pivot = data.legPivots[part.group] {
                let angle: Double
                switch part.group {
                case .legFF: angle = motion.legFF
                case .legRF: angle = motion.legRF
                case .legFN: angle = motion.legFN
                case .legRN: angle = motion.legRN
                default: angle = 0
                }
                view = AnyView(view.rotationEffect(.degrees(angle), anchor: CatRig.anchor(pivot)))
            }
        case .base:
            break
        }
        return view
    }

    // MARK: - 参数化眼睛（支持眨眼 / 睡觉闭眼 / 舔毛眯眼）

    private func faceView(_ face: CatFaceSpec, activity: CatActivity, idleState: IdleState) -> some View {
        let ss = catW / CatRig.viewW
        let closed = face.eyesClosed || activity == .sleep
        let eyeOpen = closed ? 0 : idleState.eyeOpenL
        let ex = 17 * face.scale
        let eyeY = face.center.y + 2 * face.scale + face.look.y

        return ZStack {
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { sgn in
                let cx = face.center.x + sgn * ex + face.look.x
                if closed || eyeOpen < 0.12 {
                    // 眯眼/闭眼：向下鼓的舒服弧线
                    ClosedEyeShape(cx: cx, cy: eyeY, r: 4.6 * face.scale)
                        .stroke(CatColors.outline,
                                style: StrokeStyle(lineWidth: 2.8 * face.scale * ss, lineCap: .round))
                } else {
                    Ellipse()
                        .fill(CatColors.outline)
                        .frame(width: 8.8 * face.scale * ss, height: 10.4 * face.scale * ss)
                        .scaleEffect(x: 1, y: CGFloat(max(eyeOpen, 0.12)), anchor: .center)
                        .position(x: cx * ss, y: eyeY * ss)
                }
            }
        }
        .rotationEffect(.degrees(Double(face.rotationDegrees)), anchor: CatRig.anchor(face.center))
    }

    // MARK: - 地面阴影 / 浮层特效

    private func shadowView(bounce: CGFloat) -> some View {
        let liftRatio = Double(min(abs(min(bounce, 0)) / 10, 1))
        return Ellipse()
            .fill(Color.black.opacity(0.14 - 0.04 * liftRatio))
            // 阴影宽度跟猫身宽走（画布为了给动作留余量比猫大不少）
            .frame(width: catW * 0.59 * (1 - 0.12 * CGFloat(liftRatio)), height: 11)
            .position(x: canvasSize.width * 0.5, y: groundY + 4)
    }

    /// 汗滴挂在行走姿态的头旁边（姿态坐标 ≈ (30, 34)）
    private func sweatView(t: TimeInterval) -> some View {
        let ss = catW / CatRig.viewW
        return ZStack {
            ForEach(0..<2, id: \.self) { index in
                let period = 0.9
                let phase = (t + Double(index) * 0.45).truncatingRemainder(dividingBy: period) / period
                let dropY = CGFloat(phase) * 13
                let dropOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.75 ? (1 - phase) / 0.25 : 1.0)

                SweatDropShape()
                    .fill(Color(red: 0.55, green: 0.78, blue: 0.95))
                    .overlay(SweatDropShape().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 6, height: 9)
                    .position(x: 30 * ss + CGFloat(index) * 9, y: 34 * ss + dropY)
                    .opacity(dropOpacity)
            }
        }
    }

    /// 睡觉的 z 字从侧卧姿态的头顶（姿态坐标 ≈ (150, 22)）往上飘
    private func sleepyZs(t: TimeInterval) -> some View {
        let ss = catW / CatRig.viewW
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let period = 2.4
                let phase = (t + Double(index) * 0.8).truncatingRemainder(dividingBy: period) / period
                let riseY = -CGFloat(phase) * 20
                let fadeOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.8 ? (1 - phase) / 0.2 : 1.0)

                Text("z")
                    .font(.system(size: 8 + CGFloat(index) * 3, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.7))
                    .position(x: 150 * ss + CGFloat(index) * 6, y: 22 * ss + riseY)
                    .opacity(fadeOpacity)
            }
        }
    }
}

/// 闭眼弧线（在姿态坐标空间定义，缩放到画布）
private struct ClosedEyeShape: Shape {
    let cx: CGFloat
    let cy: CGFloat
    let r: CGFloat
    func path(in rect: CGRect) -> Path {
        let s = rect.width / CatRig.viewW
        var p = Path()
        p.move(to: CGPoint(x: (cx - r) * s, y: cy * s))
        p.addQuadCurve(to: CGPoint(x: (cx + r) * s, y: cy * s),
                       control: CGPoint(x: cx * s, y: (cy + r * 0.9) * s))
        return p
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        TabbyCatView(metrics: PetMetrics(memoryFraction: 0.3, networkActivity: 0.0), bodyColor: .white, personality: .tabbyCat)
        TabbyCatView(metrics: PetMetrics(memoryFraction: 0.7, networkActivity: 0.85), bodyColor: .white, personality: .tabbyCat)
    }
    .padding()
    .background(Color.white)
}
