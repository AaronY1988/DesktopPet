//
//  PetPersonality.swift
//  DesktopPet
//
//  把"待机手感"相关的可调参数收拢成一个配置结构体。IdleAnimator 和
//  各角色的尾巴 / 耳朵 spring 都读这里的值——两个角色共用同一份
//  IdleAnimator / SpringValue 实现，靠这个结构体的不同取值制造出
//  不同的"性格"（小花狗沉稳、狸花猫轻快灵活）。
//
//  小花狗现在是整张矢量插画（SpottedDogView），没有耳朵/尾巴这些可以
//  单独动的部件，personality.earStiffness / tailStiffness 等字段对它
//  来说是"算了但用不上"，breathAmplitude / quirkProbabilityPerCheck
//  这些作用在"整只宠物"级别的字段仍然生效。
//
//  下面 `earTwitchImpulse` / `quirkCheckInterval` 里给的具体数字，
//  不是拍脑袋定的：用 Python 跑了一遍 SpringValue 的积分过程反推校准，
//  确保"耳朵抽动"的峰值大概落在 12°~16°（够显眼但不夸张），
//  "彩蛋动作强度" quirkPulse 的峰值落在 ~1.0（方便调用方直接当
//  0...1 的强度系数用）。想要更猛/更细腻的手感，直接调这些数字即可，
//  数值和视觉幅度大致成线性关系。
//

import Foundation

struct PetPersonality {
    // MARK: 呼吸 / 重心微晃

    /// 呼吸缩放的振幅（小花狗更明显、狸花猫更沉稳内敛）
    var breathAmplitude: Double
    /// 重心微晃的振幅，两个角色目前共用同一个量级
    var swayAmplitude: Double = 2.0

    // MARK: 眨眼（随机排期，不是正弦）

    /// 两次眨眼之间的随机间隔范围
    var blinkIntervalRange: ClosedRange<Double>

    // MARK: 耳朵 spring（低概率随机抽动 + 回弹）

    var earStiffness: Double
    var earDamping: Double
    /// 每次"检查是否要抽动耳朵"时触发的概率
    var earTwitchProbabilityPerCheck: Double
    /// 两次检查之间的随机间隔范围
    var earTwitchCheckInterval: ClosedRange<Double>
    /// 触发时给 spring 施加的瞬时速度冲量，数值越大甩得越猛
    var earTwitchImpulse: Double

    // MARK: 尾巴 spring 链（惯性跟随）

    /// 串联的弹簧节数：狸花猫尾巴长、更灵活用 3 节；小花狗预设仍保留 2 节
    /// 的数值，但小花狗目前没有可动的尾巴部件，这个字段暂时用不上
    var tailSegmentCount: Int
    var tailStiffness: Double
    var tailDamping: Double

    // MARK: 待机彩蛋动作（具体解读交给各角色：小花狗是整体小幅摇晃，猫可以是尾尖抽动/舔爪）

    var quirkProbabilityPerCheck: Double
    var quirkCheckInterval: ClosedRange<Double>

    // MARK: 预设

    /// 协议默认实现用的中性参数，新角色不特别定制手感时的兜底值。
    static let neutral = PetPersonality(
        breathAmplitude: 0.028,
        blinkIntervalRange: 2.0...5.0,
        earStiffness: 130,
        earDamping: 15,
        earTwitchProbabilityPerCheck: 0.14,
        earTwitchCheckInterval: 2.5...4.5,
        earTwitchImpulse: 600,
        tailSegmentCount: 2,
        tailStiffness: 110,
        tailDamping: 14,
        quirkProbabilityPerCheck: 0.15,
        quirkCheckInterval: 4.0...6.5
    )

    /// 小花狗已拆成分层矢量部件（SpottedDogParts.swift），ear*/tail*
    /// 字段全部真正生效：耳朵随机抽动走 earSpring，尾巴用 2 节、刚度 140
    /// 的链条（本征频率约 1.9Hz，比猫的 3 节软链更"硬朗"，甩动干脆），
    /// quirkPulse 解读为"甩头"。
    static let spottedDog = PetPersonality(
        breathAmplitude: 0.03,
        blinkIntervalRange: 2.0...6.0,
        earStiffness: 120,
        earDamping: 14,
        earTwitchProbabilityPerCheck: 0.12,
        earTwitchCheckInterval: 2.5...4.5,
        earTwitchImpulse: 550,
        tailSegmentCount: 2,
        tailStiffness: 140,
        tailDamping: 17,
        quirkProbabilityPerCheck: 0.15,
        quirkCheckInterval: 4.0...7.0 // 偶尔整体摇晃一下
    )

    static let tabbyCat = PetPersonality(
        breathAmplitude: 0.025, // 猫呼吸更沉稳内敛
        blinkIntervalRange: 1.5...4.0, // 眨眼比较频繁
        earStiffness: 150, // 猫耳更挺，回位更快
        earDamping: 17,
        earTwitchProbabilityPerCheck: 0.16,
        earTwitchCheckInterval: 2.0...3.8,
        earTwitchImpulse: 880, // 校准后峰值约 16°
        tailSegmentCount: 3, // 长尾巴，多节更灵活
        tailStiffness: 70, // 刚度更低，更软更"甩得开"
        tailDamping: 9,
        quirkProbabilityPerCheck: 0.2,
        quirkCheckInterval: 3.0...5.5 // 偶尔舔爪、尾尖抽动
    )
}
