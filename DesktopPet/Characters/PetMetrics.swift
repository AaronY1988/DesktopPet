//
//  PetMetrics.swift
//  DesktopPet
//
//  把 SystemMonitor 发布的原始系统数据，转换成角色动画统一使用的归一化参数。
//  所有角色实现都只依赖这个结构体，而不是直接读取 SystemMonitor，
//  这样将来调整"指标 -> 视觉映射"的算法时只需要改这一个地方。
//

import Foundation

struct PetMetrics {
    /// 内存占用率 0...1，用于驱动肚子缩放
    var memoryFraction: Double = 0

    /// 归一化后的网络活跃度 0...1（0 = 完全空闲，1 = 达到或超过参考峰值速率）
    /// 用于驱动奔跑 / 摆腿速度
    var networkActivity: Double = 0

    /// 原始下行速率 bytes/sec，保留给需要展示精确数值的角色（例如未来的提示气泡）
    var rawDownloadSpeed: Double = 0

    /// 原始上行速率 bytes/sec
    var rawUploadSpeed: Double = 0

    /// 可选的 CPU 温度（摄氏度）。
    /// 说明：macOS 上读取真实 CPU 温度需要访问 SMC（System Management Controller）的
    /// 私有接口（IOKit 私有 key，Apple Silicon 上该接口更加不稳定且未公开文档化），
    /// 使用私有 API 有 App Store 审核被拒的风险，因此本项目未实现真实采集，
    /// 始终为 nil，仅保留字段与 `colorForTemperature` 接口以便未来扩展。
    var cpuTemperature: Double? = nil

    /// 由 SystemMonitor 的原始发布值构造出动画使用的归一化指标。
    /// - Parameter referencePeakSpeed: 网速映射到 0...1 的参考峰值（bytes/sec），
    ///   达到或超过该值视为"满速奔跑"，默认 5 MB/s，可按需调整体感灵敏度。
    static func from(monitor: SystemMonitor, referencePeakSpeed: Double = 5 * 1024 * 1024) -> PetMetrics {
        let totalSpeed = monitor.downloadSpeed + monitor.uploadSpeed
        let activity = min(max(totalSpeed / referencePeakSpeed, 0), 1)
        return PetMetrics(
            memoryFraction: monitor.memoryUsage,
            networkActivity: activity,
            rawDownloadSpeed: monitor.downloadSpeed,
            rawUploadSpeed: monitor.uploadSpeed,
            cpuTemperature: nil
        )
    }
}
