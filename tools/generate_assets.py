#!/usr/bin/env python3
"""Reproduce original Emnio vector-like PNG artwork. Does not touch AI menu key art."""
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
 path=A/path;path.parent.mkdir(parents=True,exist_ok=True);im.resize((im.width//S,im.height//S),Image.Resampling.LANCZOS).save(path)
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
# premium logo typeset in licensed DejaVu fonts.
fontpath=A/'fonts/Display.ttf'
def font(size):return ImageFont.truetype(str(fontpath),int(size*S))
def txt(d,xy,t,size,fill,stroke=0):d.text((int(xy[0]*S),int(xy[1]*S)),t,font=font(size),fill=fill,stroke_width=stroke*S,stroke_fill=(2,8,22,255))
im,d=canvas(900,235)
line(d,[(20,30),(96,30),(110,16),(780,16),(803,39),(876,39)],col('#43e4fb'),2)
# serpent emblem at left
poly(d,[(24,79),(52,56),(114,56),(140,77),(121,98),(75,98),(65,112),(124,112),(145,133),(118,161),(49,161),(26,142),(46,125),(67,140),(104,140),(112,132),(56,132),(34,111),(48,91),(106,91),(113,80),(70,80),(54,95)],col('#35dff7'),col('#b5ffff'))
txt(d,(163,42),'WAR SERPENT',78,col('#e8f9ff'),1)
txt(d,(170,135),'NEON CITY  /  ARENA SURVIVAL',22,col('#8dc2d9'))
txt(d,(747,143),'.IO',43,col('#cc83ff'))
line(d,[(166,180),(840,180)],col('#536fa6'),1)
save(glow(im),Path('branding/warserpent.png'))
im,d=canvas(600,240)
poly(d,[(38,50),(163,50),(145,72),(61,72),(80,99),(145,99),(126,120),(67,120),(79,147),(146,147),(166,169),(50,169),(24,109)],col('#ae7aff'),col('#f1c5ff'))
txt(d,(190,56),'EMNIO',68,col('#f1edff'))
txt(d,(195,143),'PLAY BEYOND THE SIGNAL',16,col('#8f9fbd'))
save(glow(im),Path('branding/emnio.png'))
im,d=canvas(512,512)
rect(d,(0,0,512,512),col('#080d23'),col('#30274c'),7)
# graphic letter S serpent monogram in a hex shield
poly(d,[(256,28),(454,140),(454,369),(256,484),(58,369),(58,140)],col('#101d37'),col('#9b63fb'))
poly(d,[(110,185),(165,115),(328,115),(394,167),(354,223),(219,223),(196,257),(338,257),(395,314),(343,390),(160,390),(108,344),(149,295),(194,336),(309,336),(325,315),(165,315),(111,269),(139,215),(304,215),(324,188),(194,171),(170,201)],col('#24d6ed'),col('#bcfaff'))
poly(d,[(315,119),(377,142),(405,172),(368,190),(326,180)],col('#2ae8fb'),col('#a7ffff'))
poly(d,[(357,145),(379,154),(365,165)],col('#d9adff'))
save(glow(im),Path('branding/icon.png'))
# Material UI assets.
for name,colour in [('panel','#263451'),('button','#28dded'),('button_alt','#a972f4'),('card','#4a5e83')]:
 im,d=canvas(360,128)
 poly(d,[(18,2),(342,2),(358,18),(358,110),(342,126),(2,126),(2,18)],col('#0c162d',240),col(colour))
 line(d,[(21,7),(122,7)],col(colour),3)
 line(d,[(238,121),(339,121)],col(colour),3)
 save(im,Path(f'ui/{name}.png'))
for name in('joystick','boost','ability'):
 im,d=canvas(160,160)
 ell(d,(9,9,151,151),col('#0b1636',180),col('#45d5ee',145),2)
 ell(d,(20,20,140,140),None,col('#6583a8',100))
 if name=='joystick':
  ell(d,(52,52,108,108),col('#153450',220),col('#72edff'),2)
  for x,y in((80,29),(80,131),(29,80),(131,80)):ell(d,(x-2,y-2,x+2,y+2),col('#5ddff6'))
 elif name=='boost':
  poly(d,[(42,60),(80,35),(118,60),(80,49)],col('#9aefff'));poly(d,[(42,90),(80,65),(118,90),(80,79)],col('#37d8ff'));poly(d,[(42,120),(80,95),(118,120),(80,109)],col('#8d6fff'))
 else:poly(d,[(91,30),(47,85),(78,85),(64,131),(116,67),(86,67)],col('#c48cff'),col('#e8faff'))
 save(glow(im),Path(f'hud/{name}.png'))
for k in range(5):
 b,m,z,a=map(col,palettes[k]);im,d=canvas(128,128)
 poly(d,[(34,6),(94,6),(122,34),(122,94),(94,122),(34,122),(6,94),(6,34)],z,b)
 if k==0:poly(d,[(74,20),(32,70),(60,70),(48,108),(97,52),(70,52)],b,a)
 elif k==1:
  poly(d,[(65,18),(72,51),(91,36),(105,77),(91,102),(48,108),(23,80),(40,43),(47,70)],b,a)
  poly(d,[(66,54),(48,86),(66,99),(83,84)],col('#fff6bb'))
 elif k==2:
  for ang in range(0,360,60):
   x,y=64+44*math.cos(math.radians(ang)),64+44*math.sin(math.radians(ang));line(d,[(64,64),(x,y)],b,5)
  ell(d,(50,50,78,78),m,a,2)
 elif k==3:
  poly(d,[(64,21),(102,37),(94,82),(64,109),(34,82),(26,37)],m,b)
  poly(d,[(57,36),(74,36),(74,59),(92,59),(92,74),(74,74),(74,92),(57,92),(57,74),(39,74),(39,59),(57,59)],a)
 else:
  ell(d,(28,25,100,99),m,b,2);poly(d,[(64,17),(106,64),(64,111),(80,64)],z,a);ell(d,(44,52,54,65),a);ell(d,(64,52,74,65),a)
 save(glow(im),Path(f'icons/ability_{k}.png'))
for name in('coin','gem','fragment','chest','trophy','energy'):
 im,d=canvas(96,96)
 if name=='coin':
  ell(d,(12,12,84,84),col('#784120'),col('#ffe399'),3);ell(d,(19,19,77,77),col('#eeb850'),col('#fff1b0'),2);txt(d,(28,17),'E',44,col('#885723'))
 elif name=='gem':
  poly(d,[(25,16),(70,16),(89,39),(48,87),(7,39)],col('#9146d9'),col('#efa4ff'));line(d,[(25,16),(34,39),(48,87),(61,39),(70,16)],col('#e5b4ff'),2);line(d,[(7,39),(89,39)],col('#b975f2'),2)
 elif name=='fragment':poly(d,[(56,9),(81,42),(61,82),(20,68),(28,29)],col('#257b9b'),col('#82f0ff'));line(d,[(56,9),(48,42),(61,82)],col('#c0fcff'),2)
 elif name=='chest':
  rect(d,(11,38,85,79),col('#253956'),col('#62d7ef'),2);poly(d,[(11,37),(22,19),(74,19),(85,37)],col('#49346d'),col('#bd8bff'));rect(d,(38,33,58,65),col('#ad7af4'),col('#dcbbff'));line(d,[(47,43),(47,55)],col('#fff1c9'),3)
 elif name=='trophy':
  poly(d,[(26,17),(70,17),(65,53),(50,65),(50,76),(68,76),(68,83),(27,83),(27,76),(45,76),(45,65),(30,53)],col('#dfaa4e'),col('#fff0b3'));line(d,[(26,25),(13,25),(15,49),(32,54)],col('#f7d179'),4);line(d,[(70,25),(83,25),(80,49),(64,54)],col('#f7d179'),4)
 else:poly(d,[(53,8),(27,48),(45,48),(36,87),(73,39),(53,39)],col('#52e3f4'),col('#d0fcff'))
 save(glow(im),Path(f'icons/{name}.png'))
# Authored reusable world tile, subtle floor; no vignette so edge tiles match.
im,d=canvas(512,512)
d.rectangle((0,0,1536,1536),fill=col('#080e20'))
for x in range(0,513,64):line(d,[(x,0),(x,512)],col('#14213b'),1)
for y in range(0,513,64):line(d,[(0,y),(512,y)],col('#14213b'),1)
for x in range(0,512,128):
 for y in range(0,512,128):
  line(d,[(x+14,y+25),(x+14,y+14),(x+25,y+14)],col('#203b53'),1)
  line(d,[(x+103,y+114),(x+114,y+114),(x+114,y+103)],col('#203b53'),1)
  ell(d,(x+61,y+61,x+67,y+67),col('#26526a'))
save(im,Path('arenas/neon_city.png'))
for name,c in [('spark','#9cf6ff'),('glow','#9657ff'),('flame','#ffbc58'),('frost','#b6edff')]:
 im,d=canvas(64,64)
 for r in range(29,0,-1):ell(d,(32-r,32-r,32+r,32+r),col(c,int(120*(1-r/30)**2)))
 ell(d,(28,28,36,36),col(c));save(im,Path(f'particles/{name}.png'))
print('Authored assets generated: five skins, branding, UI, arena, icons, particles.')
