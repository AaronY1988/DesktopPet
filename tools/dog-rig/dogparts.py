# -*- coding: utf-8 -*-
"""Decompose the spotted-dog SVG into independently animatable parts.

Ops model: ('M',(x,y)) ('L',(x,y)) ('C',(c1),(c2),(p)) ('Q',(c),(p)) ('Z',)
All coords in the original 180.03 x 203.21 viewBox space.
"""
import re, math

NUM = r'(-?(?:\d+\.?\d*|\.\d+))'

def parse(d):
    toks = [m.group(0) for m in re.finditer(r'([MmCcSsLlHhVvZz])|' + NUM, d)]
    i = 0; cx = cy = 0; ops = []; cmd = None
    def nxt():
        nonlocal i
        v = float(toks[i]); i += 1; return v
    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]; i += 1
        if cmd in 'Mm':
            x, y = nxt(), nxt()
            if cmd == 'm': x += cx; y += cy
            cx, cy = x, y; ops.append(('M', (x, y))); cmd = 'L' if cmd == 'M' else 'l'
        elif cmd in 'Cc':
            x1,y1,x2,y2,x,y = nxt(),nxt(),nxt(),nxt(),nxt(),nxt()
            if cmd == 'c': x1+=cx;y1+=cy;x2+=cx;y2+=cy;x+=cx;y+=cy
            ops.append(('C',(x1,y1),(x2,y2),(x,y))); cx,cy = x,y
        elif cmd in 'Ss':
            x2,y2,x,y = nxt(),nxt(),nxt(),nxt()
            if cmd == 's': x2+=cx;y2+=cy;x+=cx;y+=cy
            if ops and ops[-1][0]=='C':
                px,py = ops[-1][2]
                x1,y1 = 2*cx-px, 2*cy-py
            else:
                x1,y1 = cx,cy
            ops.append(('C',(x1,y1),(x2,y2),(x,y))); cx,cy = x,y
        elif cmd in 'Ll':
            x,y = nxt(),nxt()
            if cmd == 'l': x+=cx; y+=cy
            ops.append(('L',(x,y))); cx,cy = x,y
        elif cmd in 'Hh':
            x = nxt()
            if cmd == 'h': x += cx
            ops.append(('L',(x,cy))); cx = x
        elif cmd in 'Vv':
            y = nxt()
            if cmd == 'v': y += cy
            ops.append(('L',(cx,y))); cy = y
        elif cmd in 'Zz':
            ops.append(('Z',))
        else:
            raise ValueError(cmd)
    return ops

def cubic_point(p0,c1,c2,p1,t):
    mt = 1-t
    return (mt**3*p0[0]+3*mt*mt*t*c1[0]+3*mt*t*t*c2[0]+t**3*p1[0],
            mt**3*p0[1]+3*mt*mt*t*c1[1]+3*mt*t*t*c2[1]+t**3*p1[1])

def cubic_split(p0,c1,c2,p1,t0,t1):
    """de Casteljau: return control points of the sub-curve on [t0,t1]."""
    def split_at(p0,c1,c2,p1,t):
        a=lerp(p0,c1,t); b=lerp(c1,c2,t); c=lerp(c2,p1,t)
        d=lerp(a,b,t); e=lerp(b,c,t); f=lerp(d,e,t)
        return (p0,a,d,f),(f,e,c,p1)
    def lerp(a,b,t): return (a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t)
    _, right = split_at(p0,c1,c2,p1,t0)
    if t0 >= 1: return right
    t1r = (t1-t0)/(1-t0)
    left, _ = split_at(*right, t1r)
    return left

def cubic_t_for_y(p0,c1,c2,p1,y,steps=200):
    """bisect assuming monotonic y"""
    lo, hi = 0.0, 1.0
    ylo = p0[1]; yhi = p1[1]
    inc = yhi > ylo
    for _ in range(60):
        mid = (lo+hi)/2
        ym = cubic_point(p0,c1,c2,p1,mid)[1]
        if (ym < y) == inc: lo = mid
        else: hi = mid
    return (lo+hi)/2

def rev(ops):
    """reverse a list of ops that begins with M and has no Z"""
    pts = []  # (type, data, endpoint)
    cur = None; segs = []
    for op in ops:
        if op[0]=='M': cur = op[1]
        elif op[0]=='L': segs.append(('L', None, cur, op[1])); cur = op[1]
        elif op[0]=='C': segs.append(('C', (op[1],op[2]), cur, op[3])); cur = op[3]
        elif op[0]=='Q': segs.append(('Q', (op[1],), cur, op[2])); cur = op[2]
    out = [('M', cur)]
    for typ, ctrl, start, end in reversed(segs):
        if typ=='L': out.append(('L', start))
        elif typ=='C': out.append(('C', ctrl[1], ctrl[0], start))
        elif typ=='Q': out.append(('Q', ctrl[0], start))
    return out

def seg_portion(start, seg, t0, t1):
    """portion of one cubic seg ('C',c1,c2,p). returns (ops without M, new endpoint)"""
    p0,c1,c2,p1 = start, seg[1], seg[2], seg[3]
    q = cubic_split(p0,c1,c2,p1,t0,t1)
    return [('C',q[1],q[2],q[3])], q[3]

def semicircle(a, b, toward):
    """cubic half-disc cap from a to b, bulging toward the given point."""
    dx, dy = b[0]-a[0], b[1]-a[1]
    L = math.hypot(dx,dy) or 1
    nx, ny = -dy/L, dx/L   # left normal
    mx, my = (a[0]+b[0])/2, (a[1]+b[1])/2
    if (toward[0]-mx)*nx + (toward[1]-my)*ny < 0:
        nx, ny = -nx, -ny
    k = 4/3 * (L/2)
    c1 = (a[0]+nx*k, a[1]+ny*k)
    c2 = (b[0]+nx*k, b[1]+ny*k)
    return [('C', c1, c2, b)]

def ops_to_d(ops, nd=2):
    f = lambda v: ('%.*f' % (nd, v)).rstrip('0').rstrip('.')
    out = []
    for op in ops:
        if op[0]=='M': out.append('M%s,%s' % (f(op[1][0]), f(op[1][1])))
        elif op[0]=='L': out.append('L%s,%s' % (f(op[1][0]), f(op[1][1])))
        elif op[0]=='C': out.append('C%s,%s %s,%s %s,%s' % (f(op[1][0]),f(op[1][1]),f(op[2][0]),f(op[2][1]),f(op[3][0]),f(op[3][1])))
        elif op[0]=='Q': out.append('Q%s,%s %s,%s' % (f(op[1][0]),f(op[1][1]),f(op[2][0]),f(op[2][1])))
        elif op[0]=='Z': out.append('Z')
    return ''.join(out)

# ---------------- original path data ----------------
D = {
 'mega': "M7.8,192.53c-4.62-.73-7.17,2.88-7.8,7.52l16.65.62c.23-1.3.19-2.84.34-4.15 1.15-10.23,2.3-20.47,3.44-30.7.22-1.97.45-3.97,1.25-5.78.8-1.81,2.27-3.44,4.18-3.92,3.01-.76,6.09,1.46,7.65,4.15,2.87,4.96.84,26.77,1.95,32.13-2.19-1.13-5.06-.76-6.88.9-1.82,1.66-2.14,5.17-1.21,7.46h17.4c1.05-14.45.69-26.82,1.74-41.27,20.14,10.94,56.04,12.2,81.69-1.44.02,12.09-.92,23.62.84,35.58.06-.21-.25,1.11-.19.9-1.73-1.03-3.43.05-7.19,1.63-1.11.47-2.19,1.09-2.91,2.05-.73.96-2.62,3.28-2.1,4.36.52,1.08,14.89.54,18.46.42,3.03-22.18,4.56-44.57,4.59-66.95.01-10.93-.91-23.16-9.05-30.45-6.1-5.45-14.83-6.71-23.01-6.83-8.98-.13-17.96.81-26.94.68-8.98-.13-18.17-1.42-26.08-5.69-7.91-4.27-14.37-11.93-15.41-20.86-.65-5.61,1.43-12.07,6.58-14.4,6.02-2.71,12.73,1.22,18.61,4.21,15.32,7.8,33.57,9.66,50.15,5.13,10.39-2.84,21.11-9.41,23.27-19.96.76-3.72,1.41-6.77-.3-10.68,0,0-4.78-2.66-6.35-2.93-28.13-4.79-58.22-11.93-86.35-16.72-5.29-.9-11.4-.62-16.52.98-5.13,1.6-8.51,6.18-11.21,10.82-2.78,4.77-2.45,14.58-2.67,20.1-1.89,47.48-4.7,95.62-6.58,143.1Z",
 'farRearLeg': "M94.15,202.97h20.78c1.19-13.36,2.84-32.01,4.03-45.36-3.68.7-6.55,1.15-9.97,2.7-.23,9.03-.47,24.25-1.44,33.23-2.77-.53-5.81.88-8.13,2.48-2.32,1.6-4.79,4.18-5.28,6.96Z",
 'tail': "M117.28,99.74c11.06,1.63,22.59,1.78,32.96-3.4,10.37-5.18,19.38-16.62,20.82-30.69.17-1.65.56-3.76,1.85-3.95.79-.11,1.49.63,2.03,1.38,3.32,4.57,4.85,11.15,4.02,17.29-.83,6.14-4.01,11.69-8.34,14.57,3.13-.4,6.26-.8,9.4-1.2-1.9,6.6-7.62,11.04-13.1,10.15,2.86.51,5.89,2.69,7.88,5.36-6.1,3.09-12.81,4.18-19.32,3.12,2.2-.46,4.21,2.58,4.36,5.42-7.38,3.86-15.92,2.55-23.29-1.32-7.37-3.87-12.94-10.57-19.28-16.72Z",
 'tailDetail': "M140.55,108.3c-3.84,0-7.14-.51-10.03-1.54-.25-.09-.39-.37-.3-.63.09-.25.37-.38.63-.3,3.48,1.24,7.6,1.7,12.6,1.39.97-.06,1.99-.15,2.81-.59.68-.36,1.37-1.14,1.29-2.01-.02-.19-.09-.37-.2-.54-.58-.12-1.14-.29-1.7-.49-.18-.07-.31-.24-.32-.43-.01-.2.1-.38.27-.46.53-.26,1.17-.23,1.74.1.2.11.38.25.53.4,4.81.91,10.14-1.06,13.13-4.96l-3.25.18c-.24,0-.44-.17-.48-.4-.04-.24.1-.48.34-.55,3.63-1.12,6.56-4.23,7.47-7.92.07-.26.34-.42.59-.36.26.06.42.33.36.59-.77,3.14-2.89,5.89-5.66,7.52l1.58-.08c.17-.03.36.08.45.24.09.16.09.35-.01.51-2.9,4.53-8.62,7-13.91,6.32.02.08.03.17.04.26.12,1.32-.82,2.44-1.81,2.96-1,.53-2.14.64-3.21.7-1.02.06-2.01.09-2.96.09Z",
 'eyePatch': "M40.19,40.87c-1.2-5.93,2.83-12.22,8.49-14.35,5.66-2.13,12.35-.41,16.89,3.59,3.79,3.34,6.26,8.74,4.61,13.52-.96,2.8-3.21,5.03-5.79,6.49-5.52,3.13-12.8,2.87-18.08-.65-3.01-2-5.4-5.07-6.11-8.61Z",
 'nose': "M138.13,34.83c1.71,3.91,1.06,6.95.3,10.68-.43,2.1-1.18,5.24-2.22,7.03-5.61.5-11.5-2.94-15.32-7.12-3.45-3.76-5.2-8.92-5.09-14.02,4.96.84,9.91,1.69,14.87,2.53,1.57.27,7.46.91,7.46.91Z",
 'smile': "M118.4,63.51s-.14.11-.37.29c-.12.09-.27.19-.45.31-.15.13-.36.26-.73.31-.35.07-.72.15-1.12.23-.4.1-.87.01-1.35-.01-.49-.05-.98-.05-1.53-.24-.54-.16-1.09-.32-1.64-.48-.77-.39-.99-.53-1.51-.81-.42-.19-.95-.61-1.42-.96-.46-.36-.97-.71-1.25-1.08-.31-.36-.6-.7-.87-1.02-.58-.61-.7-1.21-.94-1.57-.18-.38-.27-.59-.27-.59-.12-.29.06-.52.4-.49.25.02.52.16.69.36,0,0,.26.3.52.6.28.29.5.73,1.03,1.16.24.22.5.46.77.72.26.28.6.4.88.65.31.22.53.46,1.04.68l1.21.62,1.17.39c.39.18.76.18,1.13.24.34.02.77.18,1.04.14.3,0,.59,0,.85,0,.56.07,1.04-.2,1.37-.23.34-.07.54-.11.54-.11.26-.05.62.11.81.37.14.2.13.4,0,.5Z",
 'blush': "M32.84,51.44c0,1.94,2.11,3.52,4.72,3.52s4.72-1.58,4.72-3.52-2.11-3.52-4.72-3.52-4.72,1.57-4.72,3.52Z",
 'earSmallDetail': "M44.17,3.4c-1.91,4.39-3.3,9.02-4.11,13.74,1.63.04,3.26.08,4.89.12-.35-3.67,2.59-7.35,6.24-7.82-3.22-.47-6.07-2.92-7.03-6.04Z",
 'spotChest': "M33.05,102.02c2.64-2.11,4.72-5.6,8.09-5.68,2.77-.07,4.93,2.26,6.69,4.4,1.2,1.46,2.42,2.94,3.18,4.67.77,1.73,1.04,3.76.31,5.5-.58,1.38-1.71,2.44-2.81,3.46-3.86,3.56-8.17,7.32-13.41,7.6-3.93.21-7.91-1.77-10.1-5.04-1.65-2.47-2.25-5.83-.79-8.42,1.81-3.22,5.95-4.19,8.84-6.49Z",
 'spotRearThigh': "M131.32,139.78c.57-5.14,3.97-9.35,8.05-12.71.25,3,.32,6.02.32,8.95,0,6.2-.14,12.39-.38,18.58-.25-.15-.5-.3-.74-.46-4.71-3.1-7.86-8.75-7.25-14.36Z",
 'spotChestLow': "M14.3,142.54c-1.39.45-2.84.59-4.28.48.53-10.94,1.07-21.89,1.6-32.84,5.17,4.27,8.89,10.3,10.16,16.89.54,2.81.65,5.78-.3,8.48-1.15,3.27-3.89,5.93-7.19,6.99Z",
 'spotSaddle': "M60.35,98.41c.04-.69.14-1.38.25-2.07,6.38,2.21,13.29,2.97,20.08,3.08,8.98.13,17.96-.81,26.94-.68,3.18.05,6.45.27,9.61.84-2.7,8.07-7.97,15.34-15.22,19.77-8.15,4.99-18.8,6.08-27.46,2.03-8.66-4.05-14.8-13.43-14.21-22.97Z",
 'earSmall': "M42.09,8.53c-.18-.51,1.36-4.36,2.97-6.06,1.01-1.07,1.57-2.31,3.04-2.46,1.35-.13,2.61.61,3.75,1.33,4.72,2.95,9.63,6.1,12.31,10.98-6.1,1.02-12.44.59-18.34-1.24-1.49-.46-3.23-1.08-3.73-2.55Z",
 'noseShine': "M126.35,35.02c-.6-.08-1.28-.12-1.72.29-.48.45-.41,1.27-.03,1.79.39.53,1.01.82,1.62,1.06,2.57,1,5.4,1.34,8.14.96.65-.09,1.31-.23,1.85-.61.53-.38.02-1.29-.15-1.92-3.5-.75-6.16-1.13-9.71-1.58Z",
 'earFloppyInner': "M16.65,22.73c6.26.2,12.52,3.27,15.31,8.88,1.69.36,3.5-.54,3.53-2.26.08-4.37-1.31-8.75-3.89-12.27-5.02.35-11.1,2.41-14.95,5.65Z",
 'earFloppy': "M33.75,20.17c-5.51-.08-11.02,1.28-15.21,4.99-2.33,2.07-4.29,4.64-6.96,6.2-1.05.62-2.3,1.07-3.44.67-1.62-.56-2.32-2.5-2.81-4.2-1.18-4.09-2.38-8.24-2.39-12.51-.02-4.26,1.3-8.73,4.41-11.48,10.21,1.64,20.29,6.95,26.41,16.32Z",
 'earTuft': "M49.42,21.14c2.43-.83,5.02-1.14,7.58-.95-1.64,1.31-3.47,2.39-5.41,3.2-.74.31-1.56.58-2.33.35-.77-.22-1.37-1.15-.98-1.85.23-.4.7-.6,1.14-.75Z",
 'neckShade': "M51.72,56.74c11.72.51,21.99,7.69,33.2,11.17,4.37,1.36,8.92,2.15,13.5,2.36-11.76.37-23.63-2.18-34.13-7.52-5.89-2.99-12.59-6.93-18.61-4.21-4.21,1.9-6.37,6.57-6.66,11.27-.09-.5-.17-1-.21-1.5-.25-2.7.24-5.56,1.91-7.69,2.49-3.19,6.96-4.06,11-3.88Z",
 'bodyShade': "M47.25,159.52c16.11,1.45,32.32,2.79,48.46,1.59,15.2-1.13,30.44-4.61,43.77-11.94-.5,17.99-1.95,35.96-4.38,53.79-3.57.13-17.94.67-18.46-.42-.52-1.08,1.37-3.41,2.1-4.36.73-.96,1.81-1.58,2.91-2.05,3.76-1.58,5.46-2.65,7.19-1.63.02-.14.24-1.08.19-.9-1.76-11.96-.83-23.49-.84-35.58-25.1,13.36-60.02,12.43-80.38,2.12-.18-.21-.38-.41-.56-.62Z",
 'eyeWhite': "M64.51,38.3c0,4.6-3.1,8.34-6.93,8.34s-6.93-3.73-6.93-8.34,3.1-8.34,6.93-8.34,6.93,3.73,6.93,8.34Z",
 'pupil': "M63.92,36.86c0,2.59-1.68,4.68-3.76,4.68s-3.76-2.1-3.76-4.68,1.68-4.68,3.76-4.68,3.76,2.1,3.76,4.68Z",
}
COLORS = {'c1':'#602724','c2':'#c1ad9b','c3':'#e9cfb9','c4':'#722c1b','c5':'#b65d2d','c6':'#8b3a22','c7':'#ffffff','c10':'#f1ac97'}

mega = parse(D['mega'])
# mega segs with start points
def with_starts(ops):
    segs = []; cur = None
    for op in ops:
        if op[0]=='M': cur = op[1]
        elif op[0]=='C': segs.append(('C', cur, op[1], op[2], op[3])); cur = op[3]
        elif op[0]=='L': segs.append(('L', cur, op[3-2] if False else op[1])); cur = op[1]
        elif op[0]=='Z': segs.append(('Z',))
    return segs
MS = with_starts(mega)   # MS[i] corresponds to node i (i>=1); MS[0] is seg ending at node1

def seg(i):
    """cubic seg ending at parse-node i: returns (p0,c1,c2,p1)"""
    s = MS[i-1]
    assert s[0]=='C', (i, s[0])
    return (s[1], s[2], s[3], s[4])

def seg_line(i):
    s = MS[i-1]; assert s[0]=='L'; return (s[1], s[2])

def sub(i, t0=0.0, t1=1.0):
    p0,c1,c2,p1 = seg(i)
    q = cubic_split(p0,c1,c2,p1,t0,t1)
    return q  # (p0,c1,c2,p1) of portion

def t_at_y(i, y):
    p0,c1,c2,p1 = seg(i)
    return cubic_t_for_y(p0,c1,c2,p1,y)

def pt(i, t):
    return cubic_point(*seg(i), t)

# ---------------- joint constants ----------------
J = {
 'neck':      (30.0, 74.0),
 'earFloppy': (31.0, 15.0),
 'earSmall':  (46.5, 11.5),
 'tail':      (121.0, 101.5),
 'hipFF':     (15.0, 150.0),  'kneeFF_y': 178.0,
 'hipNF':     (40.0, 150.0),  'kneeNF_y': 180.0,
 'hipNR':     (133.5, 142.0), 'kneeNR_y': 183.0,
 'hipFR':     (113.0, 158.0), 'kneeFR_y': 184.0,
 'eye':       (57.58, 38.30),
}

PARTS = []  # (name, ops, fill, opacity, group)
def add(name, ops, fill, opacity=1.0):
    PARTS.append((name, ops, fill, opacity))

C = lambda q: ('C', q[1], q[2], q[3])

# ---------- TAIL ----------
add('tail', parse(D['tail']), COLORS['c5'])
add('tailDetail', parse(D['tailDetail']), COLORS['c4'])

# ---------- FAR REAR LEG (from cls-2 path) ----------
FR = parse(D['farRearLeg'])
FRS = with_starts(FR)
# segs: 0:L (94.15,202.97)->(114.93,202.97); 1:C ->(118.96,157.61); 2:C ->(108.99,160.31);
# 3:C ->(108.76? ...) let's recompute via with_starts
# back edge = FRS[1]: (114.93,202.97)->(118.96,157.61); front edge = FRS[3]: (108.99,160.31)->? 
def fr_seg(i):
    s = FRS[i]; return (s[1], s[2], s[3], s[4])
backE = fr_seg(1)   # paw->top (going up)
frontE = fr_seg(3)  # top->down (going down)
kFRy = J['kneeFR_y']
tb = cubic_t_for_y(*backE, kFRy)     # on back edge (y decreasing)
tf = cubic_t_for_y(*frontE, kFRy)    # on front edge (y increasing)
hipFR = J['hipFR']
tb_hip = cubic_t_for_y(*backE, hipFR[1])
tf_hip = cubic_t_for_y(*frontE, hipFR[1])
# thigh: front edge from hipY down to kneeY, knee cap, back edge kneeY up to hipY, hip cap
q_f = cubic_split(*frontE, tf_hip, tf)
q_b = cubic_split(*backE, tb, tb_hip)
thighFR = [('M', q_f[0]), C(q_f)] + semicircle(q_f[3], q_b[0], (113.0, kFRy+20)) + [C(q_b)] + semicircle(q_b[3], q_f[0], (hipFR[0], hipFR[1]-20)) + [('Z',)]
# shank: front edge kneeY->bottom, paw bottoms, back edge bottom->kneeY, knee cap
q_f2 = cubic_split(*frontE, tf, 1.0)
q_b2 = cubic_split(*backE, 0.0, tb)
shankFR = [('M', q_f2[0]), C(q_f2)]
for s in FRS[4:]:
    if s[0]=='C': shankFR.append(('C', s[2], s[3], s[4]))
    elif s[0]=='L': shankFR.append(('L', s[2]))
# now at (94.14,202.98) ~= path start (94.15,202.97); paw bottom line:
shankFR += [('L', (94.15,202.97)), ('L', (114.93,202.97)), C(q_b2)] + semicircle(q_b2[3], q_f2[0], (113.0, kFRy-20)) + [('Z',)]
add('farRearThigh', thighFR, COLORS['c2'])
add('farRearShank', shankFR, COLORS['c2'])

# ---------- FAR FRONT LEG (mega nodes 36-tail + 1..5) ----------
kFFy = J['kneeFF_y']
t36k = t_at_y(36, kFFy); t36top = t_at_y(36, 142.0)
t4k = t_at_y(4, kFFy)   # seg4: (16.99,196.52)->(20.43,165.82) going up
q_front_th = sub(36, t36top, t36k)          # front edge, downward, thigh part
q_front_sh = sub(36, t36k, 1.0)             # front edge, downward, shank part (ends 7.84,192.54)
q_in_sh = sub(4, 0.0, t4k)                  # inner edge upward from paw to knee
q_in_th = sub(4, t4k, 1.0)                  # inner edge knee->165.82
thighFF = [('M', q_front_th[0]), C(q_front_th)] + semicircle(q_front_th[3], q_in_th[0], (14.0, kFFy+20)) + \
          [C(q_in_th), C(sub(5,0,1))] + [('L',(20.0,150.0))] + semicircle((20.0,150.0), q_front_th[0], (J['hipFF'][0], J['hipFF'][1]-20)) + [('Z',)]
shankFF = [('M', q_front_sh[0]), C(q_front_sh), C(sub(1,0,1)), ('L', seg_line(2)[1]), C(sub(3,0,1)), C(q_in_sh)] + \
          semicircle(q_in_sh[3], q_front_sh[0], (14.0, kFFy-20)) + [('Z',)]
add('farFrontThigh', thighFF, COLORS['c3'])
add('farFrontShank', shankFF, COLORS['c3'])

# ---------- BODY ----------
t36neck = t_at_y(36, 58.0)
t36chest = t_at_y(36, 149.0)
q_chest = sub(36, t36neck, t36chest)  # downward front edge portion
body = [('M', (39.21,72.89))]
body += rev([('M', seg(25)[0]), C(sub(25,0,1))])[1:]          # neck back reversed: ->(54.62,93.75)
body += rev([('M', seg(24)[0]), C(sub(24,0,1))])[1:]          # ->(80.70,99.44)
body += rev([('M', seg(23)[0]), C(sub(23,0,1))])[1:]          # ->(107.64,98.76)
body += rev([('M', seg(22)[0]), C(sub(22,0,1))])[1:]          # ->(130.65,105.59)
body += rev([('M', seg(21)[0]), C(sub(21,0,1))])[1:]          # rump ->(139.70,136.04)
body += [('Q', (142.5,152.0), (128.20,158.05))]               # hidden hip bulge under near-rear leg
body += rev([('M', seg(13)[0]), C(sub(13,0,1))])[1:]          # belly reversed ->(46.51,159.49)
body += [('L', (33.51,160.27))]
body += rev([('M', seg(7)[0]), C(sub(7,0,1))])[1:]            # crotch ->(25.86,156.12)
body += rev([('M', seg(6)[0]), C(sub(6,0,1))])[1:]            # ->(21.68,160.04)
body += [('Q', (13.0,156.0), q_chest[3])]                     # over far-front-leg top to chest edge
body += rev([('M', q_chest[0]), C(q_chest)])[1:]              # chest edge upward ->(~13,58)
body += [('L', (39.21,72.89)), ('Z',)]
add('body', body, COLORS['c3'])
add('spotSaddle', parse(D['spotSaddle']), COLORS['c5'])
add('spotChest', parse(D['spotChest']), COLORS['c5'])
add('spotChestLow', parse(D['spotChestLow']), COLORS['c5'])

# body shade: original cls-8 with the rear-leg descent replaced by a short closure along the belly
BS = parse(D['bodyShade']); BSS = with_starts(BS)
def bs_seg(i):
    s = BSS[i]; return (s[1], s[2], s[3], s[4])
# BSS[0]: (47.25,159.52)->(95.71,161.11); BSS[1]: ->(139.48,149.17)  (top curve to hip)
# then descent to paw ... then "-.84-35.58" etc; keep: top curve, then close down to belly line near (128,158)
bshade = [('M',(47.25,159.52)), C(bs_seg(0)), C(bs_seg(1))]
# find the return curve along belly: segment '-25.1,13.36-60.02,12.43-80.38,2.12' start (128.02? ...)
# we rebuild closure: from (139.48,149.17) quad to belly end (128.20,158.05) then follow belly reversed to (46.51,159.49)
bshade += [('Q', (140.0,156.0), (128.20,158.05))]
bshade += rev([('M', seg(13)[0]), C(sub(13,0,1))])[1:]
bshade += [('Z',)]
add('bodyShade', bshade, COLORS['c6'], 0.22)

# ---------- NEAR REAR LEG (mega nodes 14..20) ----------
kNRy = J['kneeNR_y']; hipNR = J['hipNR']
t14k = t_at_y(14, kNRy); t14hip = t_at_y(14, hipNR[1]+8)  # front edge starts at y158 anyway
t20k = t_at_y(20, kNRy)  # back edge (135.11,202.99)->(139.70,136.04) going up
t20hip = t_at_y(20, hipNR[1])
q14_th = sub(14, 0.0, t14k)     # (128.20,158.05) down to knee
q14_sh = sub(14, t14k, 1.0)
q20_sh = sub(20, 0.0, t20k)
q20_th = sub(20, t20k, t20hip)
thighNR = [('M', (127.0,140.0)), ('L', q14_th[0]), C(q14_th)] + semicircle(q14_th[3], q20_th[0], (133.0, kNRy+20)) + \
          [C(q20_th)] + semicircle(q20_th[3], (127.0,140.0), (hipNR[0], hipNR[1]-20)) + [('Z',)]
shankNR = [('M', q14_sh[0]), C(q14_sh)]
for i in range(15,19):
    s = MS[i-1]
    shankNR.append(('C', s[2], s[3], s[4]))
shankNR += [C(sub(19,0,1)), C(q20_sh)] + semicircle(q20_sh[3], q14_sh[0], (133.0, kNRy-20)) + [('Z',)]
add('nearRearThigh', thighNR, COLORS['c3'])
t14s = t_at_y(14, 158.2); t20s = t_at_y(20, 152.0)
q14_shd = sub(14, 0.0, t14k)
q20_shd = sub(20, t20k, t_at_y(20, 152.0))
thighNRshade = [('M', q14_shd[0]), C(q14_shd)] + semicircle(q14_shd[3], q20_shd[0], (133.0, kNRy+20)) + \
               [C(q20_shd), ('L', q14_shd[0]), ('Z',)]
add('nearRearThighShade', thighNRshade, COLORS['c6'], 0.22)
add('spotRearThigh', parse(D['spotRearThigh']), COLORS['c5'])
add('nearRearShank', shankNR, COLORS['c3'])
add('nearRearShankShade', shankNR, COLORS['c6'], 0.22)

# ---------- NEAR FRONT LEG (mega nodes 8..12) ----------
kNFy = J['kneeNF_y']
t8k = t_at_y(8, kNFy)    # (33.51,160.27)->(35.46,192.40) downward
t12k = t_at_y(12, kNFy)  # (44.77,200.76)->(46.51,159.49) upward
q8_th = sub(8, 0.0, t8k); q8_sh = sub(8, t8k, 1.0)
q12_sh = sub(12, 0.0, t12k); q12_th = sub(12, t12k, 1.0)
thighNF = [('M', (33.2,146.0)), ('L', q8_th[0]), C(q8_th)] + semicircle(q8_th[3], q12_th[0], (40.0, kNFy+20)) + \
          [C(q12_th), ('L', (46.3,146.0))] + semicircle((46.3,146.0), (33.2,146.0), (J['hipNF'][0], J['hipNF'][1]-20)) + [('Z',)]
# NOTE: semicircle direction: bulge must point downward for knee caps, upward for hip. verify visually.
shankNF = [('M', q8_sh[0]), C(q8_sh), C(sub(9,0,1)), C(sub(10,0,1)), ('L', seg_line(11)[1]), C(q12_sh)] + \
          semicircle(q12_sh[3], q8_sh[0], (40.0, kNFy-20)) + [('Z',)]
add('nearFrontThigh', thighNF, COLORS['c3'])
add('nearFrontShank', shankNF, COLORS['c3'])

# ---------- HEAD ----------
t36head = t_at_y(36, 76.0)
q_face = sub(36, 0.0, t36head)   # (14.42,49.44) down to (~12.7,76)
head = [('M', (39.21,72.89))]
for i in range(26, 36):
    head.append(C(sub(i,0,1)))
head += [C(q_face), ('L', (39.21,72.89)), ('Z',)]
add('head', head, COLORS['c3'])
add('neckShade', parse(D['neckShade']), COLORS['c6'], 0.26)
add('eyePatch', parse(D['eyePatch']), COLORS['c5'])
add('nose', parse(D['nose']), COLORS['c4'])
add('smile', parse(D['smile']), COLORS['c1'])
add('blush', parse(D['blush']), COLORS['c10'])
add('noseShine', parse(D['noseShine']), COLORS['c7'])
add('earTuft', parse(D['earTuft']), COLORS['c4'])
add('earSmall', parse(D['earSmall']), COLORS['c5'])
add('earSmallDetail', parse(D['earSmallDetail']), COLORS['c6'])
add('earFloppy', parse(D['earFloppy']), COLORS['c5'])
add('earFloppyInner', parse(D['earFloppyInner']), COLORS['c6'])
add('eyeWhite', parse(D['eyeWhite']), COLORS['c7'])
add('pupil', parse(D['pupil']), COLORS['c1'])

# z-order for rendering
ZORDER = ['tail','tailDetail',
          'farRearThigh','farRearShank',
          'farFrontThigh','farFrontShank',
          'body','spotSaddle','spotChest','spotChestLow','bodyShade',
          'nearRearThigh','nearRearThighShade','spotRearThigh','nearRearShank','nearRearShankShade',
          'nearFrontThigh','nearFrontShank',
          'head','neckShade','eyePatch','nose','smile','blush','noseShine',
          'earTuft','earSmall','earSmallDetail','earFloppy','earFloppyInner','eyeWhite','pupil']

PARTMAP = {name:(ops,fill,op) for (name,ops,fill,op) in PARTS}

if __name__ == '__main__':
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180.03 203.21">']
    for name in ZORDER:
        ops, fill, op = PARTMAP[name]
        o = '' if op==1 else ' opacity="%.2f"' % op
        svg.append('  <path id="%s" fill="%s"%s d="%s"/>' % (name, fill, o, ops_to_d(ops)))
    svg.append('</svg>')
    open('decomposed.svg','w').write('\n'.join(svg))
    print('wrote decomposed.svg with', len(ZORDER), 'parts')
