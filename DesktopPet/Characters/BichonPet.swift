//
//  BichonPet.swift
//  DesktopPet
//
//  比熊角色实现——这一版换成了 Rive 驱动（素材见 Resources/dog.riv），
//  不再是纯 SwiftUI 矢量绘制。PetCharacter 协议本身没有变，别的角色
//  （比如 TabbyCatPet）完全不用关心这只角色具体是怎么画的。
//
//  dog.riv 里目前只有一段循环走路时间轴动画 `dog-walk-cycle`，以及一个
//  带三个点击触发反应（摸耳朵/尾巴/舌头）的 State Machine，没有可以
//  连续驱动的"肚子大小"之类的自定义输入，所以内存驱动肚子变大这个效果
//  这一版先不做了（详见 BichonView.swift 里的说明和 README 的已知限制）。
//

import SwiftUI

struct BichonPet: PetCharacter {
    let id = "bichon"
    let displayName = "比熊犬"
    let canvasSize = CGSize(width: 170, height: 150)
    let idleAnimation: PetIdleBehavior = .sit

    /// 比熊的性格参数目前只用于（未来）待机彩蛋的解读，Rive 素材本身
    /// 还没有接入 IdleAnimator / SpringValue 这套通用组件。
    let personality: PetPersonality = .bichon

    func draw(metrics: PetMetrics) -> AnyView {
        AnyView(BichonView(metrics: metrics, personality: personality))
    }

    /// Rive 素材的颜色是在 Rive 编辑器里画好的，代码这边目前没有接口能
    /// 覆盖它的配色（除非文件里有导出对应的 Data Binding / 颜色输入）。
    /// 保留这个方法只是为了满足协议，暂时不生效。
    func colorForTemperature(_ celsius: Double?) -> Color {
        .white
    }
}
