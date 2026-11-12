# Re-set the three practice cards across German screenshots 3+4 in German (app wording, app font).
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np
S3,S4,O3,O4=sys.argv[1:5]
FONT='/Users/arthur/Desktop/wingman-app/Wingman/Fonts/Manrope-Medium.ttf'
TITLE=ImageFont.truetype(FONT,77); LESS=ImageFont.truetype(FONT,51); BODY=ImageFont.truetype(FONT,60)
SEAM=1284
W=955           # card text width (from the English wrapping)
X0=669          # text left edge
a=Image.open(S3).convert('RGB'); b=Image.open(S4).convert('RGB')
pano=Image.new('RGB',(2568,2778)); pano.paste(a,(0,0)); pano.paste(b,(1284,0))
P=np.array(pano)
d=ImageDraw.Draw(pano)

cards=[  # title row top, lessons row top, first summary line top(lt), colours, texts
 dict(t=79,  l=189, s=300, ct=(26,26,26), cl=(95,95,95), cs=(72,72,72),
      title='Kaffee und Regen', less='2 Lektionen',
      summary='Mieses Wetter, warmer Kaffee, ein Tisch für zwei. Aus einem einfachen Moment wird eine Chance.',
      erase=[(650,62,1680,170),(712,180,1680,258),(650,290,1680,540)]),
 dict(t=811, l=930, s=1032, ct=(26,26,26), cl=(95,95,95), cs=(72,72,72),
      title='Hund & Flirt', less='3 Lektionen',
      summary='Lachen, Blickkontakt und zwei Hunde, die sich jagen. Hier kommt es aufs Timing an.',
      erase=[(650,795,1680,885),(712,920,1680,998),(650,1022,1680,1272)]),
 dict(t=1539, l=1649, s=1760, ct=(186,186,186), cl=(186,186,186), cs=(186,186,186),
      title='Zwischen den Zeilen', less='5 Lektionen erforderlich',
      summary='Bücher, Stille und ein Grund zu reden. Führ behutsam und lass das Interesse wachsen.',
      erase=[(650,1525,1680,1612),(712,1638,1680,1718),(650,1750,1680,1990)]),
]
def bgcolor(box):
    x0,y0,x1,y1=box; reg=P[y0:y1,x0:x1].reshape(-1,3)
    v,c=np.unique(reg,axis=0,return_counts=True); return tuple(int(t) for t in v[c.argmax()])

def wrap(text,font,limit=3):
    words=text.split(); lines=[]; cur=''
    for w in words:
        c=(cur+' '+w).strip()
        if font.getlength(c)<=W: cur=c
        else: lines.append(cur); cur=w
    lines.append(cur)
    if len(lines)>limit:   # SwiftUI .lineLimit(3): tail truncation with an ellipsis
        rest=' '.join(lines[limit-1:]); s=rest
        while font.getlength(s.rstrip()+'…')>W: s=s[:-1]
        lines=lines[:limit-1]+[s.rstrip()+'…']
    return lines

def draw_line(y_lt_ref,text,font,fill,ref_text,x0=None,base=None):
    """Screens 3 and 4 form one panorama. Draw the line at the app's spacing on a common baseline;
    if a letter would be cut by the seam, move it just past the seam and spread that shift as
    1-3 px of extra tracking over the letters before it, so every letter stays whole."""
    x0=X0 if x0 is None else x0
    if base is None: base=y_lt_ref - font.getbbox(ref_text,anchor='ls')[1]
    pos=[x0+font.getlength(text[:i]) for i in range(len(text))]
    k=None
    for i,ch in enumerate(text):
        if ch==' ': continue
        l,_,r,_=font.getbbox(ch,anchor='ls')
        if pos[i]+l < SEAM+3 and pos[i]+r > SEAM-3: k=i; break
    shift=[0.0]*len(text)
    if k is not None:
        def ink(i): return font.getbbox(text[i],anchor='ls')
        def nxt(i):
            j=i
            while j<len(text) and text[j]==' ': j+=1
            return j
        # option A: letter k goes right of the seam (letters before it track out)
        pushA=SEAM+4-(pos[k]+ink(k)[0])
        # option B: letter k stays left (letters up to k track in), the next letter goes right
        pullB=(SEAM-4)-(pos[k]+ink(k)[2])            # negative
        j=nxt(k+1)
        pushB=max(0.0, SEAM+4-(pos[j]+ink(j)[0])) if j<len(text) else 0.0
        costA=abs(pushA); costB=abs(pullB)+pushB
        if costB<costA and k>0:
            for i in range(len(text)):
                shift[i]=pullB*i/k if i<=k else pushB
            nudges.append((text,'keep '+text[k]+' left',round(pullB,1),round(pushB,1)))
        else:
            for i in range(len(text)): shift[i]=pushA*i/k if i<k else pushA
            nudges.append((text,'move '+text[k]+' right',round(pushA,1)))
    for i,ch in enumerate(text):
        if ch!=' ': d.text((pos[i]+shift[i],base),ch,font=font,fill=fill,anchor='ls')
nudges=[]

for c in cards:
    for box in c['erase']:
        col=bgcolor(box); d.rectangle(box,fill=col)
    draw_line(c['t'],c['title'],TITLE,c['ct'],'Fetch & Flirt')
    # lessons label: same top as the old one
    lb=c['l']-LESS.getbbox('3 L',anchor='ls')[1]
    draw_line(0,c['less'],LESS,c['cl'],'',x0=722,base=lb)
    for i,line in enumerate(wrap(c['summary'],BODY)):
        draw_line(c['s']+82*i,line,BODY,c['cs'],'something playful.')
        print(c['title'],'|',line)
print('line right edges',nudges)
pano.crop((0,0,1284,2778)).save(O3); pano.crop((1284,0,2568,2778)).save(O4)
