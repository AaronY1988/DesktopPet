# -*- coding: utf-8 -*-
"""Emit SpottedDogParts.swift from the decomposed parts."""
import importlib.util, math
spec = importlib.util.spec_from_file_location('dp', 'dogparts.py')
dp = importlib.util.module_from_spec(spec); spec.loader.exec_module(dp)
spec2 = importlib.util.spec_from_file_location('pz', 'pose.py')
pz = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(pz)

def f(v):
    s = '%.2f' % v
    s = s.rstrip('0').rstrip('.')
    return s if s not in ('-0','') else '0'

def path_swift(ops, indent='        '):
    lines = []
    for op in ops:
        if op[0]=='M':
            lines.append('p.move(to: P(%s, %s))' % (f(op[1][0]), f(op[1][1])))
        elif op[0]=='L':
            lines.append('p.addLine(to: P(%s, %s))' % (f(op[1][0]), f(op[1][1])))
        elif op[0]=='C':
            lines.append('p.addCurve(to: P(%s, %s), control1: P(%s, %s), control2: P(%s, %s))' % (
                f(op[3][0]), f(op[3][1]), f(op[1][0]), f(op[1][1]), f(op[2][0]), f(op[2][1])))
        elif op[0]=='Q':
            lines.append('p.addQuadCurve(to: P(%s, %s), control: P(%s, %s))' % (
                f(op[2][0]), f(op[2][1]), f(op[1][0]), f(op[1][1])))
        elif op[0]=='Z':
            lines.append('p.closeSubpath()')
    return ('\n'+indent).join(lines)

# color mapping: hex -> swift
def col(hexs):
    r = int(hexs[1:3],16)/255; g = int(hexs[3:5],16)/255; b = int(hexs[5:7],16)/255
    return 'Color(red: %.3f, green: %.3f, blue: %.3f)' % (r,g,b)

CASE = {n: n[0].lower()+n[1:] if not n[0].islower() else n for n in dp.ZORDER}

parts_code = []
fills = []
for name in dp.ZORDER:
    ops, fill, opac = dp.PARTMAP[name]
    parts_code.append('    static let %s: Path = {\n        var p = Path()\n        %s\n        return p\n    }()' % (CASE[name], path_swift(ops)))

# closed-eye line (hand-authored): gentle arc where the eye is, shown while blinking/sleeping
eyelid = [('M',(51.5,39.5)), ('Q',(57.6,44.5),(63.7,39.0))]
parts_code.append('    /// 闭眼弧线（眨眼到底/睡觉时描边显示，非原 SVG 部件）\n    static let eyelid: Path = {\n        var p = Path()\n        %s\n        return p\n    }()' % path_swift(eyelid))

pivots = {
  'neck': dp.J['neck'], 'earFloppy': dp.J['earFloppy'], 'earSmall': dp.J['earSmall'], 'tail': dp.J['tail'],
  'hipFrontFar': dp.J['hipFF'], 'hipFrontNear': dp.J['hipNF'], 'hipRearNear': dp.J['hipNR'], 'hipRearFar': dp.J['hipFR'],
  'kneeFrontFar': pz.PIVOTS['kFF'], 'kneeFrontNear': pz.PIVOTS['kNF'], 'kneeRearNear': pz.PIVOTS['kNR'], 'kneeRearFar': pz.PIVOTS['kFR'],
  'eyeCenter': dp.J['eye'],
}
piv_code = '\n'.join('    static let %s = CGPoint(x: %s, y: %s)' % (k, f(v[0]), f(v[1])) for k,v in pivots.items())

swift = '''//
//  SpottedDogParts.swift
//  DesktopPet
//
//  小花狗的分层矢量部件——由 tools/dog-rig/dogparts.py 从用户提供的原始
//  SVG 插画自动拆解生成（原图里头/身体/四条腿是一条画死的大路径，
//  脚本用 de Casteljau 在髋部/膝盖处精确切开贝塞尔边，并给每个关节
//  加了"以关节为圆心的半圆帽"，保证任意旋转角度下部件之间都不露缝）。
//
//  坐标全部保留在原 SVG 的 180.03 x 203.21 viewBox 空间里；每个部件的
//  Shape 都按整张画布等比缩放绘制，因此旋转锚点直接用
//  SpottedDogRig.anchor(_:) 把 viewBox 坐标换算成 UnitPoint 即可。
//
//  ⚠️ 数值请勿手改——想调整拆分方式请改生成脚本后重新生成。
//

import SwiftUI

// MARK: - 骨骼（关节支点，viewBox 坐标）

enum SpottedDogRig {
    static let viewW: CGFloat = 180.03
    static let viewH: CGFloat = 203.21

%s

    /// viewBox 坐标 -> rotationEffect 用的 UnitPoint 锚点
    static func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: p.x / viewW, y: p.y / viewH)
    }
}

// MARK: - 配色（原 SVG 的 class 色板）

enum SpottedDogColors {
    static let cream      = %s // #e9cfb9 主体
    static let creamDark  = %s // #c1ad9b 远侧后腿
    static let orange     = %s // #b65d2d 斑块/耳朵/尾巴
    static let darkBrown  = %s // #722c1b 鼻子/尾巴纹理
    static let deepBrown  = %s // #602724 瞳孔/嘴线
    static let shade      = %s // #8b3a22 阴影叠层
    static let blushPink  = %s // #f1ac97 腮红
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - 部件路径（viewBox 空间，静态构建一次）

enum SpottedDogPaths {
%s
}

// MARK: - 通用部件 Shape：把 viewBox 路径等比缩放到画布

struct SpottedDogPartShape: Shape {
    let base: Path
    func path(in rect: CGRect) -> Path {
        let s = rect.width / SpottedDogRig.viewW
        return base.applying(CGAffineTransform(scaleX: s, y: s))
    }
}
''' % (piv_code,
       col('#e9cfb9'), col('#c1ad9b'), col('#b65d2d'), col('#722c1b'),
       col('#602724'), col('#8b3a22'), col('#f1ac97'),
       '\n\n'.join(parts_code))

out = '/sessions/vibrant-dreamy-mccarthy/mnt/Desktop Pet/DesktopPet/DesktopPet/Views/SpottedDogParts.swift'
open(out, 'w').write(swift)
print('wrote', out, len(swift), 'bytes')
print('knees:', {k: (round(v[0],2), round(v[1],2)) for k,v in pz.PIVOTS.items()})
