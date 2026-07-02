//
//  TailSpringChain.swift
//  DesktopPet
//
//  尾巴的多节串联弹簧：每一节的目标是"上一节当前的值"，这样一个扰动会
//  像鞭子一样沿着链条依次传递、依次衰减/放大，比单节 spring 的滞后曲线
//  更高阶、更"软"——用 Python 数值模拟验证过：同样给一个正弦驱动信号，
//  3 节、低刚度的链条（狸花猫）末端会出现比驱动信号本身更大的摆幅，
//  正是"甩起来更灵活"的手感来源。
//
//  渲染范围说明：这里的链式模拟是完整的 N 节真实积分，但两个角色的
//  尾巴目前仍然是一整根 Capsule 矢量图形（不是画成可见的多关节），
//  为了避免引入"多关节需要逐节计算世界坐标变换"这种在没有实机预览的
//  情况下风险偏高的绘制逻辑。做法是：取链条"最后一节"（滞后/甩动最
//  明显的一节）的值来驱动这根 Capsule 的旋转角，视觉上仍然能读出
//  "尾巴跟不上身体、慢半拍甩过去"的惯性感。如果以后想要真的做成
//  可见的分节尾巴，可以在角色的 `tailView` 里把 `segments` 逐节用起来
//  （每节一个 Capsule，用 offset + rotationEffect 依次挂在上一节末端）。
//

import Foundation

final class TailSpringChain {
    private(set) var segments: [SpringValue]
    private var lastUpdateTime: Double?

    init(segmentCount: Int, stiffness: Double, damping: Double) {
        segments = (0..<max(segmentCount, 1)).map { _ in
            SpringValue(value: 0, velocity: 0, target: 0, stiffness: stiffness, damping: damping)
        }
    }

    /// 每帧调用：`drivingTarget` 是"身体主运动"给第一节的驱动目标
    /// （比如当前活跃状态下尾巴本来应该摆到的角度、或者闲置时的重心
    /// 摆动分量）。返回每一节当前的值；`values.last` 是滞后最明显的尾尖，
    /// 通常拿它来驱动尾巴的实际渲染角度。
    @discardableResult
    func update(t: Double, drivingTarget: Double) -> [Double] {
        let dt = min(lastUpdateTime.map { max(t - $0, 0) } ?? (1.0 / 30.0), 1.0 / 15.0)
        lastUpdateTime = t

        for i in segments.indices {
            segments[i].target = i == 0 ? drivingTarget : segments[i - 1].value
            segments[i].update(dt: dt)
        }
        return segments.map(\.value)
    }

    /// 便捷读取尾尖（最后一节）的当前值，不推进模拟。
    var tipValue: Double { segments.last?.value ?? 0 }
}
