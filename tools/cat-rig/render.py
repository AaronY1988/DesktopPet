import importlib.util, cairosvg
from PIL import Image
spec = importlib.util.spec_from_file_location('cp','catposes.py')
cp = importlib.util.module_from_spec(spec); spec.loader.exec_module(cp)
order=['groom','loaf','sitFront','sitBack','walk','lieSide']
tiles=[]
for k in order:
    svg=cp.pose_svg(cp.POSES[k]())
    open('p_%s.svg'%k,'w').write(svg)
    cairosvg.svg2png(url='p_%s.svg'%k, write_to='p_%s.png'%k, output_width=330, background_color='#f4f4f4')
    tiles.append(Image.open('p_%s.png'%k).convert('RGBA'))
w,h=tiles[0].size
g=Image.new('RGBA',(w*3,h*2),(244,244,244,255))
for i,t in enumerate(tiles): g.paste(t,((i%3)*w,(i//3)*h),t)
g.save('../cat_grid.png'); print('ok')
