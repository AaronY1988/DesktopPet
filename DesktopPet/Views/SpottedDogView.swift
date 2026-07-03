//
//  SpottedDogView.swift
//  DesktopPet
//
//  小花狗——分层矢量部件版。用户提供的 SVG 插画原本是"头+身体+四条腿
//  画死在一条路径里"的整张图，现在已经用脚本（tools/dog-rig/）拆成了
//  可以独立驱动的部件（见 SpottedDogParts.swift）：
//
//  可独立驱动的部件与关节：
//  - 四条腿 × 两段（大腿绕髋部旋转、小腿+爪子绕膝盖嵌套旋转），
//    关节处是"以关节为圆心的半圆帽"，任意摆角都不露缝；
//  - 头部整组绕脖根旋转（含眼睛、鼻子、嘴、腮红、颈部阴影）；
//  - 大耳朵/小耳朵在头部组内再绕各自耳根旋转（待机随机抽动 + 奔跑甩动）；
//  - 尾巴绕尾根旋转，由 TailSpringChain 提供惯性滞后的甩动手感；
//  - 眼睛可眨（纵向缩放 + 闭眼弧线），瞌睡时闭眼。
//
//  三层动画分工（和狸花猫 TabbyCatView 一致）：
//  1) 待机微动画层（IdleAnimator）：呼吸、重心微晃、随机眨眼、随机耳朵
//     抽动；待机彩蛋 quirkPulse 现在解读为"甩头"（拆件之前只能整体摇晃）。
//  2) spring 次级运动层：尾巴 2 节链条滞后甩动。
//  3) 自主行为状态机 + 系统数据层：网络活跃 -> 全力奔跑（对角小跑步态，
//     网速决定步频/摆幅/弹跳）；网络空闲 -> 按时间循环切换 踱步/东张西望/
//     摇尾巴/扑跪邀玩 等行为，闲置久了睡觉。行为切换时姿态做 0.35s 插值
//     过渡，不会瞬间跳变。
//
//  奔跑步态说明：对角小跑（trot）——近侧前腿+远侧后腿同相，另一对反相；
//  膝盖在腿抬起回摆时单向弯曲（相位滞后于髋部），前腿向后弯、后腿向前弯，
//  这套角度曲线是先在生成脚本里逐帧渲染验证过再移植进来的。
//

import SwiftUI

// MARK: - 自主行为状态机

/// 网络空闲时按"已闲置时长"循环切换的行为。纯时间驱动、不依赖随机数，
/// 同一个 idleDuration 总能复现同一动作，方便调试预览。
enum DogActivity: Equatable {
    case rest       // 站着喘气发呆（呼吸/眨眼/尾巴慢摆）
    case pace       // 悠闲踱步（低频步态 + 小范围来回走）
    case lookAround // 东张西望（头左右转、耳朵竖起）
    case wagBurst   // 开心猛摇尾巴（顺带屁股一起扭）
    case playBow    // 扑跪邀玩（前腿前伸压低、屁股翘起、尾巴快摇）
    case sleep      // 睡觉（头耷拉、闭眼、飘 z）
    case run        // 网络活跃：全力奔跑
}

/// 约 38 秒一轮的待机行为循环；闲置超过 55 秒进入睡眠。
private func resolveActivity(idleDuration: Double) -> DogActivity {
    if idleDuration > 55 { return .sleep }
    let cycle = idleDuration.truncatingRemainder(dividingBy: 38)
    switch cycle {
    case 0..<7:   return .rest
    case 7..<15:  return .pace
    case 15..<20: return .lookAround
    case 20..<24: return .wagBurst
    case 24..<29: return .playBow
    default:      return .rest
    }
}

// MARK: - 姿态（一帧里所有关节的角度）

/// 所有角度单位为度，正方向 = 屏幕顺时针（与 rotationEffect 一致）。
/// 腿的命名沿用部件命名：Front/Rear = 前/后，Near/Far = 近侧/远侧。
struct DogPose {
    var hipFrontNear = 0.0, kneeFrontNear = 0.0
    var hipFrontFar  = 0.0, kneeFrontFar  = 0.0
    var hipRearNear  = 0.0, kneeRearNear  = 0.0
    var hipRearFar   = 0.0, kneeRearFar   = 0.0
    var head = 0.0          // 正 = 鼻子朝下压，负 = 抬头
    var earFloppy = 0.0, earSmall = 0.0
    var tailTarget = 0.0    // 喂给尾巴 spring 链的驱动目标
    var bodyRot = 0.0       // 整体旋转（扑跪时屁股翘起）
    var bounce = 0.0        // 整体竖直位移（负 = 跳起）
    var paceX = 0.0         // 踱步的水平位移

    /// 行为切换时的姿态插值（线性混合每个关节角度）
    static func mix(_ a: DogPose, _ b: DogPose, _ u: Double) -> DogPose {
        let v = max(0, min(1, u))
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * v }
        var p = DogPose()
        p.hipFrontNear = m(a.hipFrontNear, b.hipFrontNear); p.kneeFrontNear = m(a.kneeFrontNear, b.kneeFrontNear)
        p.hipFrontFar = m(a.hipFrontFar, b.hipFrontFar);    p.kneeFrontFar = m(a.kneeFrontFar, b.kneeFrontFar)
        p.hipRearNear = m(a.hipRearNear, b.hipRearNear);    p.kneeRearNear = m(a.kneeRearNear, b.kneeRearNear)
        p.hipRearFar = m(a.hipRearFar, b.hipRearFar);       p.kneeRearFar = m(a.kneeRearFar, b.kneeRearFar)
        p.head = m(a.head, b.head)
        p.earFloppy = m(a.earFloppy, b.earFloppy); p.earSmall = m(a.earSmall, b.earSmall)
        p.tailTarget = m(a.tailTarget, b.tailTarget)
        p.bodyRot = m(a.bodyRot, b.bodyRot); p.bounce = m(a.bounce, b.bounce); p.paceX = m(a.paceX, b.paceX)
        return p
    }
}

// MARK: - 主视图

struct SpottedDogView: View {
    let metrics: PetMetrics
    let personality: PetPersonality

    @State private var idleAnimator: IdleAnimator
    @State private var tailChain: TailSpringChain
    @State private var squashAmount: CGFloat = 1.0
    @State private var idleStartTime: Date?

    /// 行为切换的姿态过渡：记录上一个行为与切换时刻，0.35s 内做插值。
    @State private var currentActivity: DogActivity = .rest
    @State private var previousActivity: DogActivity = .rest
    @State private var blendStartT: Double?

    /// 朝向：1 = 原画朝向（头朝右），-1 = 整体水平镜像（头朝左）。
    /// 踱步来回走时自动面朝行进方向；奔跑回到默认朝向。翻转经由
    /// withAnimation 的 spring 让 scaleX 平滑过 0，看起来像"转了个身"。
    @State private var facing: CGFloat = 1

    init(metrics: PetMetrics, personality: PetPersonality) {
        self.metrics = metrics
        self.personality = personality
        _idleAnimator = State(initialValue: IdleAnimator(personality: personality))
        _tailChain = State(initialValue: TailSpringChain(
            segmentCount: personality.tailSegmentCount,
            stiffness: personality.tailStiffness,
            damping: personality.tailDamping
        ))
    }

    /// 与 SpottedDogPet.canvasSize 保持一致。画布必须容得下最坏情况的
    /// 组合动作（肚子鼓胀 + 弹跳/抖动 + 踱步位移 + 扑跪旋转 +
    /// 睡觉 z 字上飘），否则悬浮窗会把超出的部件直接裁掉。
    private let canvasSize = CGSize(width: 190, height: 205)
    /// 狗的绘制宽度；高度按原 viewBox 比例换算
    private let dogW: CGFloat = 126
    private var dogH: CGFloat { dogW * SpottedDogRig.viewH / SpottedDogRig.viewW }
    /// 爪子落地基准线（画布坐标）
    private let groundY: CGFloat = 190

    private let idleThreshold = 0.04
    private var isIdle: Bool { metrics.networkActivity < idleThreshold }

    /// 内存占用 -> 肚子鼓胀。只作用于躯干部件（横向为主、纵向少量），
    /// 头和四肢不变，读起来是"肚子吃撑了"而不是整只狗变大——比旧版的
    /// 整体均匀缩放（0.9~1.15）直观得多，那种缩放几乎看不出在表达内存。
    /// 躯干放大只会增加与头/腿的同色重叠，不会露缝（拆件无描边）。
    private var bellyScale: CGFloat {
        1 + CGFloat(metrics.memoryFraction) * 0.22
    }

    /// 奔跑步频（每秒步幅数），网速越快腿甩得越快
    private var strideFrequency: Double {
        0.9 + metrics.networkActivity * (3.2 - 0.9)
    }
    private var isPanting: Bool { !isIdle && metrics.networkActivity > 0.55 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idleDuration = idleStartTime.map { timeline.date.timeIntervalSince($0) } ?? 0
            let activity: DogActivity = isIdle ? resolveActivity(idleDuration: idleDuration) : .run
            let isSleepy = activity == .sleep

            // --- 第 1 层：待机微动画 ---
            let idleState = idleAnimator.update(t: t)
            let breathingCG = CGFloat(idleState.breathScale)

            // --- 第 3 层：行为姿态（带切换插值） ---
            let rawPose = pose(t: t, activity: activity)
            let blendedPose: DogPose = {
                if activity != currentActivity {
                    // onChange 要下一帧才会记录这次切换：本帧先按旧行为渲染，
                    // 避免插值开始前闪现一帧未混合的新姿态
                    return pose(t: t, activity: currentActivity)
                }
                guard let start = blendStartT, t - start < 0.35, previousActivity != activity else { return rawPose }
                let u = (t - start) / 0.35
                let eased = u * u * (3 - 2 * u) // smoothstep
                return DogPose.mix(pose(t: t, activity: previousActivity), rawPose, eased)
            }()

            // --- 第 2 层：尾巴 spring 链（滞后甩动）+ 彩蛋甩头 ---
            let tailValues = tailChain.update(t: t, drivingTarget: blendedPose.tailTarget)
            let tailAngle = (tailValues.last ?? blendedPose.tailTarget) + idleState.quirkPulse * 6
            let headShake = idleState.quirkPulse * 9 // 拆件之后彩蛋终于能做回"甩头"了

            let shake = runningShake(t: t, activity: activity)
            let stepIndex = activity == .run ? Int(t * strideFrequency * 2) : -1
            let eyeOpen = isSleepy ? min(idleState.eyeOpenL, 0.05) : idleState.eyeOpenL

            let scaleY = breathingCG * squashAmount
            let scaleX = 1 / sqrt(max(scaleY, 0.01))

            // 期望朝向：踱步时面朝行进方向（三角波前半程向右、后半程向左），
            // 奔跑回到原画朝向，其余行为保持当前朝向不变。
            let desiredFacing: CGFloat = {
                switch activity {
                case .pace:
                    let phase = t.truncatingRemainder(dividingBy: 7.0) / 7.0
                    return phase < 0.5 ? 1 : -1
                case .run:
                    return 1
                default:
                    return facing
                }
            }()

            ZStack {
                shadowView(bounce: CGFloat(blendedPose.bounce), lifted: activity == .playBow)

                dogBody(pose: blendedPose,
                        tailAngle: tailAngle,
                        headShake: headShake,
                        eyeOpen: eyeOpen,
                        isSleepy: isSleepy,
                        t: t)
                    .frame(width: dogW, height: dogH)
                    .scaleEffect(x: scaleX * facing, y: scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(blendedPose.bodyRot),
                                    anchor: SpottedDogRig.anchor(CGPoint(x: 75, y: 150)))
                    .offset(x: CGFloat(blendedPose.paceX) + shake.width + CGFloat(idleState.swayX),
                            y: CGFloat(blendedPose.bounce) + shake.height)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.18), radius: 2.5, x: 0, y: 1)
                    .position(x: canvasSize.width / 2, y: groundY - dogH / 2)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            // 采样间隔 1.5s，肚子变化用 0.6s 缓动跟上，不会一跳一跳
            .animation(.easeInOut(duration: 0.6), value: bellyScale)
            .onChange(of: activity) { newActivity in
                previousActivity = currentActivity
                currentActivity = newActivity
                blendStartT = Date().timeIntervalSinceReferenceDate
                triggerSquash()
            }
            .onChange(of: isIdle) { nowIdle in
                idleStartTime = nowIdle ? Date() : nil
            }
            .onChange(of: desiredFacing) { newFacing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    facing = newFacing
                }
                triggerSquash() // 转身落脚时顺带一次小挤压，动作更有分量
            }
            .onChange(of: stepIndex) { _ in
                if activity == .run { triggerSquash() }
            }
            .onAppear {
                idleStartTime = isIdle ? Date() : nil
                currentActivity = isIdle ? .rest : .run
                previousActivity = currentActivity
            }
        }
    }

    // MARK: - 姿态计算（各行为的关节角度曲线）

    /// 对角小跑步态。所有常数是先在生成脚本里逐帧渲染验证过的：
    /// - 髋部正弦摆动，近前+远后同相、远前+近后反相；
    /// - 膝盖用 max(0, sin(φ+滞后)) 做单向弯曲，前腿向后弯（正）、
    ///   后腿向前弯（负），滞后 1.9/2.1 弧度让小腿"跟不上"大腿，
    ///   甩起来才有鞭梢感；
    /// - 弹跳频率是步频的一倍（对角小跑一步一落）。
    private func gaitPose(t: Double, frequency: Double, intensity: Double) -> DogPose {
        let phi = t * frequency * 2 * .pi
        let hipAmp = 16 + 14 * intensity
        let kneeAmp = 22 + 16 * intensity

        func leg(_ offset: Double, front: Bool) -> (hip: Double, knee: Double) {
            let hip = hipAmp * sin(phi + offset)
            let bend = max(0, sin(phi + offset + (front ? 1.9 : 2.1)))
            return (hip, (front ? kneeAmp : -kneeAmp) * bend)
        }

        var p = DogPose()
        (p.hipFrontNear, p.kneeFrontNear) = leg(0, front: true)
        (p.hipRearFar, p.kneeRearFar) = leg(0, front: false)
        (p.hipFrontFar, p.kneeFrontFar) = leg(.pi, front: true)
        (p.hipRearNear, p.kneeRearNear) = leg(.pi, front: false)
        p.bounce = -abs(sin(phi)) * (3 + 4 * intensity)
        p.head = 3 * sin(phi * 2)
        p.earFloppy = (6 + 5 * intensity) * sin(phi + 0.8)
        p.earSmall = (4 + 4 * intensity) * sin(phi + 0.8)
        p.tailTarget = (12 + 8 * intensity) * sin(phi + 1.0)
        return p
    }

    private func pose(t: Double, activity: DogActivity) -> DogPose {
        switch activity {
        case .run:
            return gaitPose(t: t, frequency: strideFrequency, intensity: metrics.networkActivity)

        case .pace:
            var p = gaitPose(t: t, frequency: 1.1, intensity: 0)
            // 踱步幅度整体再收一半，慢悠悠的
            p.hipFrontNear *= 0.55; p.kneeFrontNear *= 0.55
            p.hipFrontFar *= 0.55; p.kneeFrontFar *= 0.55
            p.hipRearNear *= 0.55; p.kneeRearNear *= 0.55
            p.hipRearFar *= 0.55; p.kneeRearFar *= 0.55
            p.bounce *= 0.4
            // 画布内小范围来回走（三角波，端点自然折返）
            let period = 7.0
            let phase = t.truncatingRemainder(dividingBy: period) / period
            let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            p.paceX = (triangle - 0.5) * 22
            return p

        case .rest:
            var p = DogPose()
            p.tailTarget = 8 * sin(t * 2 * .pi / 4.5) - 2
            return p

        case .lookAround:
            var p = DogPose()
            // 头缓慢左右转（负 = 抬头方向），耳朵竖起一点，一副警觉相
            p.head = -4 + 6 * sin(t * 0.7 * 2 * .pi)
            p.earFloppy = -6
            p.earSmall = -5
            p.tailTarget = 10 * sin(t * 1.3 * 2 * .pi)
            return p

        case .wagBurst:
            var p = DogPose()
            // 1.6Hz 略低于尾巴 spring 链的本征频率（约 1.9Hz），链条末端
            // 还能保住约 2/3 的摆幅，同时带明显的相位滞后——"甩起来"的
            // 手感正来自这个滞后；频率再高链条就跟不上、反而摇不动了
            let w = sin(t * 1.6 * 2 * .pi)
            p.tailTarget = 30 * w
            p.bodyRot = 1.4 * w   // 屁股跟着一起扭
            p.head = -3
            p.earFloppy = 3 * w
            return p

        case .playBow:
            var p = DogPose()
            p.hipFrontNear = 26; p.kneeFrontNear = -10
            p.hipFrontFar = 24; p.kneeFrontFar = -8
            p.hipRearNear = -8; p.kneeRearNear = -8
            p.hipRearFar = -6; p.kneeRearFar = -6
            p.bodyRot = -7      // 前低后高
            p.head = -6         // 抬头看你
            p.bounce = 3
            p.tailTarget = 28 * sin(t * 1.6 * 2 * .pi)
            return p

        case .sleep:
            var p = DogPose()
            p.head = 12         // 头耷拉下去
            p.earFloppy = 4
            p.tailTarget = -4   // 尾巴垂着不动
            p.bounce = 2
            return p
        }
    }

    private func triggerSquash() {
        squashAmount = 0.95
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            squashAmount = 1.0
        }
    }

    /// 奔跑高频抖动：保留旧版"跑得浑身发抖"的卡通夸张，但幅度大幅调小——
    /// 现在速度感主要由真实的摆腿步态传达，抖动只是点缀。
    private func runningShake(t: TimeInterval, activity: DogActivity) -> CGSize {
        guard activity == .run else { return .zero }
        let amplitude = 0.6 + metrics.networkActivity * 1.6
        let dx = (sin(t * 41) + sin(t * 67 + 1.3) * 0.6) / 1.6 * amplitude
        let dy = (sin(t * 53 + 0.7) + sin(t * 31) * 0.6) / 1.6 * amplitude * 0.5
        return CGSize(width: CGFloat(dx), height: CGFloat(dy))
    }

    // MARK: - 分层部件组装（z 序：后 -> 前）

    private func dogBody(pose: DogPose,
                         tailAngle: Double,
                         headShake: Double,
                         eyeOpen: Double,
                         isSleepy: Bool,
                         t: TimeInterval) -> some View {
        let C = SpottedDogColors.self
        let R = SpottedDogRig.self
        let P = SpottedDogPaths.self

        return ZStack {
            // 尾巴（spring 链输出角度，绕尾根）
            Group {
                part(P.tail, C.orange)
                part(P.tailDetail, C.darkBrown)
            }
            .rotationEffect(.degrees(tailAngle), anchor: R.anchor(R.tail))

            // 远侧后腿（原 SVG 里就是深一号的颜色）
            leg(thigh: part(P.farRearThigh, C.creamDark),
                shank: part(P.farRearShank, C.creamDark),
                hip: pose.hipRearFar, knee: pose.kneeRearFar,
                hipPivot: R.hipRearFar, kneePivot: R.kneeRearFar)

            // 远侧前腿
            leg(thigh: part(P.farFrontThigh, C.cream),
                shank: part(P.farFrontShank, C.cream),
                hip: pose.hipFrontFar, knee: pose.kneeFrontFar,
                hipPivot: R.hipFrontFar, kneePivot: R.kneeFrontFar)

            // 躯干 + 斑块 + 肚皮阴影（随内存占用鼓胀，锚点在肚子底部中心）
            Group {
                part(P.body, C.cream)
                part(P.spotSaddle, C.orange)
                part(P.spotChest, C.orange)
                part(P.spotChestLow, C.orange)
                part(P.bodyShade, C.shade, opacity: 0.22)
            }
            // 锚点在脖根下方 (30, 150)：胸口贴着头的后缘几乎不动、肚子
            // 朝屁股方向鼓，避免胸口撑出头部轮廓形成锯齿（已渲染核对）
            .scaleEffect(x: bellyScale,
                         y: 1 + (bellyScale - 1) * 0.55,
                         anchor: R.anchor(CGPoint(x: 30, y: 150)))

            // 近侧后腿（大腿上的斑块和阴影跟着大腿一起转）
            leg(thigh: ZStack {
                    part(P.nearRearThigh, C.cream)
                    part(P.nearRearThighShade, C.shade, opacity: 0.22)
                    part(P.spotRearThigh, C.orange)
                },
                shank: ZStack {
                    part(P.nearRearShank, C.cream)
                    part(P.nearRearShankShade, C.shade, opacity: 0.22)
                },
                hip: pose.hipRearNear, knee: pose.kneeRearNear,
                hipPivot: R.hipRearNear, kneePivot: R.kneeRearNear)

            // 近侧前腿
            leg(thigh: part(P.nearFrontThigh, C.cream),
                shank: part(P.nearFrontShank, C.cream),
                hip: pose.hipFrontNear, knee: pose.kneeFrontNear,
                hipPivot: R.hipFrontNear, kneePivot: R.kneeFrontNear)

            // 头部整组（绕脖根旋转；耳朵在组内绕各自耳根再旋转）
            headGroup(pose: pose, headShake: headShake, eyeOpen: eyeOpen)

            // 头部附近的浮层特效
            if isPanting { sweatView(t: t) }
            if isSleepy { sleepyZs(t: t) }
        }
    }

    /// 一条腿 = 大腿绕髋部旋转 + 小腿（含爪子）先绕膝盖、再跟着髋部旋转。
    /// rotationEffect 的锚点用 viewBox 坐标换算的 UnitPoint，部件本身都是
    /// 整张画布大小的 Shape，所以不需要任何 frame/position 拼装。
    private func leg<T: View, S: View>(thigh: T, shank: S,
                                       hip: Double, knee: Double,
                                       hipPivot: CGPoint, kneePivot: CGPoint) -> some View {
        Group {
            thigh
            shank.rotationEffect(.degrees(knee), anchor: SpottedDogRig.anchor(kneePivot))
        }
        .rotationEffect(.degrees(hip), anchor: SpottedDogRig.anchor(hipPivot))
    }

    private func headGroup(pose: DogPose, headShake: Double, eyeOpen: Double) -> some View {
        let C = SpottedDogColors.self
        let R = SpottedDogRig.self
        let P = SpottedDogPaths.self

        return Group {
            Group {
                part(P.head, C.cream)
                part(P.neckShade, C.shade, opacity: 0.26)
                part(P.eyePatch, C.orange)
                part(P.nose, C.darkBrown)
                part(P.smile, C.deepBrown)
                part(P.blush, C.blushPink)
                part(P.noseShine, .white)
                part(P.earTuft, C.darkBrown)
            }

            // 小耳朵（头顶立耳）
            Group {
                part(P.earSmall, C.orange)
                part(P.earSmallDetail, C.shade)
            }
            .rotationEffect(.degrees(pose.earSmall), anchor: R.anchor(R.earSmall))

            // 大垂耳
            Group {
                part(P.earFloppy, C.orange)
                part(P.earFloppyInner, C.shade)
            }
            .rotationEffect(.degrees(pose.earFloppy), anchor: R.anchor(R.earFloppy))

            // 眼睛：纵向缩放眨眼；接近全闭时描一条闭眼弧线
            Group {
                part(P.eyeWhite, .white)
                part(P.pupil, C.deepBrown)
            }
            .scaleEffect(x: 1, y: CGFloat(max(eyeOpen, 0.001)), anchor: R.anchor(R.eyeCenter))

            if eyeOpen < 0.2 {
                SpottedDogPartShape(base: P.eyelid)
                    .stroke(C.deepBrown, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(pose.head + headShake), anchor: R.anchor(R.neck))
    }

    private func part(_ path: Path, _ fill: Color, opacity: Double = 1) -> some View {
        SpottedDogPartShape(base: path)
            .fill(fill.opacity(opacity))
    }

    /// 把 viewBox 坐标换算成狗绘制区域内的点（给汗滴 / z 字这类浮层用）
    private func local(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let s = dogW / SpottedDogRig.viewW
        return CGPoint(x: x * s, y: y * s)
    }

    // MARK: - 地面阴影

    private func shadowView(bounce: CGFloat, lifted: Bool) -> some View {
        let liftRatio = Double(min(abs(min(bounce, 0)) / 12, 1))
        return Ellipse()
            .fill(Color.black.opacity(0.15 - 0.05 * liftRatio))
            // 阴影宽度跟狗身宽走（不要跟画布宽走：画布为了给动作留余量
            // 比狗大不少，按画布算阴影会显得过大）
            .frame(width: dogW * (lifted ? 0.75 : 0.66) * (1 - 0.15 * CGFloat(liftRatio)),
                   height: 12)
            .position(x: canvasSize.width * 0.5, y: groundY + 5)
    }

    // MARK: - 头部附近的浮层特效（汗滴 / 打盹 z 字）

    /// 汗滴从额头冒出来、顺着脸往下淌。头顶轮廓在 x≈76/89 处约为
    /// y≈23/26，基准点取 (76, 24) 正好贴在轮廓上（已用 pose.py 渲染
    /// 核对）。旧版挂在 (150, 28)——那是鼻尖（x≈138）前方的半空中，
    /// 看起来汗不是从头上流下来的。
    private func sweatView(t: TimeInterval) -> some View {
        let base = local(76, 24)
        return ZStack {
            ForEach(0..<2, id: \.self) { index in
                let period = 0.9
                let phase = (t + Double(index) * 0.45).truncatingRemainder(dividingBy: period) / period
                let dropY = CGFloat(phase) * 15
                let dropOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.75 ? (1 - phase) / 0.25 : 1.0)
                let dropScale = 0.7 + 0.3 * CGFloat(min(phase * 3, 1))

                SweatDropShape()
                    .fill(Color(red: 0.55, green: 0.78, blue: 0.95))
                    .overlay(SweatDropShape().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 7, height: 10)
                    .scaleEffect(dropScale)
                    .position(x: base.x + CGFloat(index) * 9, y: base.y + dropY)
                    .opacity(dropOpacity)
            }
        }
    }

    /// 打盹的 z 字从头顶（viewBox ≈ (34, 4)）往上飘
    private func sleepyZs(t: TimeInterval) -> some View {
        let base = local(34, 4)
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let period = 2.4
                let phase = (t + Double(index) * 0.8).truncatingRemainder(dividingBy: period) / period
                let riseY = -CGFloat(phase) * 20
                let fadeOpacity = phase < 0.15 ? phase / 0.15 : (phase > 0.8 ? (1 - phase) / 0.2 : 1.0)

                Text("z")
                    .font(.system(size: 9 + CGFloat(index) * 3, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.7))
                    .position(x: base.x + CGFloat(index) * 6, y: base.y + riseY)
                    .opacity(fadeOpacity)
            }
        }
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
