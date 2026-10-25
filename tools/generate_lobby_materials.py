#!/usr/bin/env python3
"""Original Emnio v1.2 UI materials and purple block arena. CC0-1.0.
Requires Pillow. Rebuild after generate_assets.py (it writes legacy neon_city.png).
All artwork is authored here; no copied game assets, fonts or external images.
"""
from pathlib import Path
import math, random
from PIL import Image,ImageDraw,ImageFilter
ROOT=Path(__file__).resolve().parents[1]/'assets'
R=random.Random(130867)

def gradient(size,top,bottom):
    im=Image.new('RGBA',size)
    px=im.load()
    for y in range(size[1]):
        t=y/max(1,size[1]-1)
        col=tuple(round(a+(b-a)*t) for a,b in zip(top,bottom))
        for x in range(size[0]): px[x,y]=col
    return im

def button(state):
    s=2; w,h=512*s,128*s
    scale=lambda p:[(int(x*s),int(y*s)) for x,y in p]
    poly=scale([(22,10),(499,10),(489,108),(470,120),(9,120),(9,29)])
    mask=Image.new('L',(w,h)); md=ImageDraw.Draw(mask); md.polygon(poly,fill=255)
    if state=='hover': top,bottom=(255,223,117,255),(213,139,24,255)
    elif state=='pressed': top,bottom=(195,132,27,255),(236,182,65,255)
    else: top,bottom=(248,207,94,255),(194,121,22,255)
    body=gradient((w,h),top,bottom)
    # A restrained brushed metal grain makes the fill tactile at phone resolution.
    grain=Image.new('RGBA',(w,h)); gp=grain.load()
    for y in range(h):
        row=R.choice([-2,-1,0,0,1,2])
        for x in range(w):
            n=row+R.choice([-1,0,0,0,1]); gp[x,y]=(255,246,210,max(0,n*2)) if n>=0 else (62,31,9,-n*2)
    body.alpha_composite(grain); body.putalpha(mask)
    out=Image.new('RGBA',(w,h)); shadow=Image.new('RGBA',(w,h)); sd=ImageDraw.Draw(shadow)
    sd.polygon([(x,y+3*s) for x,y in poly],fill=(0,0,0,175)); shadow=shadow.filter(ImageFilter.GaussianBlur(2*s)); out.alpha_composite(shadow); out.alpha_composite(body)
    d=ImageDraw.Draw(out)
    d.line(scale([(22,10),(499,10),(489,108)]),fill=(255,238,170,255),width=2*s)
    d.line(scale([(489,108),(470,120),(9,120),(9,29)]),fill=(83,45,12,255),width=3*s)
    d.line(scale([(25,16),(491,16)]),fill=(255,239,180,180),width=s)
    d.line(scale([(16,110),(468,110),(481,101)]),fill=(255,226,128,110),width=s)
    # Recessed left grip and rightward flank are nonverbal physical design details.
    for x in [25,31,37]: d.line(scale([(x,39),(x,88)]),fill=(100,60,17,130),width=2*s)
    d.polygon(scale([(466,43),(480,64),(462,85),(467,64)]),fill=(99,58,13,180))
    if state=='pressed': out=Image.Image.transform(out,(w,h),Image.Transform.AFFINE,(1,0,0,0,1,-2*s))
    return out.resize((512,128),Image.Resampling.LANCZOS)

def strip():
    w,h=256,720; im=gradient((w,h),(19,25,33,249),(8,12,20,252)); d=ImageDraw.Draw(im)
    for y in range(3,h,4): d.line((3,y,w-7,y),fill=(34,43,56,50))
    d.rectangle((0,0,3,h),fill=(49,61,77,255)); d.rectangle((w-3,0,w-1,h),fill=(3,5,9,255))
    d.line((w-6,7,w-6,h-7),fill=(73,85,100,125),width=1)
    d.polygon([(0,0),(256,0),(256,11),(21,11),(0,30)],fill=(55,63,72,230))
    d.polygon([(0,h-17),(235,h-17),(256,h-35),(256,h),(0,h)],fill=(5,8,13,255))
    d.line((14,58,14,h-65),fill=(105,77,137,85),width=1)
    for y in [29,h-37]:
        for x in [13,w-18]:
            d.ellipse((x-3,y-3,x+3,y+3),fill=(4,7,11),outline=(81,91,106),width=1)
            d.line((x-1,y,x+1,y),fill=(105,115,130),width=1)
    return im

def panel():
    w,h=768,512; im=gradient((w,h),(26,32,43,247),(11,16,25,250)); d=ImageDraw.Draw(im)
    for y in range(2,h,3): d.line((8,y,w-8,y),fill=(60,67,80,18))
    d.polygon([(0,22),(22,0),(w-25,0),(w,25),(w,h-22),(w-22,h),(22,h),(0,h-22)],outline=(77,88,107,255),width=2)
    d.line((22,6,w-30,6,w-7,29),fill=(154,167,188,150),width=1)
    d.line((8,h-29,29,h-8,w-28,h-8),fill=(3,5,10,255),width=3)
    d.line((24,34,88,34),fill=(218,164,63,255),width=3)
    d.line((91,34,123,34),fill=(112,83,44,255),width=3)
    d.line((w-124,h-33,w-25,h-33),fill=(99,69,127,200),width=2)
    return im

def floor():
    # Square lattice of heavy octagonal industrial blocks, explicitly shaded in 2D.
    s=2; size=512; im=Image.new('RGBA',(size*s,size*s),(25,15,40,255)); d=ImageDraw.Draw(im)
    def pg(coords,color): d.polygon([(round(x*s),round(y*s)) for x,y in coords],fill=color)
    def ln(coords,color,width=1): d.line([(round(x*s),round(y*s)) for x,y in coords],fill=color,width=round(width*s))
    for by in range(-1,5):
        for bx in range(-1,5):
            x,y=bx*128,by*128
            # Deterministic 4-block repeat means each tile edge matches the next tile.
            v=((bx%4)*17+(by%4)*23)%9-4
            top=[(x+18,y+8),(x+109,y+8),(x+120,y+19),(x+120,y+101),(x+108,y+113),(x+18,y+113),(x+7,y+102),(x+7,y+19)]
            # Block shadow + deep, visible right and lower side faces.
            pg([(x+13,y+22),(x+124,y+22),(x+124,y+116),(x+112,y+127),(x+19,y+127),(x+4,y+113)],(14,8,24,255))
            pg([(x+7,y+102),(x+18,y+113),(x+108,y+113),(x+120,y+101),(x+120,y+114),(x+108,y+125),(x+18,y+125),(x+7,y+114)],(35+v,20,53+v,255))
            pg([(x+120,y+19),(x+120,y+114),(x+126,y+108),(x+126,y+24)],(30+v,18,46+v,255))
            pg(top,(65+v,39+v,94+v,255))
            # Bright top bevel and darker bottom bevel visibly read as stone/tech blocks.
            pg([(x+18,y+8),(x+109,y+8),(x+120,y+19),(x+113,y+25),(x+104,y+16),(x+22,y+16),(x+14,y+24),(x+7,y+19)],(92+v,61+v,125+v,255))
            pg([(x+7,y+19),(x+14,y+24),(x+14,y+97),(x+22,y+105),(x+18,y+113),(x+7,y+102)],(77+v,47+v,108+v,255))
            pg([(x+22,y+105),(x+104,y+105),(x+113,y+96),(x+113,y+25),(x+120,y+19),(x+120,y+101),(x+108,y+113),(x+18,y+113)],(49+v,27+v,73+v,255))
            ln([(x+19,y+9),(x+108,y+9),(x+118,y+19)],(150,88,173,255),1)
            ln([(x+17,y+111),(x+108,y+111),(x+118,y+101)],(111,58,139,255),1)
            # Small panel seam/circuit inset; no luminous clutter around collectible food.
            ln([(x+28,y+87),(x+28,y+36),(x+37,y+27),(x+79,y+27)],(50+v,29+v,77+v,255),1)
            ln([(x+85,y+97),(x+101,y+97),(x+104,y+94)],(116,67,141,190),1)
            for xx in [25,102]:
                d.ellipse(((x+xx-1)*s,(y+21)*s,(x+xx+1)*s,(y+23)*s),fill=(31,18,46,255))
    im=im.resize((size,size),Image.Resampling.LANCZOS)
    return im

def main():
    (ROOT/'ui').mkdir(parents=True,exist_ok=True); (ROOT/'arenas').mkdir(parents=True,exist_ok=True)
    for state,suffix in [('normal',''),('hover','_hover'),('pressed','_pressed')]:
        im=button(state)
        for stem in ['button_start','start']: im.save(ROOT/'ui'/f'{stem}{suffix}.png',optimize=True)
    strip().save(ROOT/'ui'/'nav_strip.png',optimize=True)
    panel().save(ROOT/'ui'/'lobby_panel.png',optimize=True)
    floor().save(ROOT/'arenas'/'neon_city.png',optimize=True)
    print('Generated nine original UI/arena PNGs. License: CC0-1.0.')
if __name__=='__main__': main()
