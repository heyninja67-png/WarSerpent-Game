#!/usr/bin/env python3
"""Reproduce only the original eight angular cyber snake sprite sets from e31130e.

The user requested restoring this exact v1.1 artwork in v1.2.1. This generator
never writes branding, studio marks, lobby/UI assets, ability icons or arena tiles."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import math, random, shutil
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'assets'
S=3
palettes=[('#29e5fb','#136d9e','#071f39','#da83ff'),('#ffb238','#a83323','#361421','#fff19a'),('#b4f5ff','#3c87bd','#162e57','#ffffff'),('#a8ff62','#426c75','#142632','#f2fbff'),('#ce7bff','#5934a2','#21173d','#92ffff')]
def col(h,a=255):
 h=h.lstrip('#');return tuple(int(h[i:i+2],16) for i in(0,2,4))+(a,)
def canvas(w,h):
 im=Image.new('RGBA',(w*S,h*S));return im,ImageDraw.Draw(im)
def p(points):return [(int(x*S),int(y*S)) for x,y in points]
def poly(d,points,fill,outline=None):d.polygon(p(points),fill=fill); d.line(p(points+[points[0]]),fill=outline,width=S) if outline else None
def line(d,points,fill,width=1):d.line(p(points),fill=fill,width=int(width*S),joint='curve')
def ell(d,b,fill,outline=None,width=1):d.ellipse(tuple(int(x*S) for x in b),fill=fill,outline=outline,width=int(width*S))
def rect(d,b,fill,outline=None,width=1):d.rounded_rectangle(tuple(int(x*S) for x in b),radius=5*S,fill=fill,outline=outline,width=int(width*S))
def save(im,path):
 relative=Path(path)
 if relative.parent != Path('snakes') or relative.suffix != '.png':
  raise ValueError('Classic generator is restricted to assets/snakes/*.png')
 path=A/relative
 path.parent.mkdir(parents=True,exist_ok=True)
 im.resize((im.width//S,im.height//S),Image.Resampling.LANCZOS).save(path)
def glow(im):
 # Glow derives only from our authored sprites.
 base=im.copy();base=base.filter(ImageFilter.GaussianBlur(3*S));base.putalpha(base.getchannel('A').point(lambda a:int(a*.35)));return Image.alpha_composite(base,im)
for k,(bright,mid,dark,accent) in enumerate(palettes):
 b,m,z,a=map(col,(bright,mid,dark,accent))
 im,d=canvas(96,76)
 # Upper side armor: different silhouette for each species.
 if k==0:
  for x in (16,34,52):poly(d,[(x,23),(x+2,9),(x+13,24)],m,b)
 elif k==1:
  poly(d,[(8,28),(0,7),(26,20),(21,0),(45,20),(53,8),(64,26)],m,b)
 elif k==2:
  for x in(12,29,45):poly(d,[(x,24),(x+9,2),(x+18,24)],m,a)
 elif k==3:
  poly(d,[(10,19),(21,11),(61,15),(70,24),(70,53),(19,58),(8,47)],m,b)
 else:
  poly(d,[(8,30),(0,5),(32,22),(54,9),(63,25),(28,50),(2,70),(12,42)],m,b)
 # Continuous neck and sculpted muzzle.
 poly(d,[(8,25),(38,18),(65,23),(80,31),(91,36),(91,46),(77,56),(48,58),(29,54),(8,52)],z,b)
 poly(d,[(13,27),(39,22),(62,27),(79,34),(86,39),(67,42),(46,34),(12,38)],m)
 poly(d,[(13,42),(39,37),(64,44),(86,44),(78,51),(50,54),(23,48)],m)
 line(d,[(29,22),(40,33),(34,43),(41,55)],b,2)
 line(d,[(48,26),(57,34),(52,40)],a,2)
 # Angry expressive eyes and gleaming pupil, facing right.
 poly(d,[(57,29),(72,33),(65,38),(57,37)],(1,4,12,255))
 poly(d,[(59,31),(69,34),(64,36),(59,35)],a)
 ell(d,(65,32,67,36),z)
 ell(d,(78,35,82,38),b)
 line(d,[(70,46),(84,43),(89,44)],(3,6,15,255),2)
 if k==1:poly(d,[(78,47),(79,53),(82,47)],a)
 if k==2:poly(d,[(78,47),(78,56),(82,48)],a)
 if k==3:
  for x in(16,23,30):line(d,[(x,28),(x,34)],a,2)
  ell(d,(17,44,23,50),z,b)
 if k==4:line(d,[(43,26),(45,47),(63,51)],a,1)
 save(glow(im),Path(f'snakes/head_{k}.png'))
 im,d=canvas(64,64)
 ell(d,(0,6,64,58),z,b,1)
 ell(d,(3,8,61,53),m)
 # Repeated overlapping armor makes body appear continuous at 18px spacing.
 if k==0:
  for x in(-5,16,37):
   poly(d,[(x,12),(x+23,8),(x+15,30),(x+23,54),(x,51),(x+8,31)],z,b)
   line(d,[(x+9,18),(x+16,26),(x+11,32),(x+18,42)],a,1)
 elif k==1:
  for x in(0,20,40):poly(d,[(x,10),(x+22,14),(x+15,31),(x+25,48),(x+2,54),(x+8,32)],z,b)
  line(d,[(0,32),(13,26),(24,35),(33,26),(47,33),(64,25)],a,2)
 elif k==2:
  for x in(-3,18,39):poly(d,[(x,32),(x+12,8),(x+29,32),(x+12,55)],m,b);line(d,[(x+12,8),(x+12,55)],a)
 elif k==3:
  for x in(2,24,46):
   rect(d,(x,10,x+18,53),z,b)
   line(d,[(x+5,16),(x+13,16)],a,2);ell(d,(x+6,26,x+12,33),b)
 else:
  for x in(-5,16,37):poly(d,[(x,32),(x+25,8),(x+17,31),(x+25,56)],z,b)
  line(d,[(0,33),(12,24),(25,35),(39,25),(52,36),(64,27)],a,2)
 line(d,[(5,49),(58,49)],b,1)
 save(glow(im),Path(f'snakes/body_{k}.png'))
 im,d=canvas(96,64)
 poly(d,[(94,9),(94,55),(62,50),(30,40),(3,32),(29,28),(59,15)],z,b)
 poly(d,[(94,17),(94,29),(39,33),(18,32),(61,25)],m)
 line(d,[(34,33),(94,35)],a,2)
 for x in(64,78):line(d,[(x,18),(x-7,31),(x,48)],b,1)
 save(glow(im),Path(f'snakes/tail_{k}.png'))
newpalettes=[('#ffd978','#bc6d22','#382819','#fff8dd'),('#f1f5fa','#8a9baa','#202831','#ff5968'),('#bdff47','#56922b','#152a27','#f5ffa2')]
for k,palette in enumerate(newpalettes,5):
 b,m,z,a=map(col,palette)
 im,d=canvas(96,76)
 if k==5:
  # Solar wyrm: a radial sun mane and broad imperial muzzle.
  for i,ang in enumerate(range(105,256,25)):
   theta=math.radians(ang);theta2=math.radians(ang+10)
   p1=(34+22*math.cos(theta),38+22*math.sin(theta))
   p2=(34+37*math.cos(theta2),38+37*math.sin(theta2))
   p3=(34+22*math.cos(theta+.3),38+22*math.sin(theta+.3))
   poly(d,[p1,p2,p3],m,b)
  ell(d,(11,15,56,62),z,b,2)
  ell(d,(17,21,49,56),m,a,1)
  poly(d,[(29,22),(62,20),(78,30),(92,39),(88,50),(61,58),(31,52)],z,b)
  poly(d,[(37,26),(61,24),(76,32),(63,36),(44,33)],m)
  poly(d,[(35,42),(57,38),(83,43),(74,52),(48,51)],m)
  poly(d,[(58,30),(75,33),(65,39),(58,37)],a)
  line(d,[(70,46),(87,43)],col('#552e1b'),2)
  poly(d,[(42,22),(49,9),(56,23)],b,a)
  line(d,[(25,26),(30,34),(25,43),(32,51)],a,2)
 elif k==6:
  # Samurai: swept kabuto helmet, white ceramic face, red lacquer jaw.
  poly(d,[(6,28),(18,10),(42,7),(64,19),(78,28),(70,39),(16,48)],z,b)
  poly(d,[(15,23),(4,2),(31,14),(42,0),(48,18),(66,7),(65,28)],m,b)
  poly(d,[(16,27),(43,19),(68,30),(63,42),(21,46)],b)
  poly(d,[(27,42),(65,31),(90,37),(94,45),(80,55),(51,60),(20,54)],z,m)
  poly(d,[(34,44),(65,37),(82,40),(76,46),(53,51)],b)
  poly(d,[(23,52),(57,53),(78,48),(84,56),(58,65),(28,61)],a)
  poly(d,[(59,32),(73,35),(64,40),(57,39)],a)
  line(d,[(25,29),(36,29)],a,3)
  line(d,[(27,35),(40,35)],col('#111923'),2)
  ell(d,(13,43,23,53),col('#232c39'),a,2)
  line(d,[(48,56),(63,55),(73,51)],col('#fff3f3'),1)
 else:
  # Venomous cobra: a real broad bioluminescent hood and narrow fanged jaw.
  poly(d,[(13,6),(37,9),(53,23),(56,52),(35,70),(8,64),(1,39)],z,b)
  poly(d,[(16,15),(29,15),(42,29),(40,54),(24,62),(10,52),(7,34)],m)
  ell(d,(14,24,32,49),z,b,2)
  ell(d,(19,29,27,43),a)
  poly(d,[(31,28),(54,23),(72,29),(91,38),(89,47),(78,52),(51,53),(32,47)],z,b)
  poly(d,[(34,29),(55,26),(72,32),(78,37),(55,36),(44,40)],m)
  poly(d,[(45,43),(59,39),(78,42),(84,46),(63,49)],m)
  poly(d,[(58,30),(73,33),(65,39),(58,37)],a)
  line(d,[(67,45),(83,43)],col('#050e0a'),2)
  poly(d,[(74,46),(76,57),(80,46)],a)
  poly(d,[(84,49),(88,53),(86,58),(82,55)],b)
  for x,y in((40,31),(48,45),(55,29)):ell(d,(x,y,x+2,y+2),a)
 save(glow(im),Path(f'snakes/head_{k}.png'))
 im,d=canvas(64,64)
 if k==5:
  ell(d,(0,7,64,57),z,b,2)
  for x in(-4,18,40):
   poly(d,[(x,31),(x+15,9),(x+29,31),(x+15,55)],m,b)
   poly(d,[(x+10,24),(x+15,14),(x+20,24),(x+17,33)],a)
  line(d,[(0,33),(64,33)],col('#ed9d36'),2)
 elif k==6:
  ell(d,(0,8,64,56),z,m)
  for x in(-8,15,38):
   poly(d,[(x,14),(x+23,10),(x+30,27),(x+23,52),(x,49),(x+6,31)],b,m)
   poly(d,[(x+4,20),(x+21,17),(x+24,25),(x+8,28)],col('#ffffff'))
   line(d,[(x+7,35),(x+22,34)],a,3)
   line(d,[(x+9,42),(x+20,41)],z,2)
  line(d,[(0,30),(64,30)],z,2)
 else:
  ell(d,(0,5,64,59),z,b)
  for x in(-5,17,39):
   for y in(17,41):poly(d,[(x,y),(x+11,y-9),(x+23,y),(x+11,y+11)],m,b)
  for x in(10,32,54):
   ell(d,(x-4,26,x+4,36),z,a)
   ell(d,(x-1,29,x+1,32),a)
 save(glow(im),Path(f'snakes/body_{k}.png'))
 im,d=canvas(96,64)
 if k==5:
  poly(d,[(94,9),(94,55),(57,49),(21,38),(3,32),(29,22),(57,16)],z,b)
  for x in(29,48,69):poly(d,[(x,31),(x+17,18),(x+20,43)],m,b)
  poly(d,[(16,29),(37,20),(28,33),(37,44)],a)
 elif k==6:
  poly(d,[(94,8),(94,56),(57,49),(9,32),(58,15)],z,m)
  poly(d,[(89,13),(89,29),(38,31),(62,19)],b)
  poly(d,[(89,34),(89,50),(62,43),(38,33)],a)
  for x in(57,73):line(d,[(x,20),(x-5,32),(x,45)],m,2)
 else:
  poly(d,[(94,8),(94,56),(63,49),(29,41),(3,32),(29,24),(64,15)],z,b)
  poly(d,[(94,16),(94,29),(21,32),(62,23)],m)
  for x in(36,54,72):ell(d,(x,28,x+6,36),a)
 save(glow(im),Path(f'snakes/tail_{k}.png'))

print('Restored original angular cyber snake sprites: 24 PNGs / 8 species, v1.1 artwork.')
