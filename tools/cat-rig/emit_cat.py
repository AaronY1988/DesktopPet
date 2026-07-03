# -*- coding: utf-8 -*-
"""Emit CatPoses.swift from the hand-modelled poses."""
import importlib.util
spec = importlib.util.spec_from_file_location('cp','catposes.py')
cp = importlib.util.module_from_spec(spec); spec.loader.exec_module(cp)

def f(v):
    s = '%.2f' % v; s = s.rstrip('0').rstrip('.')
    return s if s not in ('-0','') else '0'

def path_swift(ops, var='p', indent='            '):
    L=[]
    for op in ops:
        if op[0]=='M': L.append('%s.move(to: P(%s, %s))'%(var,f(op[1][0]),f(op[1][1])))
        elif op[0]=='L': L.append('%s.addLine(to: P(%s, %s))'%(var,f(op[1][0]),f(op[1][1])))
        elif op[0]=='C': L.append('%s.addCurve(to: P(%s, %s), control1: P(%s, %s), control2: P(%s, %s))'%(var,f(op[3][0]),f(op[3][1]),f(op[1][0]),f(op[1][1]),f(op[2][0]),f(op[2][1])))
        elif op[0]=='Q': L.append('%s.addQuadCurve(to: P(%s, %s), control: P(%s, %s))'%(var,f(op[2][0]),f(op[2][1]),f(op[1][0]),f(op[1][1])))
        elif op[0]=='Z': L.append('%s.closeSubpath()'%var)
    return ('\n'+indent).join(L)

COLMAP = {cp.OUT:'CatColors.outline', cp.ORANGE:'CatColors.orange', cp.STRIPE:'CatColors.stripe',
          cp.CREAM:'CatColors.cream', cp.BLUSH:'CatColors.blush', cp.EARPK:'CatColors.earPink'}

FACE = {  # center, scale, rot, closed, look
 'sitFront': (100,50,1.0,0,False,(0,0)),
 'loaf':     (104,68,1.0,0,False,(0,0)),
 'walk':     (62,64,0.92,0,False,(0,0)),
 'groom':    (74,46,1.0,-24,True,(0,0)),
 'lieSide':  (133,66,1.0,0,False,(-2,0)),
 'sitBack':  None,
}
TAILPIV = {'sitFront':(128,150),'loaf':(146,140),'walk':(150,96),'sitBack':(118,154),'groom':(114,124),'lieSide':(70,118)}
PAWPIV = {'groom':(98,88)}
LEGPIV = {'walk': {'legFF':(86,124),'legRF':(134,124),'legFN':(94,126),'legRN':(126,126)}}

def group_of(pose, name):
    if name.startswith('tail'): return '.tail'
    if pose=='groom' and name.startswith('paw'): return '.paw'
    if pose=='walk' and name.startswith('leg'): return '.' + name[0].lower()+name[1:]  # legFF etc
    return '.base'

order=['sitFront','loaf','groom','sitBack','walk','lieSide']
pose_code=[]
for pose in order:
    parts = cp.POSES[pose]()
    # local vars for clip sources
    clipsrc = {s['clip'] for _,_,s in parts if s and s.get('clip')}
    lines=[]
    pathmap={}
    ci=0
    for n,o,s in parts:
        if n in clipsrc and n not in pathmap:
            pathmap[n] = 'clip_'+n
    emitted=set()
    part_exprs=[]
    for n,o,s in parts:
        if n in ('eyeL','eyeR'):  # parametric in the view
            continue
        if s is None: s = cp.styl(fill=cp.STRIPE)
        # emit path (as local var if clip source, else inline builder)
        if n in pathmap and n not in emitted:
            lines.append('        let %s: Path = {\n            var p = Path()\n            %s\n            return p\n        }()' % (pathmap[n], path_swift(o)))
            emitted.add(n)
            pexpr = pathmap[n]
        elif n in pathmap:
            pexpr = pathmap[n]
        else:
            vn = 'p%d'%len(part_exprs)
            lines.append('        let %s: Path = {\n            var p = Path()\n            %s\n            return p\n        }()' % (vn, path_swift(o)))
            pexpr = vn
        fill = 'nil' if not s.get('fill') else COLMAP[s['fill']]
        stroke = 'nil' if not s.get('stroke') else COLMAP[s['stroke']]
        clip = 'nil' if not s.get('clip') else pathmap[s['clip']]
        part_exprs.append('            CatPart(path: %s, fill: %s, stroke: %s, lineWidth: %s, clip: %s, group: %s),' % (
            pexpr, fill, stroke, f(s.get('sw', 3.4)), clip, group_of(pose,n)))
    face = FACE[pose]
    if face:
        c=face
        facestr = 'CatFaceSpec(center: P(%s, %s), scale: %s, rotationDegrees: %s, eyesClosed: %s, look: P(%s, %s))' % (
            f(c[0]), f(c[1]), f(c[2]), f(c[3]), 'true' if c[4] else 'false', f(c[5][0]), f(c[5][1]))
    else:
        facestr = 'nil'
    tp = TAILPIV[pose]
    paw = PAWPIV.get(pose)
    pawstr = 'P(%s, %s)'%(f(paw[0]),f(paw[1])) if paw else 'nil'
    legs = LEGPIV.get(pose)
    if legs:
        legstr = '[%s]' % ', '.join('.%s: P(%s, %s)'%(k[0].lower()+k[1:], f(v[0]), f(v[1])) for k,v in legs.items())
    else:
        legstr = '[:]'
    pose_code.append('''    static let %s: CatPoseData = {
%s
        return CatPoseData(
            parts: [
%s
            ],
            face: %s,
            tailPivot: P(%s, %s),
            pawPivot: %s,
            legPivots: %s
        )
    }()''' % (pose, '\n'.join(lines), '\n'.join(part_exprs), facestr, f(tp[0]), f(tp[1]), pawstr, legstr))

def col(h):
    r=int(h[1:3],16)/255; g=int(h[3:5],16)/255; b=int(h[5:7],16)/255
    return 'Color(red: %.3f, green: %.3f, blue: %.3f)'%(r,g,b)

swift = '''//
//  CatPoses.swift
//  DesktopPet
//
//  小橘猫（橘白奶牛猫）的六个姿态矢量数据——按用户提供的姿态参考图
//  逐个手工描摹建模，由 tools/cat-rig/emit_cat.py 生成。
//
//  设计要点：
//  - 这套画风是"纯色块 + 粗描边"，每个姿态是一组有序部件（先画的在下面）；
//    部件 = 路径 + 填充色/描边色，橙色斑块通过 clip 到身体/头部路径实现
//    "色块贴在轮廓内"的效果。
//  - 眼睛刻意不烘焙进静态路径，由视图按 face 定位参数化绘制，才能眨眼；
//    舔毛姿态 eyesClosed = true，画舒服眯眼弧线。
//  - 尾巴是"描边管道"（粗描边色 + 细橙色两笔叠加），单独成组，绕
//    tailPivot 小幅旋转就是摆尾；行走姿态的四条腿、舔毛姿态的爪子
//    也各自成组，配套支点在 legPivots / pawPivot。
//
//  ⚠️ 数值请勿手改——想调整造型请改生成脚本后重新生成。
//

import SwiftUI

enum CatColors {
    static let outline = %s // #3a3430 描边
    static let orange  = %s // #f09a5e 橘色斑块
    static let stripe  = %s // #e5793d 深橘条纹
    static let cream   = %s // #fdf4e6 奶油底色
    static let blush   = %s // #f2b3a5 腮红
    static let earPink = %s // #f9d2c4 耳内粉
}

enum CatRig {
    static let viewW: CGFloat = 200
    static let viewH: CGFloat = 180
    static func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: p.x / viewW, y: p.y / viewH)
    }
}

/// 可独立驱动的部件分组
enum CatPartGroup {
    case base, tail, paw, legFF, legRF, legFN, legRN
}

struct CatPart {
    let path: Path
    let fill: Color?
    let stroke: Color?
    let lineWidth: CGFloat
    let clip: Path?
    let group: CatPartGroup
}

/// 眼睛的参数化定位（姿态坐标空间）
struct CatFaceSpec {
    let center: CGPoint
    let scale: CGFloat
    let rotationDegrees: CGFloat
    let eyesClosed: Bool
    let look: CGPoint
}

struct CatPoseData {
    let parts: [CatPart]
    let face: CatFaceSpec?
    let tailPivot: CGPoint
    let pawPivot: CGPoint?
    let legPivots: [CatPartGroup: CGPoint]
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

enum CatPoses {
%s
}

/// 把姿态坐标空间（200x180）的路径等比缩放到画布
struct CatPartShape: Shape {
    let base: Path
    func path(in rect: CGRect) -> Path {
        let s = rect.width / CatRig.viewW
        return base.applying(CGAffineTransform(scaleX: s, y: s))
    }
}
''' % (col(cp.OUT), col(cp.ORANGE), col(cp.STRIPE), col(cp.CREAM), col(cp.BLUSH), col(cp.EARPK),
       '\n\n'.join(pose_code))

out='/sessions/vibrant-dreamy-mccarthy/mnt/Desktop Pet/DesktopPet/DesktopPet/Views/CatPoses.swift'
open(out,'w').write(swift)
print('wrote', out, len(swift))
