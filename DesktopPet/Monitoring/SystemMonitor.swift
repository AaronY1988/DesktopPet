//
//  SystemMonitor.swift
//  DesktopPet
//
//  统一采集系统指标（内存占用率 / 网络上下行速率），并以 @Published 属性
//  广播给所有订阅者（角色视图据此驱动动画）。
//
//  权限说明：
//  - `host_statistics64` 读取的是系统级聚合统计信息（不是某个进程的私有信息），
//    在沙盒（App Sandbox）和非沙盒环境下都可以直接调用，不需要额外 entitlement。
//  - `getifaddrs` 读取的是本机网络接口的累计收发字节数（网卡计数器），
//    同样不需要网络访问权限（App Sandbox 的 "Outgoing/Incoming Connections"
//    entitlement 是给真正建立 socket 连接用的，这里只是读取本地接口信息，
//    未开启网络 entitlement 也可以正常工作）。
//

import Foundation
import Darwin

/// 系统监控单例：每隔 `refreshInterval` 秒采集一次内存与网速，
/// 并通过 Combine 的 `@Published` 属性对外发布。
final class SystemMonitor: ObservableObject {

    static let shared = SystemMonitor()

    /// 内存占用率，范围 0.0 ~ 1.0（用于驱动宠物的整体/肚子缩放）
    @Published private(set) var memoryUsage: Double = 0

    /// 下行速率，单位 bytes/sec
    @Published private(set) var downloadSpeed: Double = 0

    /// 上行速率，单位 bytes/sec
    @Published private(set) var uploadSpeed: Double = 0

    /// 采集刷新间隔（秒），需求为 1~2 秒
    let refreshInterval: TimeInterval = 1.5

    private var timer: Timer?

    // 上一次采样的网络累计字节数与时间戳，用于计算差值速率
    private var lastNetworkSample: (received: UInt64, sent: UInt64, time: Date)?

    private init() {}

    /// 启动周期性采集。应用启动时调用一次即可。
    func start() {
        guard timer == nil else { return }
        // 立即采一次，避免刚启动时角色处于"假闲置"状态
        sample()
        let t = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.sample()
        }
        // 允许在菜单交互 / 窗口拖动等 RunLoop 模式下依然触发
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let memory = Self.readMemoryUsageFraction()
        let (down, up) = readNetworkSpeed()

        // 均在主线程更新（SystemMonitor 本身只在主线程被 Timer 调用，这里显式回到主线程更安全）
        DispatchQueue.main.async {
            self.memoryUsage = memory
            self.downloadSpeed = down
            self.uploadSpeed = up
        }
    }

    // MARK: - 内存占用采集

    /// 使用 `host_statistics64` (VM_STATISTICS64) 读取系统虚拟内存统计信息，
    /// 计算 "已使用内存 / 物理内存总量" 的占比。
    ///
    /// 已使用内存 = active + wired + compressed 页面
    /// （inactive / purgeable 页面属于可被系统随时回收的缓存，不计入"占用"，
    /// 这与活动监视器"内存压力"标签页的口径基本一致）
    static func readMemoryUsageFraction() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { statsPtr -> kern_return_t in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize

        let used = active + wired + compressed
        let total = used + free + inactive

        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    // MARK: - 网速采集

    /// 使用 `getifaddrs` 遍历所有网络接口，累加各接口的收发字节数，
    /// 与上一次采样的差值除以时间间隔即为速率（bytes/sec）。
    /// 排除回环接口 (lo0) 与未启用的接口，避免统计到本机自环流量。
    private func readNetworkSpeed() -> (download: Double, upload: Double) {
        let (received, sent) = Self.readCumulativeNetworkBytes()
        let now = Date()

        defer { lastNetworkSample = (received, sent, now) }

        guard let last = lastNetworkSample else {
            // 第一次采样没有基准，速率记为 0
            return (0, 0)
        }

        let elapsed = now.timeIntervalSince(last.time)
        guard elapsed > 0 else { return (0, 0) }

        // 处理接口计数器溢出/重置（比如网络接口重启导致计数器归零）的极端情况
        let deltaReceived = received >= last.received ? received - last.received : 0
        let deltaSent = sent >= last.sent ? sent - last.sent : 0

        return (Double(deltaReceived) / elapsed, Double(deltaSent) / elapsed)
    }

    /// 读取所有活跃、非回环网络接口的累计收发字节数总和。
    private static func readCumulativeNetworkBytes() -> (received: UInt64, sent: UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalReceived: UInt64 = 0
        var totalSent: UInt64 = 0

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }

            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)

            // 只统计 AF_LINK（链路层）地址族条目，它的 ifa_data 才是 if_data 结构体，
            // 包含 ibytes/obytes 累计字节数；AF_INET/AF_INET6 条目的 ifa_data 无效。
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            // 跳过未启用 (IFF_UP) 或回环 (IFF_LOOPBACK) 接口
            guard (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0 else { continue }

            guard let data = interface.ifa_data else { continue }
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee

            totalReceived += UInt64(networkData.ifi_ibytes)
            totalSent += UInt64(networkData.ifi_obytes)
        }

        return (totalReceived, totalSent)
    }
}
