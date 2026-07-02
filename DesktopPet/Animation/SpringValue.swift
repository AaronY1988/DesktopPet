//
//  SpringValue.swift
//  DesktopPet
//
//  一维弹簧-阻尼模拟器：给耳朵、尾巴这类"被主运动带着走"的次级部件提供
//  惯性跟随（滞后 + 回弹）效果。这是纯数值模拟，每帧调用 `update(dt:)`
//  推进一步，和 SwiftUI 的 `.spring()` 动画修饰符是两回事：
//  - `.spring()` 用来给"离散状态切换"（比如落地瞬间的一次性挤压回弹）
//    做插值，交给 SwiftUI 动画系统去跑；
//  - `SpringValue` 用来给"需要持续追踪一个不断变化的目标"的物理量
//    （比如尾巴要一直根据身体摆动的角度做出滞后跟随）做逐帧积分。
//
//  用法：每帧把 `target` 设成"这个部件理论上应该在的位置/角度"，
//  调用一次 `update(dt:)`，`value` 就会像挂在弹簧上一样滞后地追上去，
//  并带一点回弹和过冲，而不是瞬间贴到 target。
//

import Foundation

struct SpringValue {
    /// 当前位移/角度（渲染时读取这个）
    var value: Double
    /// 当前速度
    var velocity: Double = 0
    /// 目标位移/角度，由外部（身体主运动）每帧写入
    var target: Double = 0
    /// 刚度：越大弹簧越"硬"，追目标追得越快
    let stiffness: Double
    /// 阻尼：越大震荡衰减得越快；阻尼相对刚度偏小时会有回弹过冲（这正是我们想要的"活的"手感）
    let damping: Double

    /// 半隐式欧拉积分一步：
    /// `force = (target - value) * stiffness`（弹簧把 value 往 target 拉）
    /// `damp = velocity * damping`（阻尼消耗速度）
    /// 用一个瞬时速度冲量（直接给 `velocity` 加一个值）就能模拟"猛地抽动一下再弹回"的效果，
    /// 不需要额外的触发状态机——冲量过后 target 保持不变（通常是 0），spring 自然会把它拉回去。
    mutating func update(dt: Double) {
        let force = (target - value) * stiffness
        let damp = velocity * damping
        velocity += (force - damp) * dt
        value += velocity * dt
    }
}
