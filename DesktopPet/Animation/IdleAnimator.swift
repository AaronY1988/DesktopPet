//
//  IdleAnimator.swift
//  DesktopPet
//
//  "永不静止"的待机微动画层：呼吸、重心微晃、随机眨眼、随机耳朵抽动、
//  随机待机彩蛋动作。两个角色共用同一份实现，只是喂给它的 PetPersonality
//  不同，手感就会不一样。
//
//  这一层和 SystemMonitor 的系统数据驱动层（肚子=内存那套）完全独立：
//  这里只负责"活着"的底噪，具体的"状态"表达（肚子大小、奔跑速度）由
//  各角色的 View 在拿到 IdleState 之后自己再叠加系统数据——用乘法叠加，
//  不覆盖（比如最终肚子缩放 = 内存决定的 bellyScale × 这里的
//  breathScale，两个 View 里都是这么写的）。
//
//  实现上是一个持有内部状态的 class 而不是纯函数，因为"下一次眨眼/
//  抽耳朵的时间点"本身就需要跨帧记住，没法只用绝对时间 t 的闭式公式
//  表达。用 @State 持有这个 class 的实例即可让它在 View 反复重建 body
//  的过程中保持同一份状态（和 SpottedDogView 里 `idleStartTime` 的做法一致）。
//

import Foundation

struct IdleState {
    /// 呼吸缩放系数（1 附近浮动），作用于躯干和肚子的 Y 轴缩放
    var breathScale: Double = 1
    /// 重心微晃的瞬时位移，作用于整体 X 偏移
    var swayX: Double = 0
    /// 重心微晃的瞬时速度，给尾巴/耳朵这类 spring 部件当驱动目标用
    var swayVelocity: Double = 0
    var eyeOpenL: Double = 1
    var eyeOpenR: Double = 1
    /// 耳朵抽动角度（度），已经是 spring 模拟的结果，直接加到耳朵旋转角上即可
    var earTwitchL: Double = 0
    var earTwitchR: Double = 0
    /// 待机彩蛋动作的强度，触发瞬间跳到峰值（约 1.0）再自然回落，
    /// 具体解读交给调用方：小花狗拿它做"整体小幅度摇晃"的角度系数，
    /// 猫可以拿它做"尾尖抽动"或"舔一下爪子"的动作强度。
    var quirkPulse: Double = 0
}

final class IdleAnimator {
    private let personality: PetPersonality
    private var lastUpdateTime: Double?

    private var nextBlinkTime: Double?
    private var blinkStartTime: Double?

    private var nextEarCheckTime: Double?
    private var earSpringL: SpringValue
    private var earSpringR: SpringValue

    private var nextQuirkCheckTime: Double?
    private var quirkSpring: SpringValue

    /// 眨眼动作本身的时长（秒），到点后 1→0→1
    private let blinkDuration: Double = 0.12

    init(personality: PetPersonality) {
        self.personality = personality
        earSpringL = SpringValue(value: 0, velocity: 0, target: 0, stiffness: personality.earStiffness, damping: personality.earDamping)
        earSpringR = SpringValue(value: 0, velocity: 0, target: 0, stiffness: personality.earStiffness, damping: personality.earDamping)
        // 彩蛋动作的弹簧参数两个角色共用一套（只有触发概率/间隔由 personality 决定），
        // 冲量 30 是照 earTwitch 同样的方法用数值模拟校准过的，峰值约在 1.0 附近。
        quirkSpring = SpringValue(value: 0, velocity: 0, target: 0, stiffness: 90, damping: 12)
    }

    /// 每一帧（TimelineView 的每个 tick）调用一次；`t` 用
    /// `timeline.date.timeIntervalSinceReferenceDate`，和角色其它动画共用同一个时间基准。
    @discardableResult
    func update(t: Double) -> IdleState {
        let dt = min(lastUpdateTime.map { max(t - $0, 0) } ?? (1.0 / 30.0), 1.0 / 15.0)
        lastUpdateTime = t

        // --- 呼吸 + 重心微晃：周期取 3.2 / 5.1 这组互质的数，
        //     叠加起来不会形成明显的整体循环感 ---
        let breathPhase = t * 2 * .pi / 3.2
        let swayPhase = t * 2 * .pi / 5.1
        let breath = 1 + personality.breathAmplitude * sin(breathPhase)
        let sway = personality.swayAmplitude * sin(swayPhase)
        let swayAngularFrequency = 2 * Double.pi / 5.1
        let swayVelocity = personality.swayAmplitude * swayAngularFrequency * cos(swayPhase)

        // --- 眨眼：随机排期，不是正弦。到点后 120ms 内 1→0→1 ---
        if nextBlinkTime == nil {
            nextBlinkTime = t + Double.random(in: personality.blinkIntervalRange)
        }
        if blinkStartTime == nil, let next = nextBlinkTime, t >= next {
            blinkStartTime = t
        }
        var eyeOpen = 1.0
        if let start = blinkStartTime {
            let elapsed = t - start
            if elapsed >= blinkDuration {
                blinkStartTime = nil
                nextBlinkTime = t + Double.random(in: personality.blinkIntervalRange)
            } else {
                let phase = elapsed / blinkDuration // 0...1
                eyeOpen = 1 - sin(phase * .pi) // 1 -> 0 -> 1 的眨眼曲线
            }
        }

        // --- 耳朵抽动：低概率随机事件，给 spring 一个瞬时速度冲量，
        //     让它自己"嗖"地甩一下再弹回原位，不需要手写回弹曲线 ---
        if nextEarCheckTime == nil {
            nextEarCheckTime = t + Double.random(in: personality.earTwitchCheckInterval)
        }
        if let next = nextEarCheckTime, t >= next {
            nextEarCheckTime = t + Double.random(in: personality.earTwitchCheckInterval)
            if Double.random(in: 0...1) < personality.earTwitchProbabilityPerCheck {
                if Bool.random() {
                    earSpringL.velocity += personality.earTwitchImpulse
                } else {
                    earSpringR.velocity += personality.earTwitchImpulse
                }
            }
        }
        earSpringL.update(dt: dt)
        earSpringR.update(dt: dt)

        // --- 待机彩蛋动作：同样是低概率随机事件 + spring 冲量 ---
        if nextQuirkCheckTime == nil {
            nextQuirkCheckTime = t + Double.random(in: personality.quirkCheckInterval)
        }
        if let next = nextQuirkCheckTime, t >= next {
            nextQuirkCheckTime = t + Double.random(in: personality.quirkCheckInterval)
            if Double.random(in: 0...1) < personality.quirkProbabilityPerCheck {
                quirkSpring.velocity += 30
            }
        }
        quirkSpring.update(dt: dt)

        return IdleState(
            breathScale: breath,
            swayX: sway,
            swayVelocity: swayVelocity,
            eyeOpenL: eyeOpen,
            eyeOpenR: eyeOpen,
            earTwitchL: earSpringL.value,
            earTwitchR: earSpringR.value,
            quirkPulse: quirkSpring.value
        )
    }
}
