//
//  SpottedDogView.swift
//  DesktopPet
//
//  小花狗——包装一整张矢量插画（Assets.xcassets/SpottedDog，用户提供的
//  SVG 转成 PDF 加入的），不再是逐个部件手绘的 SwiftUI Shape。
//
//  和之前比熊矢量版最大的区别：比熊的身体/头/耳朵/尾巴/腿是七八个独立
//  子视图各自动画，这只狗是一整张画死的插画，没法单独控制某个部位。
//  能做的只是"整张图"级别的变换，具体取舍如下：
//
//  保留的效果（都是"整只宠物一起动"的效果，原样复用）：
//  - 呼吸缩放（IdleAnimator.breathScale）：整只狗随呼吸微微鼓缩，
//    复用原来只套在身体这一个形状上的振幅，直接套在整张图上效果依然自然。
//  - 待机重心微晃（idleState.swayX）、奔跑弹跳 + 高频抖动：这几个本来
//    就是整只宠物一起位移的效果，原样保留。
//  - 冒汗特效、打盹时头顶飘的 "z" 字：这两个本来就是独立叠加在头部
//    附近的浮层，不依赖对头部本身的形变，原样保留，只是坐标从"头部
//    子视图的局部坐标"改成了"整张图的相对坐标估算头部大概在哪"。
//  - 落地/坐下瞬间的挤压回弹（squashAmount）：作用对象从"身体形状"
//    换成了"整张图"，视觉逻辑不变。
//
//  改造过的效果：
//  - "内存越大肚子越大"改成了"内存越大整只狗略微变大一圈"
//    （memoryScale，区间从原来肚子的 0.8~1.6x 收窄到 0.9~1.25x）——
//    因为肚子和身体现在画在同一张图里分不开，只能做整体缩放的近似。
//  - 待机彩蛋 quirkPulse：原来比熊是"甩头"，猫是"尾尖抽动"，这里
//    因为甩不了头，改成了一次小幅度的整体摇晃（wiggle）。
//
//  彻底失去的效果：耳朵抽动、尾巴 spring 甩动、四条腿摆动步态、坐下时
//  腿缩短的姿态切换、眨眼——这些都需要能单独控制局部部件才能做，
//  单张矢量插画做不到。如果之后想找回来，两个方向：
//  1) 请人把这只狗拆成分层的矢量部件（身体/头/耳朵/尾巴/腿各一个文件），
//     代码这边照抄 TabbyCatView.swift 的做法接进来；
//  2) 补充几张不同姿势（站/坐/走）的插画，做成姿势切换式动画，
//     没有连续的物理惯性感，但比纯静止好。
//

import SwiftUI

struct SpottedDogView: View {
    let metrics: PetMetrics
    let personality: PetPersonality

    /// 待机微动画层：呼吸、重心微晃、待机彩蛋摇晃。眨眼、耳朵抽动这两项
    /// IdleAnimator 依然会算，但这只狗没有可以单独眨/抽动的部件，算出来
    /// 的 eyeOpenL/R、earTwitchL/R 直接丢弃不用。
    @State private var idleAnimator: IdleAnimator

    /// 落地/坐下瞬间的挤压强度，1 = 常态，作用对象是整张插画而不是单个身体形状。
    @State private var squashAmount: CGFloat = 1.0

    /// 记录"从什么时候开始闲置"，用于判断是否进入长时间打盹状态。
    @State private var idleStartTime: Date?

    init(metrics: PetMetrics, personality: PetPersonality) {
        self.metrics = metrics
        self.personality = personality
        _idleAnimator = State(initialValue: IdleAnimator(personality: personality))
    }

    private let canvasSize = CGSize(width: 150, height: 170)

    /// 网络活跃度低于该阈值时视为"闲置"
    private let idleThreshold = 0.04
    private var isIdle: Bool { metrics.networkActivity < idleThreshold }

    /// 内存驱动的整体缩放：0.9x~1.25x。比原来比熊"肚子" 0.8~1.6x 的区间
    /// 收窄了不少，因为现在是整只狗一起变大，区间太夸张会显得比例失真。
    private var memoryScale: CGFloat {
        0.9 + CGFloat(metrics.memoryFraction) * (1.25 - 0.9)
    }

    /// "迈步"频率，只用来驱动奔跑弹跳/抖动的节奏，不再驱动真的腿部摆动。
    private var stepFrequency: Double {
        isIdle ? 0 : 0.7 + metrics.networkActivity * (3.4 - 0.7)
    }

    /// 网速达到一定阈值时冒汗，呼应"跑起来了"的观感
    private var isPanting: Bool { !isIdle && metrics.networkActivity > 0.55 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idleDuration = idleStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            // 闲置超过 12 秒视为"睡着"，触发头顶漂浮 "z" 字的打盹小动画
            let isSleepy = isIdle && idleDuration > 12

            let idleState = idleAnimator.update(t: t)
            let breathingCG = CGFloat(idleState.breathScale)

            let bounce = runningBounce(t: t)
            let shake = runningShake(t: t)
            let stepIndex = isIdle ? -1 : Int(t * stepFrequency * 2)

            // Y 方向缩放 = 呼吸 × 落地挤压 × 内存整体缩放；
            // X 方向按 1/sqrt(scaleY) 反向联动，保持"看起来体积不变"，
            // 再额外乘一次 memoryScale，让内存变大时是"整体变大"而不只是变瘦变高。
            let scaleY = breathingCG * squashAmount * memoryScale
            let scaleX = (1 / sqrt(max(scaleY, 0.01))) * memoryScale
            let wiggle = idleState.quirkPulse * 10

            ZStack {
                shadowView(bounce: bounce)

                ZStack {
                    Image("SpottedDog")
                        .resizable()
                        .scaledToFit()
                        .frame(width: canvasSize.width * 0.82, height: canvasSize.height * 0.82)
                        .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)

                    if isPanting {
                        sweatView(t: t)
                    }
                    if isSleepy {
                        sleepyZs(t: t)
                    }
                }
                .offset(x: shake.width + CGFloat(idleState.swayX), y: bounce + shake.height)
                .rotationEffect(.degrees(wiggle), anchor: .bottom)
                .compositingGroup()
                .shadow(color: .black.opacity(0.18), radius: 2.5, x: 0, y: 1)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .animation(.easeInOut(duration: 0.3), value: memoryScale)
            .onChange(of: isIdle) { nowIdle in
                idleStartTime = nowIdle ? Date() : nil
                triggerSquash() // 闲置/重新活跃这类状态切换也算一次"落地"
            }
            .onChange(of: stepIndex) { _ in
                if !isIdle { triggerSquash() }
            }
            .onAppear {
                idleStartTime = isIdle ? Date() : nil
            }
        }
    }

    /// 落地/坐下瞬间的挤压回弹：立刻压扁到 0.9，再用 SwiftUI 的
    /// `.spring(response:dampingFraction:)` 带一点过冲地弹回 1。
    private func triggerSquash() {
        squashAmount = 0.9
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            squashAmount = 1.0
        }
    }

    // MARK: - 地面阴影

    private func shadowView(bounce: CGFloat) -> some View {
        let liftRatio = Double(min(abs(bounce) / 12, 1))
        return Ellipse()
            .fill(Color.black.opacity(0.15 - 0.05 * liftRatio))
            .frame(width: canvasSize.width * 0.55 * (1 - 0.15 * CGFloat(liftRatio)), height: 12)
            .position(x: canvasSize.width * 0.5, y: canvasSize.height * 0.92)
    }

    // MARK: - 头部附近的浮层特效（汗滴 / 打盹 z 字）

    /// 这张插画里狗抬头朝右上方、嘴巴张开的位置大概在整张图宽度 78%、
    /// 高度 15% 附近，汗滴/z 字的坐标都是照这个估算出来的相对位置，
    /// 不是精确对齐插画里的某个像素点。
    private func sweatView(t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let period = 0.9
                let phase = (t + Double(index) * 0.45).truncatingRemainder(dividingBy: period) / period
                let dropY = CGFloat(phase) * 16
                let dropOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.75 ? (1 - phase) / 0.25 : 1.0)
                let dropScale = 0.7 + 0.3 * CGFloat(min(phase * 3, 1))

                SweatDropShape()
                    .fill(Color(red: 0.55, green: 0.78, blue: 0.95))
                    .overlay(SweatDropShape().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 7, height: 10)
                    .scaleEffect(dropScale)
                    .position(x: canvasSize.width * 0.8 + CGFloat(index) * 10, y: canvasSize.height * 0.18 + dropY)
                    .opacity(dropOpacity)
            }
        }
    }

    private func sleepyZs(t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let period = 2.4
                let phase = (t + Double(index) * 0.8).truncatingRemainder(dividingBy: period) / period
                let riseY = -CGFloat(phase) * 22
                let fadeOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.8 ? (1 - phase) / 0.2 : 1.0)

                Text("z")
                    .font(.system(size: 9 + CGFloat(index) * 3, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.7))
                    .position(x: canvasSize.width * 0.75 + CGFloat(index) * 5, y: canvasSize.height * 0.1 + riseY)
                    .opacity(fadeOpacity)
            }
        }
    }

    // MARK: - 纯时间驱动的系统数据表现（跑动相关，独立于待机层）

    /// 奔跑弹跳：只在移动状态下出现，跟随迈步频率的两倍起伏（一步一次小跳），
    /// 网速越快跳得越明显。
    private func runningBounce(t: TimeInterval) -> CGFloat {
        guard !isIdle, stepFrequency > 0 else { return 0 }
        let phase = t * stepFrequency * 2 * 2 * .pi
        let height = 3 + metrics.networkActivity * 5
        let bounceMagnitude = abs(sin(phase)) * height
        return CGFloat(-bounceMagnitude)
    }

    /// 奔跑高频抖动：叠加两组不同频率、不同相位的正弦波，制造出"跑得非常
    /// 卖力、浑身都在抖"的夸张卡通震动感。网速越高振幅越大。
    private func runningShake(t: TimeInterval) -> CGSize {
        guard !isIdle else { return .zero }
        let intensity = metrics.networkActivity
        let amplitude = 2.2 + intensity * 5.0
        let dx = (sin(t * 41) + sin(t * 67 + 1.3) * 0.6) / 1.6 * amplitude
        let dy = (sin(t * 53 + 0.7) + sin(t * 31) * 0.6) / 1.6 * amplitude * 0.6
        return CGSize(width: CGFloat(dx), height: CGFloat(dy))
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        SpottedDogView(metrics: PetMetrics(memoryFraction: 0.2, networkActivity: 0.0), personality: .spottedDog)
        SpottedDogView(metrics: PetMetrics(memoryFraction: 0.9, networkActivity: 0.8), personality: .spottedDog)
    }
    .padding()
    .background(Color.white)
}
