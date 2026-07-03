# -*- coding: utf-8 -*-
"""Render posed frames of the decomposed dog to validate joint math.
Transforms mirror exactly what SwiftUI rotationEffect nesting will do."""
import math, subprocess, sys
import importlib.util
spec = importlib.util.spec_from_file_location('dp', 'dogparts.py')
dp = importlib.util.module_from_spec(spec); spec.loader.exec_module(dp)

J = dp.J
# knee pivot points (midpoint of the two edges at knee y)
def midpt(a, b): return ((a[0]+b[0])/2, (a[1]+b[1])/2)
kFF = midpt(dp.cubic_point(*dp.seg(36), dp.t_at_y(36, J['kneeFF_y'])), dp.pt(4, dp.t_at_y(4, J['kneeFF_y'])))
kNF = midpt(dp.pt(8, dp.t_at_y(8, J['kneeNF_y'])), dp.pt(12, dp.t_at_y(12, J['kneeNF_y'])))
kNR = midpt(dp.pt(14, dp.t_at_y(14, J['kneeNR_y'])), dp.pt(20, dp.t_at_y(20, J['kneeNR_y'])))
_fr_b = dp.fr_seg(1); _fr_f = dp.fr_seg(3)
kFR = midpt(dp.cubic_point(*_fr_f, dp.cubic_t_for_y(*_fr_f, J['kneeFR_y'])),
            dp.cubic_point(*_fr_b, dp.cubic_t_for_y(*_fr_b, J['kneeFR_y'])))
PIVOTS = {'kFF':kFF, 'kNF':kNF, 'kNR':kNR, 'kFR':kFR}

# part -> list of (pivotKey, angleKey); innermost rotation LAST in svg transform string
RIG = {
  'tail':        [('tail','tail')], 'tailDetail': [('tail','tail')],
  'farRearThigh':[('hipFR','hipFR')],
  'farRearShank':[('hipFR','hipFR'), ('kFR','kneeFR')],
  'farFrontThigh':[('hipFF','hipFF')],
  'farFrontShank':[('hipFF','hipFF'), ('kFF','kneeFF')],
  'body': [], 'spotSaddle': [], 'spotChest': [], 'spotChestLow': [], 'bodyShade': [],
  'nearRearThigh':[('hipNR','hipNR')], 'nearRearThighShade':[('hipNR','hipNR')], 'spotRearThigh':[('hipNR','hipNR')],
  'nearRearShank':[('hipNR','hipNR'), ('kNR','kneeNR')], 'nearRearShankShade':[('hipNR','hipNR'), ('kNR','kneeNR')],
  'nearFrontThigh':[('hipNF','hipNF')],
  'nearFrontShank':[('hipNF','hipNF'), ('kNF','kneeNF')],
}
HEAD_PARTS = ['head','neckShade','eyePatch','nose','smile','blush','noseShine','earTuft',
              'earSmall','earSmallDetail','earFloppy','earFloppyInner','eyeWhite','pupil']
for p in HEAD_PARTS: RIG[p] = [('neck','head')]
RIG['earFloppy'] = [('neck','head'), ('earFloppy','earF')]
RIG['earFloppyInner'] = [('neck','head'), ('earFloppy','earF')]
RIG['earSmall'] = [('neck','head'), ('earSmall','earS')]
RIG['earSmallDetail'] = [('neck','head'), ('earSmall','earS')]

def pivot(key):
    return PIVOTS.get(key) or J[key]

def render_svg(pose, fname):
    dy = pose.get('dy', 0)
    bodyRot = pose.get('bodyRot', 0)
    parts = []
    for name in dp.ZORDER:
        ops, fill, opac = dp.PARTMAP[name]
        chain = RIG[name]
        tfs = []
        if dy or bodyRot:
            tfs.append('translate(0 %.2f)' % dy)
            if bodyRot: tfs.append('rotate(%.2f 75 150)' % bodyRot)
        for pk, ak in chain:
            a = pose.get(ak, 0)
            if a:
                px, py = pivot(pk)
                tfs.append('rotate(%.2f %.2f %.2f)' % (a, px, py))
        t = (' transform="%s"' % ' '.join(tfs)) if tfs else ''
        o = '' if opac==1 else ' opacity="%.2f"' % opac
        parts.append('<path fill="%s"%s%s d="%s"/>' % (fill, o, t, dp.ops_to_d(ops)))
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -12 180.03 215.21">%s</svg>' % ''.join(parts)
    open(fname,'w').write(svg)

def run_pose(phi, intensity=1.0):
    """trot gait. phase pairs: nearFront+farRear = 0, farFront+nearRear = pi"""
    A = 16 + 14*intensity     # hip swing amplitude
    K = 22 + 16*intensity     # knee bend amplitude
    def leg(off, front):
        hip = A * math.sin(phi + off)
        # knee bends when the leg is lifted/swinging: bend peaks shortly after backswing
        bend = max(0.0, math.sin(phi + off + (1.9 if front else 2.1)))
        knee = (K if front else -K) * bend
        return hip, knee
    hipNF, kneeNF = leg(0, True)
    hipFR, kneeFR = leg(0, False)
    hipFF, kneeFF = leg(math.pi, True)
    hipNR, kneeNR = leg(math.pi, False)
    bounce = -abs(math.sin(phi)) * (3 + 4*intensity)
    return dict(hipNF=hipNF, kneeNF=kneeNF, hipFR=hipFR, kneeFR=kneeFR,
                hipFF=hipFF, kneeFF=kneeFF, hipNR=hipNR, kneeNR=kneeNR,
                dy=bounce, head=3*math.sin(phi*2), tail=10*math.sin(phi+1.0),
                earF=8*math.sin(phi+0.8), earS=6*math.sin(phi+0.8))

if __name__ == '__main__':
    import cairosvg
    from PIL import Image
    frames = []
    N = 8
    for i in range(N):
        phi = 2*math.pi*i/N
        render_svg(run_pose(phi), 'f%02d.svg' % i)
        cairosvg.svg2png(url='f%02d.svg' % i, write_to='f%02d.png' % i, output_width=270)
        frames.append('f%02d.png' % i)
    imgs = [Image.open(f).convert('RGBA') for f in frames]
    w, h = imgs[0].size
    grid = Image.new('RGBA', (w*4, h*2), (255,255,255,255))
    for i, im in enumerate(imgs):
        grid.paste(im, ((i%4)*w, (i//4)*h), im)
    grid.save('../run_frames.png')
    print('wrote run_frames.png')
