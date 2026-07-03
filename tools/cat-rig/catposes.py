# -*- coding: utf-8 -*-
"""Hand-modelled vector poses of the orange-white cat (traced by eye from the
user's reference sheet). Each pose = list of parts; a part is
(name, ops, style) where style = dict(fill=, stroke=, sw=, clip=, opacity=).
Canvas per pose: 200 x 180, ground ~ y=166.
"""
import math

# palette sampled from the reference
OUT   = '#3a3430'   # dark outline
ORANGE= '#f09a5e'
STRIPE= '#e5793d'
CREAM = '#fdf4e6'
BLUSH = '#f2b3a5'
EARPK = '#f9d2c4'

def P(x,y): return (x,y)

def ops_to_d(ops):
    f=lambda v:('%.2f'%v).rstrip('0').rstrip('.')
    o=[]
    for op in ops:
        if op[0]=='M': o.append('M%s,%s'%(f(op[1][0]),f(op[1][1])))
        elif op[0]=='L': o.append('L%s,%s'%(f(op[1][0]),f(op[1][1])))
        elif op[0]=='C': o.append('C%s,%s %s,%s %s,%s'%(f(op[1][0]),f(op[1][1]),f(op[2][0]),f(op[2][1]),f(op[3][0]),f(op[3][1])))
        elif op[0]=='Q': o.append('Q%s,%s %s,%s'%(f(op[1][0]),f(op[1][1]),f(op[2][0]),f(op[2][1])))
        elif op[0]=='Z': o.append('Z')
    return ''.join(o)

def xform(ops, dx=0, dy=0, rot=0, cx=0, cy=0, sx=1, sy=1):
    """rotate deg about (cx,cy) then scale about (cx,cy) then translate"""
    r = math.radians(rot)
    def tp(p):
        x,y = p[0]-cx, p[1]-cy
        x,y = x*math.cos(r)-y*math.sin(r), x*math.sin(r)+y*math.cos(r)
        x,y = x*sx, y*sy
        return (x+cx+dx, y+cy+dy)
    out=[]
    for op in ops:
        if op[0] in 'ML': out.append((op[0], tp(op[1])))
        elif op[0]=='C': out.append(('C',tp(op[1]),tp(op[2]),tp(op[3])))
        elif op[0]=='Q': out.append(('Q',tp(op[1]),tp(op[2])))
        else: out.append(op)
    return out

def smooth_closed(pts, k=0.36):
    """closed smooth blob through points using catmull-rom-ish cubics"""
    n=len(pts); ops=[('M',pts[0])]
    for i in range(n):
        p0=pts[(i-1)%n]; p1=pts[i]; p2=pts[(i+1)%n]; p3=pts[(i+2)%n]
        c1=(p1[0]+(p2[0]-p0[0])*k/2, p1[1]+(p2[1]-p0[1])*k/2)
        c2=(p2[0]-(p3[0]-p1[0])*k/2, p2[1]-(p3[1]-p1[1])*k/2)
        ops.append(('C',c1,c2,p2))
    ops.append(('Z',))
    return ops

def smooth_open(pts, k=0.36):
    n=len(pts); ops=[('M',pts[0])]
    for i in range(n-1):
        p0=pts[max(i-1,0)]; p1=pts[i]; p2=pts[i+1]; p3=pts[min(i+2,n-1)]
        c1=(p1[0]+(p2[0]-p0[0])*k/2, p1[1]+(p2[1]-p0[1])*k/2)
        c2=(p2[0]-(p3[0]-p1[0])*k/2, p2[1]-(p3[1]-p1[1])*k/2)
        ops.append(('C',c1,c2,p2))
    return ops

def ellipse(cx,cy,rx,ry):
    k=0.5523
    return [('M',(cx+rx,cy)),
            ('C',(cx+rx,cy+ry*k),(cx+rx*k,cy+ry),(cx,cy+ry)),
            ('C',(cx-rx*k,cy+ry),(cx-rx,cy+ry*k),(cx-rx,cy)),
            ('C',(cx-rx,cy-ry*k),(cx-rx*k,cy-ry),(cx,cy-ry)),
            ('C',(cx+rx*k,cy-ry),(cx+rx,cy-ry*k),(cx+rx,cy)),
            ('Z',)]

def capsule(x1,y1,x2,y2,r):
    """rounded stroke-like capsule as filled path"""
    ang=math.atan2(y2-y1,x2-x1); nx,ny=-math.sin(ang)*r, math.cos(ang)*r
    k=0.5523*r
    dx,dy=math.cos(ang),math.sin(ang)
    a=(x1+nx,y1+ny); b=(x2+nx,y2+ny); c=(x2-nx,y2-ny); d=(x1-nx,y1-ny)
    return [('M',a),('L',b),
            ('C',(b[0]+dx*k*2.4,b[1]+dy*k*2.4),(c[0]+dx*k*2.4,c[1]+dy*k*2.4),c),
            ('L',d),
            ('C',(d[0]-dx*k*2.4,d[1]-dy*k*2.4),(a[0]-dx*k*2.4,a[1]-dy*k*2.4),a),('Z',)]

SW = 4.2  # outline width

def styl(fill=None, stroke=None, sw=SW, clip=None, opacity=1.0):
    return dict(fill=fill, stroke=stroke, sw=sw, clip=clip, opacity=opacity)

# ---------------------------------------------------------------- face -----
def face(cx, cy, s=1.0, eyes='open', look=(0,0), blush=True, whisk=True, rot=0):
    """front-facing face features. returns list of parts (no head shape)."""
    parts=[]
    ex, ey = 17*s, 2*s
    def T(o): return xform(o, rot=rot, cx=cx, cy=cy)
    if eyes=='open':
        parts.append(('eyeL', T(ellipse(cx-ex+look[0],cy+ey+look[1],4.6*s,5.4*s)), styl(fill=OUT)))
        parts.append(('eyeR', T(ellipse(cx+ex+look[0],cy+ey+look[1],4.6*s,5.4*s)), styl(fill=OUT)))
    else: # closed: content arcs
        for sgn,nm in [(-1,'eyeL'),(1,'eyeR')]:
            x=cx+sgn*ex
            parts.append((nm, T([('M',(x-5*s,cy+ey)),('Q',(x,cy+ey+4.5*s),(x+5*s,cy+ey))]), styl(stroke=OUT, sw=3.2*s)))
    # nose + mouth
    parts.append(('nose', T([('M',(cx-2.2*s,cy+9.5*s)),('L',(cx+2.2*s,cy+9.5*s)),('L',(cx,cy+12.3*s)),('Z',)]), styl(fill=OUT)))
    if blush:
        parts.append(('blushL', T(ellipse(cx-ex-10*s, cy+9*s, 6.2*s, 3.6*s)), styl(fill=BLUSH)))
        parts.append(('blushR', T(ellipse(cx+ex+10*s, cy+9*s, 6.2*s, 3.6*s)), styl(fill=BLUSH)))
    if whisk:
        w=[]
        for sgn in (-1,1):
            bx=cx+sgn*30*s
            for i,dy in enumerate((-4,2,8)):
                w.append(('M',(bx, cy+dy*s+2*s)))
                w.append(('L',(bx+sgn*24*s, cy+(dy*2.0-3)*s)))
        parts.append(('whiskers', T(w), styl(stroke=OUT, sw=1.8*s)))
    return parts

def ear(cx, cy, w, h, rot, inner=True):
    """rounded triangle ear pointing up, rotated about its base center"""
    o = smooth_closed([(cx-w/2,cy),(cx,cy-h),(cx+w/2,cy)], k=0.5)
    parts=[('ear', xform(o, rot=rot, cx=cx, cy=cy), styl(fill=CREAM, stroke=OUT))]
    if inner:
        oi = smooth_closed([(cx-w*0.27,cy-h*0.12),(cx,cy-h*0.62),(cx+w*0.27,cy-h*0.12)], k=0.5)
        parts.append(('earIn', xform(oi, rot=rot, cx=cx, cy=cy), styl(fill=EARPK)))
    return parts

def stripes(pts, r, rot=0):
    """small rounded stripe marks; pts = [(x,y,angle)]"""
    ops=[]
    for (x,y,a) in pts:
        aa=math.radians(a)
        dx,dy=math.cos(aa)*r*1.6, math.sin(aa)*r*1.6
        ops += capsule(x-dx,y-dy,x+dx,y+dy,r*0.62)
    return ops


# ---------------------------------------------------------------- poses ----
# part = (name, ops, style). clip='<name>' clips to that earlier part's path.
# tails are stroked tubes: two parts (outline stroke wider + orange stroke).

def tail_tube(name, pts, w=13, color=ORANGE):
    path = smooth_open(pts)
    return [(name+'Out', path, styl(stroke=OUT, sw=w+2*3.4)),
            (name, path, styl(stroke=color, sw=w))]

def tail_marks(marks, r=3.4):
    return [('tailMarks', stripes(marks, r), styl(fill=STRIPE))]

def head_stripes(cx, top, s=1.0):
    return [('headStripes', stripes([(cx-13*s, top+7*s, 75),(cx, top+4*s, 90),(cx+13*s, top+7*s, 105)], 3.0*s), None)]  # style set later w/ clip

def pose_sitFront():
    parts=[]
    parts += tail_tube('tail', [(128,150),(154,158),(174,152),(187,142)])
    parts += tail_marks([(158,156,10),(172,151,20),(184,143,35)])
    parts += ear(72,22,32,28,-18); parts += ear(128,22,32,28,18)
    for p in parts[-4:]:
        if p[0]=='ear': p[2]['fill']=ORANGE
    body = smooth_closed([(100,74),(72,86),(59,126),(66,156),(100,166),(134,156),(141,126),(128,86)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchR', smooth_closed([(126,84),(144,102),(144,140),(124,158),(114,120)]), styl(fill=ORANGE, clip='body')))
    parts.append(('patchL', ellipse(66,142,15,19), styl(fill=ORANGE, clip='body')))
    parts.append(('legs', [('M',(87,120)),('C',(86,132),(86,144),(86,150)),('Q',(86,160),(95,160)),
                            ('M',(113,120)),('C',(114,132),(114,144),(114,150)),('Q',(114,160),(105,160))],
                  styl(stroke=OUT, sw=3.4)))
    head = smooth_closed([(100,12),(66,21),(55,46),(63,70),(100,80),(137,70),(145,46),(134,21)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(50,54),(70,42),(100,48),(130,42),(150,54),(148,12),(52,12)]), styl(fill=ORANGE, clip='head')))
    hs = head_stripes(100,10); hs[0][2] and None
    parts.append(('headStripes', stripes([(87,17,75),(100,14,90),(113,17,105)],3.0), styl(fill=STRIPE, clip='head')))
    parts += face(100,50)
    return parts

def pose_loaf():
    parts=[]
    parts += tail_tube('tail', [(146,140),(168,140),(182,133),(189,127)], w=12)
    parts += tail_marks([(170,139,5),(181,134,20),(188,128,30)], r=3.0)
    body = smooth_closed([(36,148),(34,118),(54,96),(90,87),(126,93),(151,111),(155,140),(138,160),(80,164),(46,160)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchBack', smooth_closed([(35,116),(60,92),(102,88),(92,122),(60,150),(37,140)]), styl(fill=ORANGE, clip='body')))
    parts.append(('pawLine', [('M',(108,161)),('Q',(116,152),(128,156)),('M',(128,156)),('Q',(136,160),(130,163))], styl(stroke=OUT, sw=3.2)))
    parts += ear(80,42,30,26,-18); parts += ear(130,42,30,26,16)
    head = smooth_closed([(104,32),(72,40),(62,64),(70,86),(104,95),(137,86),(145,64),(136,40)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(58,72),(76,60),(104,66),(132,60),(149,72),(146,32),(60,32)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(91,37,75),(104,34,90),(117,37,105)],3.0), styl(fill=STRIPE, clip='head')))
    parts += face(104,68)
    return parts

def pose_walk():
    parts=[]
    parts += tail_tube('tail', [(152,94),(170,86),(181,69),(184,50)], w=12)
    parts += tail_marks([(172,84,-40),(180,70,-65),(184,54,-80)], r=3.0)
    # far legs
    parts.append(('legFF', capsule(80,116,68,156,7), styl(fill=CREAM, stroke=OUT)))
    parts.append(('legRF', capsule(136,116,150,154,7), styl(fill=CREAM, stroke=OUT)))
    body = smooth_closed([(58,86),(102,76),(148,84),(167,102),(159,128),(118,140),(78,137),(51,114)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('saddle', smooth_closed([(66,80),(120,72),(160,90),(150,114),(108,96),(72,98)]), styl(fill=ORANGE, clip='body')))
    # near legs
    parts.append(('legFN', capsule(88,118,79,158,8), styl(fill=CREAM, stroke=OUT)))
    parts.append(('legRN', capsule(130,118,142,158,8), styl(fill=CREAM, stroke=OUT)))
    parts += ear(44,36,28,24,-24); parts += ear(88,32,28,24,8)
    head = smooth_closed([(64,28),(34,38),(26,60),(34,82),(64,92),(94,82),(102,60),(94,38)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(22,66),(40,56),(64,62),(88,56),(106,66),(102,28),(26,28)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(52,33,75),(64,30,90),(76,33,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts += face(64,62, s=0.92)
    return parts

def pose_sitBack():
    parts=[]
    parts += tail_tube('tail', [(120,152),(144,146),(162,152),(167,165)], w=12)
    parts += tail_marks([(146,147,0),(160,152,25),(166,161,60)], r=3.0)
    body = smooth_closed([(100,60),(66,73),(53,110),(57,146),(82,164),(100,166),(120,164),(143,146),(147,110),(134,73)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('backPatch', smooth_closed([(52,122),(58,72),(100,54),(140,70),(150,118),(118,134),(74,132)]), styl(fill=ORANGE, clip='body')))
    parts += ear(80,18,30,26,-15, inner=False); parts += ear(120,18,30,26,15, inner=False)
    for p in parts[-2:]: p[2]['fill']=ORANGE
    head = smooth_closed([(100,12),(74,21),(65,42),(74,62),(100,69),(126,62),(135,42),(126,21)])
    parts.append(('head', head, styl(fill=ORANGE, stroke=OUT)))
    parts.append(('headStripes', stripes([(88,17,75),(100,14,90),(112,17,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts.append(('whiskB', [('M',(66,44)),('L',(46,40)),('M',(66,50)),('L',(48,50)),
                             ('M',(134,44)),('L',(154,40)),('M',(134,50)),('L',(152,50))], styl(stroke=OUT, sw=1.8)))
    return parts

def pose_groom():
    parts=[]
    parts += tail_tube('tail', [(116,120),(94,144),(72,160),(55,166)], w=12)
    parts += tail_marks([(88,148,-40),(72,159,-20),(58,165,-10)], r=3.0)
    body = smooth_closed([(86,62),(120,56),(147,82),(152,118),(128,146),(96,148),(75,120),(71,88)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchR', smooth_closed([(118,58),(148,86),(148,120),(124,144),(108,98)]), styl(fill=ORANGE, clip='body')))
    # tilted head with closed eyes
    hcx,hcy,rot = 76,42,-24
    e1 = ear(52,20,30,26,-30); e2 = ear(102,12,30,26,10)
    for grp in (e1,e2):
        for p in grp: p[1][:] = xform(p[1], rot=rot, cx=hcx, cy=hcy)
        parts += grp
    head = xform(smooth_closed([(76,8),(44,17),(34,42),(42,64),(76,74),(109,64),(117,42),(108,17)]), rot=rot, cx=hcx, cy=hcy)
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', xform(smooth_closed([(30,50),(48,38),(76,44),(104,38),(122,50),(120,8),(32,8)]), rot=rot, cx=hcx, cy=hcy), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', xform(stripes([(63,13,75),(76,10,90),(89,13,105)],2.8), rot=rot, cx=hcx, cy=hcy), styl(fill=STRIPE, clip='head')))
    parts += face(76,46, eyes='closed', rot=rot)
    # raised paw in front of cheek
    parts.append(('paw', capsule(112,80,86,52,9), styl(fill=CREAM, stroke=OUT)))
    return parts

def pose_lieSide():
    parts=[]
    parts += tail_tube('tail', [(66,116),(46,140),(58,158),(92,164),(118,157)], w=13)
    parts += tail_marks([(50,146,-70),(66,159,-15),(90,164,0)], r=3.2)
    body = smooth_closed([(62,100),(98,86),(138,88),(161,105),(163,132),(141,152),(96,156),(62,138)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchL', smooth_closed([(60,102),(92,88),(98,120),(78,142),(60,132)]), styl(fill=ORANGE, clip='body')))
    parts.append(('patchR', smooth_closed([(142,92),(162,108),(158,136),(138,148),(128,116)]), styl(fill=ORANGE, clip='body')))
    parts.append(('paw', capsule(94,136,79,156,8), styl(fill=CREAM, stroke=OUT)))
    parts += ear(110,36,29,25,-22); parts += ear(156,40,29,25,20)
    head = smooth_closed([(133,30),(102,39),(93,62),(101,84),(133,93),(164,84),(172,62),(164,39)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(89,70),(106,58),(133,64),(160,58),(176,70),(173,30),(92,30)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(120,35,75),(133,32,90),(146,35,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts += face(133,66, look=(-2,0))
    return parts

POSES = {
 'groom': pose_groom, 'loaf': pose_loaf, 'sitFront': pose_sitFront,
 'sitBack': pose_sitBack, 'walk': pose_walk, 'lieSide': pose_lieSide,
}

def pose_svg(parts, extra=''):
    defs=[]; body=[]
    pathmap = {n: ops_to_d(o) for n,o,s in parts}
    ci=0
    for n,o,s in parts:
        if s is None: s = styl(fill=STRIPE)
        d = ops_to_d(o)
        attrs=[]
        if s.get('clip'):
            ci+=1
            defs.append('<clipPath id="c%d"><path d="%s"/></clipPath>' % (ci, pathmap[s['clip']]))
            attrs.append('clip-path="url(#c%d)"' % ci)
        f = s.get('fill'); st = s.get('stroke')
        attrs.append('fill="%s"' % (f if f else 'none'))
        if st: attrs.append('stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"' % (st, s.get('sw',SW)))
        if s.get('opacity',1)!=1: attrs.append('opacity="%.2f"'%s['opacity'])
        body.append('<path d="%s" %s/>' % (d, ' '.join(attrs)))
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 180"><defs>%s</defs>%s%s</svg>' % (''.join(defs), ''.join(body), extra)

if __name__=='__main__':
    import cairosvg
    from PIL import Image
    order=['groom','loaf','sitFront','sitBack','walk','lieSide']
    tiles=[]
    for k in order:
        svg=pose_svg(POSES[k]())
        open('p_%s.svg'%k,'w').write(svg)
        cairosvg.svg2png(url='p_%s.svg'%k, write_to='p_%s.png'%k, output_width=330, background_color='#f4f4f4')
        tiles.append(Image.open('p_%s.png'%k).convert('RGBA'))
    w,h=tiles[0].size
    g=Image.new('RGBA',(w*3,h*2),(244,244,244,255))
    for i,t in enumerate(tiles): g.paste(t,((i%3)*w,(i//3)*h),t)
    g.save('../cat_grid.png'); print('ok')

# ============================ v2 overrides ============================
SW = 3.4

def face(cx, cy, s=1.0, eyes='open', look=(0,0), blush=True, whisk=True, rot=0):
    parts=[]
    ex, ey = 17*s, 2*s
    def T(o): return xform(o, rot=rot, cx=cx, cy=cy)
    if eyes=='open':
        parts.append(('eyeL', T(ellipse(cx-ex+look[0],cy+ey+look[1],4.4*s,5.2*s)), styl(fill=OUT)))
        parts.append(('eyeR', T(ellipse(cx+ex+look[0],cy+ey+look[1],4.4*s,5.2*s)), styl(fill=OUT)))
    else:
        for sgn,nm in [(-1,'eyeL'),(1,'eyeR')]:
            x=cx+sgn*ex
            parts.append((nm, T([('M',(x-4.6*s,cy+ey)),('Q',(x,cy+ey+4.2*s),(x+4.6*s,cy+ey))]), styl(stroke=OUT, sw=2.8*s)))
    parts.append(('nose', T([('M',(cx-2.0*s,cy+9.5*s)),('L',(cx+2.0*s,cy+9.5*s)),('L',(cx,cy+12.0*s)),('Z',)]), styl(fill=OUT)))
    if blush:
        parts.append(('blushL', T(ellipse(cx-ex-9*s, cy+9.5*s, 5.8*s, 3.4*s)), styl(fill=BLUSH)))
        parts.append(('blushR', T(ellipse(cx+ex+9*s, cy+9.5*s, 5.8*s, 3.4*s)), styl(fill=BLUSH)))
    if whisk:
        w=[]
        for sgn in (-1,1):
            bx=cx+sgn*27*s
            for dy in (-3,2,7):
                w.append(('M',(bx, cy+(dy+2)*s)))
                w.append(('L',(bx+sgn*19*s, cy+(dy*1.25+1)*s)))
        parts.append(('whiskers', T(w), styl(stroke=OUT, sw=1.5*s)))
    return parts

def ear(cx, cy, w, h, rot, inner=True, fill=CREAM):
    o = smooth_closed([(cx-w/2,cy),(cx,cy-h),(cx+w/2,cy)], k=0.5)
    parts=[('ear', xform(o, rot=rot, cx=cx, cy=cy), styl(fill=fill, stroke=OUT))]
    if inner:
        oi = smooth_closed([(cx-w*0.20,cy-h*0.20),(cx,cy-h*0.62),(cx+w*0.20,cy-h*0.20)], k=0.5)
        parts.append(('earIn', xform(oi, rot=rot, cx=cx, cy=cy), styl(fill=EARPK)))
    return parts

def tail_tube(name, pts, w=13, color=ORANGE):
    path = smooth_open(pts)
    return [(name+'Out', path, styl(stroke=OUT, sw=w+2*2.9)),
            (name, path, styl(stroke=color, sw=w))]

def pose_sitFront():
    parts=[]
    parts += tail_tube('tail', [(128,150),(154,158),(174,152),(187,142)])
    parts += tail_marks([(158,156,10),(172,151,20),(184,143,35)])
    parts += ear(72,22,32,28,-18, fill=ORANGE); parts += ear(128,22,32,28,18, fill=ORANGE)
    body = smooth_closed([(100,74),(69,86),(56,126),(64,156),(100,166),(136,156),(144,126),(131,86)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchR', smooth_closed([(124,82),(146,100),(146,142),(122,160),(108,118)]), styl(fill=ORANGE, clip='body')))
    parts.append(('patchL', ellipse(65,142,15,19), styl(fill=ORANGE, clip='body')))
    parts.append(('legs', [('M',(87,118)),('L',(87,151)),('Q',(87,160),(96,160)),
                            ('M',(113,118)),('L',(113,151)),('Q',(113,160),(104,160))],
                  styl(stroke=OUT, sw=3.2)))
    head = smooth_closed([(100,12),(66,21),(55,46),(63,70),(100,80),(137,70),(145,46),(134,21)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(50,52),(70,40),(100,44),(130,40),(150,52),(148,12),(52,12)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(87,17,75),(100,14,90),(113,17,105)],3.0), styl(fill=STRIPE, clip='head')))
    parts += face(100,50)
    return parts

def pose_loaf():
    parts=[]
    parts += tail_tube('tail', [(146,140),(168,140),(182,133),(189,127)], w=12)
    parts += tail_marks([(170,139,5),(181,134,20),(188,128,30)], r=3.0)
    body = smooth_closed([(36,148),(34,118),(54,96),(90,87),(126,93),(151,111),(155,140),(138,160),(80,164),(46,160)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchBack', smooth_closed([(35,116),(60,92),(102,88),(92,122),(60,150),(37,140)]), styl(fill=ORANGE, clip='body')))
    parts.append(('pawLine', [('M',(102,161)),('Q',(112,151),(126,156))], styl(stroke=OUT, sw=3.0)))
    parts += ear(80,42,30,26,-18); parts += ear(130,42,30,26,16)
    head = smooth_closed([(104,32),(72,40),(62,64),(70,86),(104,95),(137,86),(145,64),(136,40)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(58,70),(76,58),(104,62),(132,58),(149,70),(146,32),(60,32)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(91,37,75),(104,34,90),(117,37,105)],3.0), styl(fill=STRIPE, clip='head')))
    parts += face(104,68)
    return parts

def pose_walk():
    parts=[]
    parts += tail_tube('tail', [(150,96),(168,88),(180,70),(183,52)], w=13)
    parts += tail_marks([(170,86,-40),(179,72,-65),(183,56,-80)], r=3.2)
    parts.append(('legFF', capsule(86,124,76,157,8), styl(fill=CREAM, stroke=OUT)))
    parts.append(('legRF', capsule(134,124,146,155,8), styl(fill=CREAM, stroke=OUT)))
    body = smooth_closed([(56,92),(100,82),(146,88),(164,104),(158,128),(118,140),(76,138),(48,116)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('saddle', smooth_closed([(64,84),(118,76),(158,92),(150,116),(108,98),(70,100)]), styl(fill=ORANGE, clip='body')))
    parts.append(('legFN', capsule(94,126,86,160,9), styl(fill=CREAM, stroke=OUT)))
    parts.append(('legRN', capsule(126,126,138,159,9), styl(fill=CREAM, stroke=OUT)))
    parts += ear(42,38,28,24,-24); parts += ear(88,34,28,24,8)
    head = smooth_closed([(62,28),(31,38),(22,62),(31,85),(62,96),(93,85),(102,62),(93,38)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(18,68),(38,56),(62,60),(86,56),(106,68),(102,28),(24,28)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(50,33,75),(62,30,90),(74,33,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts += face(62,64, s=0.92)
    return parts

def pose_sitBack():
    parts=[]
    parts += tail_tube('tail', [(118,154),(146,148),(164,156),(165,170)], w=13)
    parts += tail_marks([(148,148,0),(161,154,30),(165,164,70)], r=3.2)
    body = smooth_closed([(100,64),(68,76),(54,112),(58,148),(84,166),(116,166),(142,148),(146,112),(132,76)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('backPatch', smooth_closed([(53,124),(58,74),(100,58),(140,72),(149,120),(118,136),(74,134)]), styl(fill=ORANGE, clip='body')))
    parts += ear(80,16,30,26,-15, inner=False, fill=ORANGE); parts += ear(120,16,30,26,15, inner=False, fill=ORANGE)
    head = smooth_closed([(100,10),(74,19),(65,40),(74,60),(100,67),(126,60),(135,40),(126,19)])
    parts.append(('head', head, styl(fill=ORANGE, stroke=OUT)))
    parts.append(('headStripes', stripes([(88,15,75),(100,12,90),(112,15,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts.append(('whiskB', [('M',(66,42)),('L',(52,38)),('M',(66,48)),('L',(53,48)),
                             ('M',(134,42)),('L',(148,38)),('M',(134,48)),('L',(147,48))], styl(stroke=OUT, sw=1.5)))
    return parts

def pose_groom():
    parts=[]
    parts += tail_tube('tail', [(114,124),(94,148),(74,162),(58,167)], w=12)
    parts += tail_marks([(88,152,-42),(72,162,-22),(60,166,-10)], r=3.0)
    body = smooth_closed([(82,56),(122,50),(152,78),(158,118),(134,148),(98,152),(72,122),(66,84)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchR', smooth_closed([(120,52),(152,82),(154,120),(128,146),(108,96)]), styl(fill=ORANGE, clip='body')))
    hcx,hcy,rot = 74,42,-24
    e1 = ear(50,16,30,26,-28); e2 = ear(102,10,30,26,8)
    for grp in (e1,e2):
        parts += [(n, xform(o, rot=rot, cx=hcx, cy=hcy), s) for n,o,s in grp]
    head = xform(smooth_closed([(74,8),(42,17),(32,42),(40,64),(74,74),(107,64),(115,42),(106,17)]), rot=rot, cx=hcx, cy=hcy)
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', xform(smooth_closed([(28,46),(46,34),(74,38),(102,34),(120,46),(118,8),(30,8)]), rot=rot, cx=hcx, cy=hcy), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', xform(stripes([(61,13,75),(74,10,90),(87,13,105)],2.8), rot=rot, cx=hcx, cy=hcy), styl(fill=STRIPE, clip='head')))
    parts += face(74,46, eyes='closed', rot=rot, whisk=True)
    parts.append(('paw', capsule(98,88,85,62,8.5), styl(fill=CREAM, stroke=OUT)))
    parts.append(('pawToe', [('M',(82,68)),('Q',(88,66),(90,71))], styl(stroke=OUT, sw=2.2)))
    return parts

def pose_lieSide():
    parts=[]
    body = smooth_closed([(62,100),(98,86),(138,88),(161,105),(163,132),(141,152),(96,156),(62,138)])
    parts.append(('body', body, styl(fill=CREAM, stroke=OUT)))
    parts.append(('patchL', smooth_closed([(60,102),(92,88),(98,120),(78,142),(60,132)]), styl(fill=ORANGE, clip='body')))
    parts.append(('patchR', smooth_closed([(142,92),(162,108),(158,136),(138,148),(128,116)]), styl(fill=ORANGE, clip='body')))
    parts += tail_tube('tail', [(70,118),(48,142),(64,161),(102,166),(131,158)], w=13)
    parts += tail_marks([(52,148,-70),(70,160,-15),(96,165,0),(122,162,10)], r=3.2)
    parts.append(('paw', capsule(96,134,85,155,8), styl(fill=CREAM, stroke=OUT)))
    parts += ear(110,36,29,25,-22); parts += ear(156,40,29,25,20)
    head = smooth_closed([(133,30),(102,39),(93,62),(101,84),(133,93),(164,84),(172,62),(164,39)])
    parts.append(('head', head, styl(fill=CREAM, stroke=OUT)))
    parts.append(('cap', smooth_closed([(89,68),(106,56),(133,60),(160,56),(176,68),(173,30),(92,30)]), styl(fill=ORANGE, clip='head')))
    parts.append(('headStripes', stripes([(120,35,75),(133,32,90),(146,35,105)],2.8), styl(fill=STRIPE, clip='head')))
    parts += face(133,66, look=(-2,0))
    return parts

POSES = {
 'groom': pose_groom, 'loaf': pose_loaf, 'sitFront': pose_sitFront,
 'sitBack': pose_sitBack, 'walk': pose_walk, 'lieSide': pose_lieSide,
}
