# Rebuild the bottom-right text block of German screenshot 1 from its own glyphs.
import sys
from PIL import Image
import numpy as np
from collections import deque
SRC, OUT, SCALE = sys.argv[1], sys.argv[2], float(sys.argv[3])
BG=(26,26,26)
im=Image.open(SRC).convert('RGB')
a=np.array(im).astype(int); L=a.mean(2)

# --- connected components in the italic two-line area (2378..2456, 800..1284)
y0,y1,x0,x1=2376,2458,800,1284
ink=(np.abs(a[y0:y1,x0:x1]-26).max(2)>12)
lab=np.zeros(ink.shape,int); n=0; comps=[]
for y in range(ink.shape[0]):
    for x in range(ink.shape[1]):
        if ink[y,x] and not lab[y,x]:
            n+=1; q=deque([(y,x)]); lab[y,x]=n; pts=[]
            while q:
                cy,cx=q.popleft(); pts.append((cy,cx))
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        ny,nx=cy+dy,cx+dx
                        if 0<=ny<ink.shape[0] and 0<=nx<ink.shape[1] and ink[ny,nx] and not lab[ny,nx]:
                            lab[ny,nx]=n; q.append((ny,nx))
            ys=[p[0] for p in pts]; xs=[p[1] for p in pts]
            comps.append((n,min(ys),max(ys),min(xs),max(xs),len(pts)))
# line A = components whose centre is above 2414-y0, line B below
def centre(c): return (c[1]+c[2])/2
A=[c for c in comps if centre(c) < 2416-y0]
B=[c for c in comps if centre(c) >= 2416-y0]
print('A comps',len(A),'B comps',len(B))
def layer(cs):
    """RGBA image of just these components (bbox-cropped), plus its origin."""
    ids={c[0] for c in cs}
    mask=np.isin(lab,list(ids))
    ys,xs=np.where(mask)
    by0,by1,bx0,bx1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    rgb=a[y0+by0:y0+by1, x0+bx0:x0+bx1].copy()
    m=mask[by0:by1,bx0:bx1]
    alpha=np.where(m,255,0).astype(np.uint8)
    img=Image.fromarray(np.dstack([rgb.astype(np.uint8),alpha]),'RGBA')
    return img,(x0+bx0,y0+by0)
# "[wing-man]" = components of line A to the right of the gap after "Wingman"
Axs=sorted(A,key=lambda c:c[3])
# find the biggest horizontal gap in line A: that's the space before "["
gaps=[]
cur_max=Axs[0][4]
for i in range(1,len(Axs)):
    gaps.append((Axs[i][3]-cur_max,i)); cur_max=max(cur_max,Axs[i][4])
g,idx=max(gaps)
print('space in line A',g,'split at',idx)
bracket_comps=Axs[idx:]
wing_img,wing_org=layer(bracket_comps)
subst_img,subst_org=layer(B)
print('[wing-man] at',wing_org,wing_img.size,' Substantiv at',subst_org,subst_img.size)

# --- body lines (rows have no descenders; bottom = baseline)
def crop(xa,xb,ya,yb): return im.crop((xa,ya,xb+1,yb))
ROW=[(2471,2520),(2548,2597),(2625,2674),(2702,2751)]
Selbstvertra=crop(816,1155,*ROW[0]); uen=crop(817,917,*ROW[1]); trainieren=crop(937,1203,*ROW[1])
dash=crop(818,852,*ROW[2]); im_=crop(875,938,*ROW[2]); echten=crop(959,1153,*ROW[2]); Leben=crop(818,986,*ROW[3])
LETTER=6; SPACE=21
def hcat(parts):
    w=sum(p.size[0] for p,_ in parts)+sum(g for _,g in parts[:-1]); h=parts[0][0].size[1]
    out=Image.new('RGB',(w,h),BG); x=0
    for p,g in parts: out.paste(p,(x,0)); x+=p.size[0]+g
    return out
lines=[hcat([(Selbstvertra,LETTER),(uen,0)]),
       hcat([(trainieren,SPACE),(dash,23),(im_,0)]),
       hcat([(echten,SPACE),(Leben,0)])]
dict_line=Image.new('RGBA',(wing_img.size[0]+16+subst_img.size[0], max(wing_img.size[1],subst_img.size[1])+20),(0,0,0,0))
# baseline-align: bottom of "Substantiv" (no descender) vs bracket bottom (brackets descend) -> align tops of x-height via original line offsets
# original: line A top row 2381 (bracket top), line B top 2421; put Substantiv so its top sits at the same height
# relative to the bracket as "noun" would: use cap-height alignment = align bottoms of 'S' (baseline) with bracket baseline.
# bracket baseline ~ bottom of non-descending letters in [wing-man]: use 'n' bottom => measure
ys=np.where(np.array(wing_img)[:,:,3].any(1))[0]
# baseline of line A: most common bottom among components
bots=sorted(c[2] for c in bracket_comps)
baseA=max(set(bots),key=bots.count)+y0
botsB=sorted(c[2] for c in B); baseB=max(set(botsB),key=botsB.count)+y0
print('baseline A',baseA,'baseline B',baseB)
dl_y_wing=0; dl_y_sub=(baseA-wing_org[1])-(baseB-subst_org[1])
if dl_y_sub<0: dl_y_wing=-dl_y_sub; dl_y_sub=0
dict_line=Image.new('RGBA',(wing_img.size[0]+15+subst_img.size[0], max(dl_y_wing+wing_img.size[1],dl_y_sub+subst_img.size[1])),(0,0,0,0))
dict_line.alpha_composite(wing_img,(0,dl_y_wing)); dict_line.alpha_composite(subst_img,(wing_img.size[0]+15,dl_y_sub))
print('dict line width',dict_line.size, 'body widths',[l.size[0] for l in lines])

# --- erase old block and lay out new one
out=im.copy()
out.paste(BG,(800,2376,1284,2778))
LEFT=816
def sc(img):
    if SCALE==1: return img
    return img.resize((round(img.size[0]*SCALE),round(img.size[1]*SCALE)),Image.LANCZOS)
d=sc(dict_line)
bg=Image.new('RGBA',d.size,BG+(255,)); bg.alpha_composite(d)
out.paste(bg.convert('RGB'),(wing_org[0]-(822-LEFT) if False else 822,2381))
y=2381+d.size[1]+round(48*SCALE)  # gap like original between dict line and body
y=max(y,2471)
pitch=round(77*SCALE)
for l in lines:
    s=sc(l); out.paste(s,(LEFT,y)); print('line right edge',LEFT+s.size[0]); y+=pitch
out.save(OUT)
