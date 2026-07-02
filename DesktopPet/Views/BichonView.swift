//
//  BichonView.swift
//  DesktopPet
//
//  白色比熊犬的纯矢量绘制视图。所有部件（身体、肚子、腿、耳朵、尾巴）
//  都是独立的子视图，不依赖任何图片资源。
//
//  动画分成三层，按优先级从底到顶叠加：
//  1) 待机微动画层（IdleAnimator，见 Animation/ 目录）：呼吸、重心微晃、
//     随机眨眼、随机耳朵抽动、随机"甩头"彩蛋——不管系统指标变不变，
//     这一层永远在跑，负责"活着"的底噪。两个角色共用同一份实现，
//     手感差异全部来自 `PetPersonality.bichon`。
//  2) spring 次级运动层（SpringValue / TailSpringChain）：尾巴不是直接
//     贴着目标角度摆，而是被"身体想要摆动的角度"牵引着、带一点滞后和
//     回弹地追上去，读起来更像真的有惯性的软组织，而不是刚体在转。
//  3) 系统数据驱动层（原有的 SystemMonitor 映射）：肚子大小 <- 内存，
//     摆腿/奔跑速度、抖动、喘气冒汗 <- 网速。这一层负责"状态"表达。
//
//  第 1 层和第 3 层的组合方式是相乘而不是覆盖——比如最终肚子的竖直缩放
//  是 `bellyScale（内存决定）× idleState.breathScale（呼吸）`，
//  躯干的挤压拉伸是在这个基础上再叠加一次落地/坐下瞬间的 squash。
//
//  造型说明（历次修正，保留意图记录）：
//  1) 四条腿（前近/前远/后近/后远）对角线同相摆动，是真实四足动物小跑
//     步态，避免"顺拐"；水平位置避开肚子椭圆范围，不会从肚子中间穿出。
//  2) 头和身体之间有一个不描边的"脖子"过渡色块盖住接缝。
//  3) 所有蓬松轮廓的凸起幅度调小、凸起数量调多，做出细腻卷毛质感。
//
//  可见度增强（三层兜底，应对纯白背景）：加深描边、身体身后加模糊光晕、
//  整只宠物合成一层后统一打外部投影。
//

import SwiftUI

// MARK: - 蓬松轮廓 Shape

/// 通用的"蓬松云朵状"轮廓 Shape，通过在椭圆边缘叠加正弦波纹模拟卷毛质感，
/// 比熊的身体、头部、尾巴绒球都基于这一个 Shape 参数化生成，不需要任何位图资源。
struct FluffyBlobShape: Shape {
    /// 边缘凸起的数量（卷毛簇的数量）
    var bumpCount: Int = 10
    /// 凸起深度，相对半径的比例。数值越小卷毛质感越细腻柔和，
    /// 数值越大越像锯齿/星星——比熊应该用偏小的值。
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
/// 给跑得很拼命（吐舌头喘气）的比熊用。
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

// MARK: - 主视图

struct BichonView: View {
    let metrics: PetMetrics
    let bodyColor: Color
    let personality: PetPersonality

    /// 待机微动画层（呼吸/重心微晃/眨眼/耳朵抽动/甩头彩蛋），
    /// 尾巴的次级 spring 链条。用自定义 init 在创建时就按 personality
    /// 配好参数，之后 @State 保证它们在 body 反复重算时保持同一份实例。
    @State private var idleAnimator: IdleAnimator
    @State private var tailChain: TailSpringChain

    /// 落地/坐下瞬间的挤压强度，1 = 常态。触发后由 SwiftUI 的
    /// `.spring(response:dampingFraction:)` 负责插值回弹，
    /// 不用手写回弹曲线（这里用的是 SwiftUI 动画系统而不是 SpringValue，
    /// 因为这是一次性的离散事件插值，不是持续追踪目标的物理量）。
    @State private var squashAmount: CGFloat = 1.0

    /// 记录"从什么时候开始闲置"，用于判断是否进入长时间打盹状态。
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

    // MARK: 可见度增强参数

    /// 描边颜色：比最初版本的 8% 不透明度黑色明显加深，纯白背景下也能看清轮廓
    private let outlineColor = Color.black.opacity(0.30)
    private let outlineWidth: CGFloat = 1.3

    // MARK: 系统数据映射

    /// 肚子缩放：内存占用 0~100% -> 0.8x~1.6x
    private var bellyScale: CGFloat {
        0.8 + CGFloat(metrics.memoryFraction) * (1.6 - 0.8)
    }

    /// 网络活跃度低于该阈值时视为"闲置"，进入坐下待机形态
    private let idleThreshold = 0.04

    private var isIdle: Bool { metrics.networkActivity < idleThreshold }

    /// 摆腿频率（Hz）：闲置为 0（坐下不动），否则 0.7Hz 慢走 ~ 3.4Hz 疾跑
    private var legFrequency: Double {
        isIdle ? 0 : 0.7 + metrics.networkActivity * (3.4 - 0.7)
    }

    /// 摆腿幅度（度），网速越快摆幅越大，奔跑感更强
    private var legSwingAmplitude: Double {
        12 + metrics.networkActivity * 14
    }

    /// 坐下姿态权重 0...1：用来把腿"缩"进身体里
    private var sitAmount: CGFloat { isIdle ? 1 : 0 }

    /// 尾巴"本来想摆到"的频率：始终在摇，网络越活跃摇得越快。
    /// 这是喂给 spring 链条的目标信号，不是最终渲染角度。
    private var tailFrequency: Double {
        isIdle ? 0.6 : 1.2 + metrics.networkActivity * 2.6
    }

    /// 尾巴"本来想摆到"的幅度：闲置时小幅度慢摇，奔跑时大幅度快摇
    private var tailAmplitude: Double {
        isIdle ? 8 : 14 + metrics.networkActivity * 12
    }

    /// 网速达到一定阈值时，让比熊吐舌头喘气，呼应"跑起来了"的观感
    private var isPanting: Bool { !isIdle && metrics.networkActivity > 0.55 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idleDuration = idleStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            // 闲置超过 12 秒视为"睡着"，触发闭眼 + 漂浮 Zzz 的打盹小动画
            let isSleepy = isIdle && idleDuration > 12

            // --- 第 1 层：待机微动画（呼吸/重心微晃/眨眼/耳朵抽动/甩头彩蛋） ---
            let idleState = idleAnimator.update(t: t)
            let breathingCG = CGFloat(idleState.breathScale)

            // --- 第 2 层：尾巴的 spring 次级运动。
            //     "目标角度"仍由原来的活跃度驱动摇摆公式给出，
            //     但不直接拿来渲染，而是喂给 spring 链条，链条输出的
            //     （滞后 + 回弹）角度才是最终渲染角度——这样尾巴摆动
            //     天然带有"跟不上身体、慢半拍甩过去"的惯性感。 ---
            let tailTargetAngle = tailWagTargetAngle(t: t)
            let tailSegmentValues = tailChain.update(t: t, drivingTarget: tailTargetAngle)
            let tailAngle = tailSegmentValues.last ?? tailTargetAngle

            // --- 第 3 层：系统数据驱动的奔跑表现 ---
            let bounce = runningBounce(t: t)
            let shake = runningShake(t: t)
            // 用"迈了几步"这个离散量的变化去触发落地挤压，
            // 而不是每帧都检测——`.onChange(of:)` 天然只在值变化时触发一次。
            let stepIndex = isIdle ? -1 : Int(t * legFrequency * 2)

            ZStack {
                shadowView(bounce: bounce)

                // 除地面阴影外的所有部件打包成一组，一起做奔跑弹跳位移，
                // 并在最外层统一合成 + 打投影，解决"白毛在白背景下看不清"的问题。
                ZStack {
                    backdropHalo
                    tailView(tailAngle: tailAngle)
                    // 远侧的两条腿画在身体后面（会被身体部分挡住），
                    // 近侧的两条腿画在身体前面（完全可见）——
                    // 四条腿都在跑，且有前后遮挡的纵深感。
                    legsView(t: t, role: .backFar)
                    legsView(t: t, role: .frontFar)
                    bodyView(breathing: breathingCG, squashAmount: squashAmount)
                    neckConnector(breathing: breathingCG)
                    bellyView(breathing: breathingCG)
                    legsView(t: t, role: .backNear)
                    legsView(t: t, role: .frontNear)
                    headView(t: t, isSleepy: isSleepy, idleState: idleState)
                }
                // 系统数据驱动的横向抖动/弹跳，叠加待机层的重心微晃 swayX——
                // 两层相加而不是互相覆盖，符合"idle 负责底噪、系统数据负责状态"的分工。
                .offset(x: shake.width + CGFloat(idleState.swayX), y: bounce + shake.height)
                .compositingGroup()
                .shadow(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 1)
            }
            .frame(width: 170, height: 150)
            .animation(.easeInOut(duration: 0.4), value: sitAmount)
            .animation(.easeInOut(duration: 0.3), value: bellyScale)
            .onChange(of: isIdle) { nowIdle in
                idleStartTime = nowIdle ? Date() : nil
                triggerSquash() // 坐下/重新起跑这类姿态切换也算一次"落地"
            }
            .onChange(of: stepIndex) { _ in
                if !isIdle { triggerSquash() }
            }
            .onAppear {
                idleStartTime = isIdle ? Date() : nil
            }
        }
    }

    /// 落地/坐下瞬间的挤压回弹：立刻压扁到 0.85，再用 SwiftUI 的
    /// `.spring(response:dampingFraction:)` 带一点过冲地弹回 1，
    /// 比 `.linear` 更有"有弹性的软组织"的手感。
    private func triggerSquash() {
        squashAmount = 0.85
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            squashAmount = 1.0
        }
    }

    // MARK: - 背景光晕（可见度增强第 2 层）

    private var backdropHalo: some View {
        Ellipse()
            .fill(Color.black.opacity(0.10))
            .frame(width: 130, height: 96)
            .blur(radius: 14)
            .position(x: 90, y: 78)
    }

    // MARK: - 地面阴影

    private func shadowView(bounce: CGFloat) -> some View {
        let liftRatio = Double(min(abs(bounce) / 12, 1))
        return Ellipse()
            .fill(Color.black.opacity(0.15 - 0.05 * liftRatio))
            .frame(width: 92 * (1 - 0.15 * CGFloat(liftRatio)), height: 14)
            .position(x: 85, y: 138)
    }

    // MARK: - 身体（呼吸 + 落地挤压，体积守恒的 X/Y 联动缩放）

    /// Y 方向缩放 = 呼吸 × 落地挤压；X 方向按 `1/sqrt(scaleY)` 反向联动，
    /// 保持"看起来体积不变"（Y 变大一点，X 就同步收窄一点）。
    private func bodyView(breathing: CGFloat, squashAmount: CGFloat) -> some View {
        let scaleY = breathing * squashAmount
        let scaleX = 1 / sqrt(scaleY)

        return FluffyBlobShape(bumpCount: 16, bumpDepth: 0.045)
            .fill(bodyColor)
            .overlay(
                FluffyBlobShape(bumpCount: 16, bumpDepth: 0.045)
                    .stroke(outlineColor, lineWidth: outlineWidth)
            )
            .frame(width: 104, height: 60)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
            .position(x: 80, y: 94)
    }

    /// 脖子过渡色块：不描边、纯色填充，专门用来盖住头和身体两个蓬松轮廓
    /// 之间的接缝，让整只狗看起来是一体的，而不是"头贴在身体上"。
    private func neckConnector(breathing: CGFloat) -> some View {
        Ellipse()
            .fill(bodyColor)
            .frame(width: 38, height: 32)
            .scaleEffect(breathing, anchor: .bottom)
            .position(x: 110, y: 66)
    }

    // MARK: - 肚子（随内存缩放，乘以呼吸缩放而不是覆盖）

    private func bellyView(breathing: CGFloat) -> some View {
        Ellipse()
            .fill(Color.white.opacity(0.95))
            .overlay(Ellipse().stroke(outlineColor.opacity(0.55), lineWidth: 1))
            .frame(width: 40, height: 28)
            .scaleEffect(bellyScale * breathing, anchor: .center)
            .position(x: 78, y: 108)
    }

    // MARK: - 腿（四条独立部件，摆动频率/幅度由网速驱动）

    /// 四条腿各自的身份：前/后 × 近侧/远侧。
    /// 近侧腿画在身体前面、完全可见；远侧腿画在身体后面、被部分遮挡，
    /// 并且整体缩小一圈、颜色略微压暗——这是让"四条腿一起跑"看起来
    /// 有前后纵深、而不是四条腿贴脸重叠在一起的关键。
    private enum LegRole {
        case frontNear, frontFar, backNear, backFar

        var isFar: Bool {
            switch self {
            case .frontFar, .backFar: return true
            case .frontNear, .backNear: return false
            }
        }
    }

    /// 单条腿：一个圆头胶囊 + 白色小爪子，围绕髋部/肩部锚点旋转摆动。
    /// 对角线上的两条腿同相摆动（前近+后远一组，前远+后近另一组），
    /// 这是真实四足动物小跑的步态，避免"顺拐"。每条腿在"往前摆"的
    /// 半程会抬起一点（模拟迈步离地），"往后摆"贴地（模拟蹬地）。
    private func legsView(t: TimeInterval, role: LegRole) -> some View {
        let baseX: CGFloat
        switch role {
        case .frontNear: baseX = 108
        case .frontFar: baseX = 103
        case .backNear: baseX = 44
        case .backFar: baseX = 49
        }

        let phaseOffset: Double
        switch role {
        case .frontNear, .backFar: phaseOffset = 0
        case .frontFar, .backNear: phaseOffset = .pi
        }

        let hipY: CGFloat = 100
        let phase = t * legFrequency * 2 * .pi + phaseOffset
        let swingDegrees = isIdle ? 0 : sin(phase) * legSwingAmplitude
        let lift: CGFloat = isIdle ? 0 : CGFloat(max(0, sin(phase))) * 4

        let sizeScale: CGFloat = role.isFar ? 0.82 : 1.0
        let legLength: CGFloat = (28 - sitAmount * 12) * sizeScale
        let pawDiameter: CGFloat = 13 * sizeScale
        let legWidth: CGFloat = 12 * sizeScale
        let totalHeight = legLength + pawDiameter

        return VStack(spacing: 0) {
            Capsule()
                .fill(bodyColor)
                .overlay(Capsule().stroke(outlineColor, lineWidth: outlineWidth))
                .frame(width: legWidth, height: legLength)
            Circle()
                .fill(Color.white)
                .frame(width: pawDiameter, height: pawDiameter)
                .overlay(Circle().stroke(outlineColor.opacity(0.7), lineWidth: 1))
                .offset(y: -3 * sizeScale)
        }
        .frame(height: totalHeight, alignment: .top)
        .rotationEffect(.degrees(swingDegrees), anchor: .top)
        .position(x: baseX, y: hipY + totalHeight / 2)
        .offset(y: -lift)
        .colorMultiply(role.isFar ? Color(white: 0.88) : Color.white)
    }

    // MARK: - 尾巴（活跃度决定"想摆到哪"，spring 链条决定"实际摆到哪"）

    /// 尾巴本来想摆到的角度（相对中心的偏移量），由网络活跃度驱动。
    /// 这只是"目标"，真正渲染用的角度是这个目标喂给 `tailChain`
    /// 之后的输出（见 `body` 里的调用），带滞后和回弹。
    private func tailWagTargetAngle(t: TimeInterval) -> Double {
        let phase = t * tailFrequency * 2 * .pi
        return sin(phase) * tailAmplitude
    }

    private func tailView(tailAngle: Double) -> some View {
        FluffyBlobShape(bumpCount: 10, bumpDepth: 0.06)
            .fill(bodyColor)
            .overlay(
                FluffyBlobShape(bumpCount: 10, bumpDepth: 0.06)
                    .stroke(outlineColor, lineWidth: outlineWidth)
            )
            .frame(width: 32, height: 32)
            .rotationEffect(.degrees(-25 + tailAngle), anchor: .bottomTrailing)
            .position(x: 36, y: 76)
    }

    // MARK: - 头部（含耳朵、口鼻、眼睛、鼻子、打盹特效）

    private func headView(t: TimeInterval, isSleepy: Bool, idleState: IdleState) -> some View {
        // 闲置时头部有一个很轻的上下"呼吸式"点头；奔跑时头部随步频轻微左右摆动；
        // 待机彩蛋（quirkPulse）偶尔叠加一次"甩头"，触发瞬间到峰值再自然回落。
        let idleBob = isIdle ? CGFloat(sin(t * 2 * .pi * 0.3)) * 1.4 : 0
        let runTilt = isIdle ? 0.0 : sin(t * legFrequency * 2 * .pi) * 3
        let headShake = idleState.quirkPulse * 20
        // 打盹时眼睛始终接近全闭，同时也让眨眼曲线的极小值参与进来（取更小的那个），
        // 避免和 IdleAnimator 的随机眨眼排期"打架"。
        let eyeOpenL = isSleepy ? min(idleState.eyeOpenL, 0.1) : idleState.eyeOpenL
        let eyeOpenR = isSleepy ? min(idleState.eyeOpenR, 0.1) : idleState.eyeOpenR

        return ZStack {
            // 耳朵在头部圆形之下，先绘制；旋转角里加了 IdleAnimator 算出来的
            // spring 抽动角度，不再是本地的确定性周期函数。
            earView(rotation: -30, x: 102, y: 40, twitch: idleState.earTwitchL)
            earView(rotation: 22, x: 138, y: 42, twitch: idleState.earTwitchR)

            // 头部主体
            FluffyBlobShape(bumpCount: 12, bumpDepth: 0.055)
                .fill(bodyColor)
                .overlay(
                    FluffyBlobShape(bumpCount: 12, bumpDepth: 0.055)
                        .stroke(outlineColor, lineWidth: outlineWidth)
                )
                .frame(width: 62, height: 54)
                .position(x: 122, y: 58)

            // 口鼻部分
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(outlineColor.opacity(0.5), lineWidth: 1))
                .frame(width: 26, height: 20)
                .position(x: 140, y: 70)

            // 鼻子
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 7, height: 7)
                .position(x: 150, y: 66)

            // 舌头 + 汗滴：只有跑得足够快（网络活跃度 > 0.55）才会吐舌头喘气冒汗
            if isPanting {
                Capsule()
                    .fill(Color.pink.opacity(0.75))
                    .frame(width: 8, height: CGFloat(14 + sin(t * 8) * 2))
                    .position(x: 148, y: 80)

                sweatView(t: t)
            }

            // 眼睛：用纵向缩放模拟眨眼 / 打盹时的半闭眼，左右眼各自读取
            // IdleAnimator 给出的 eyeOpenL / eyeOpenR（目前两眼同步眨，
            // 但接口上是独立的，方便以后做单眼眨眼之类的花样）。
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 5, height: 5)
                .scaleEffect(x: 1, y: CGFloat(eyeOpenL), anchor: .center)
                .position(x: 112, y: 52)
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 5, height: 5)
                .scaleEffect(x: 1, y: CGFloat(eyeOpenR), anchor: .center)
                .position(x: 130, y: 48)

            // 打盹时头顶漂浮的 "z" 字
            if isSleepy {
                sleepyZs(t: t)
            }
        }
        .rotationEffect(.degrees(runTilt + headShake), anchor: .bottom)
        .offset(y: idleBob)
    }

    private func earView(rotation: Double, x: CGFloat, y: CGFloat, twitch: Double) -> some View {
        FluffyBlobShape(bumpCount: 6, bumpDepth: 0.08)
            .fill(bodyColor.opacity(0.95))
            .overlay(
                FluffyBlobShape(bumpCount: 6, bumpDepth: 0.08)
                    .stroke(outlineColor, lineWidth: outlineWidth)
            )
            .frame(width: 24, height: 32)
            .rotationEffect(.degrees(rotation + twitch))
            .position(x: x, y: y)
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
                    .position(x: 150 + CGFloat(index) * 5, y: 24 + riseY)
                    .opacity(fadeOpacity)
            }
        }
    }

    /// 头部附近周期性冒出的汗滴：每滴汗从头侧冒出、往下滑落一小段再淡出，
    /// 两滴汗错开时间循环播放，配合吐舌头一起表示"跑得很拼命"。
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
                    .position(x: 104 + CGFloat(index) * 12, y: 42 + dropY)
                    .opacity(dropOpacity)
            }
        }
    }

    // MARK: - 纯时间驱动的系统数据表现（跑动相关，独立于待机层）

    /// 奔跑弹跳：只在移动状态下出现，跟随摆腿频率的两倍起伏（一步一次小跳），
    /// 网速越快跳得越明显。
    private func runningBounce(t: TimeInterval) -> CGFloat {
        guard !isIdle, legFrequency > 0 else { return 0 }
        let phase = t * legFrequency * 2 * 2 * .pi
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
        BichonView(metrics: PetMetrics(memoryFraction: 0.2, networkActivity: 0.0), bodyColor: .white, personality: .bichon)
        BichonView(metrics: PetMetrics(memoryFraction: 0.9, networkActivity: 0.8), bodyColor: .white, personality: .bichon)
    }
    .padding()
    .background(Color.white)
}
