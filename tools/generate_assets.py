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
# War Serpent logo is original image-generated key art; retain checked-in PNG.
im,d=canvas(600,240)
poly(d,[(38,50),(163,50),(145,72),(61,72),(80,99),(145,99),(126,120),(67,120),(79,147),(146,147),(166,169),(50,169),(24,109)],col('#ae7aff'),col('#f1c5ff'))
txt(d,(190,56),'EMNIO',68,col('#f1edff'))
txt(d,(195,143),'PLAY BEYOND THE SIGNAL',16,col('#8f9fbd'))
save(glow(im),Path('branding/emnio.png'))
# Android icon is original image-generated key art; retain checked-in PNG.
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

# v1.1: original premium studio identity, tactile UI materials, three new species.
# These illustrations are authored from vector paths at 3x then antialiased.
# UI art intentionally keeps typography external for localization.
def emnio_emblem(d,cx,cy,scale=1.0,white=False):
 def q(points):return [(cx+x*scale,cy+y*scale) for x,y in points]
 ink=col('#edf4ff') if white else col('#bd9bff')
 # Two folded blade shapes describe a continuous angular E / horizon portal.
 poly(d,q([(-69,-71),(37,-71),(72,-34),(15,-34),(-12,-7),(54,-7),(23,24),(-44,24),(-74,-7),(-41,-40),(5,-40),(-9,-54),(-56,-54)]),ink)
 poly(d,q([(-44,35),(21,35),(50,6),(74,31),(34,71),(-7,71),(-29,49),(-67,49)]),col('#f1f7ff'))
 # Small detached signal shard is the recognizable brand accent.
 poly(d,q([(58,-71),(81,-48),(68,-35),(45,-58)]),col('#6ce9f0'))

im,d=canvas(1000,380)
emnio_emblem(d,145,179,1.34)
# Custom geometric wordmark, each letter is individually authored.
letters={
'E': [[(0,0),(70,0),(70,15),(18,15),(18,37),(60,37),(60,52),(18,52),(18,75),(70,75),(70,90),(0,90)]],
'M': [[(0,90),(0,0),(19,0),(44,42),(69,0),(88,0),(88,90),(71,90),(71,28),(44,71),(17,28),(17,90)]],
'N': [[(0,90),(0,0),(17,0),(57,62),(57,0),(75,0),(75,90),(58,90),(18,28),(18,90)]],
'I': [[(0,0),(18,0),(18,90),(0,90)]],
'O': [[(15,0),(65,0),(80,15),(80,75),(65,90),(15,90),(0,75),(0,15)],[(20,17),(17,20),(17,70),(20,73),(60,73),(63,70),(63,20),(60,17)]]}
x=300
for char in 'EMNIO':
 shapes=letters[char]
 poly(d,[(x+u*1.35,111+v*1.35) for u,v in shapes[0]],col('#f1f6ff'))
 if char=='O':poly(d,[(x+u*1.35,111+v*1.35) for u,v in shapes[1]],(0,0,0,0))
 x+= (max(pt[0] for pt in shapes[0])+30)*1.35
# restrained label with generous tracking
small=ImageFont.truetype(str(A/'fonts/Body.ttf'),17*S)
d.text((302*S,260*S),'G A M E S',font=small,fill=col('#97a4be'))
line(d,[(302,291),(423,291)],col('#9c78d4'),2)
save(im,Path('branding/emnio.png'))
im,d=canvas(512,512)
emnio_emblem(d,256,256,2.42)
save(glow(im),Path('branding/emnio_symbol.png'))
# wide white wordmark for future high-contrast placements
im,d=canvas(1000,190)
x=105
for char in 'EMNIO':
 shapes=letters[char]
 poly(d,[(x+u*1.65,20+v*1.65) for u,v in shapes[0]],col('#f2f7ff'))
 if char=='O':poly(d,[(x+u*1.65,20+v*1.65) for u,v in shapes[1]],(0,0,0,0))
 x+=(max(pt[0] for pt in shapes[0])+29)*1.65
save(im,Path('branding/emnio_wordmark.png'))

# Tactile dark metal buttons: quiet surfaces, inset illumination and asymmetric cuts.
def material_asset(name,accent,kind='button',state='normal'):
 w,h=(512,128) if kind=='button' else (512,256)
 im,d=canvas(w,h)
 ac=col(accent)
 silhouette=[(18,5),(w-29,5),(w-5,29),(w-5,h-20),(w-20,h-5),(5,h-5),(5,18)]
 poly(d,[(x,y+3) for x,y in silhouette],col('#010610',210))
 poly(d,silhouette,col('#17273b') if state!='hover' else col('#243a50'))
 # The inner material is a subtle monochrome bevel, not an outer wireframe.
 inner=[(20,9),(w-31,9),(w-10,31),(w-10,h-22),(w-22,h-10),(10,h-10),(10,21)]
 poly(d,inner,col('#0e2033') if state!='pressed' else col('#081321'))
 if kind=='button':
  for y in range(12,h-12):
   r=.68+.32*(1-y/h)
   if state=='hover':base=(28,64,81)
   elif state=='pressed':base=(9,20,31)
   else:base=(17,37,53)
   line(d,[(20,y),(w-34,y)],tuple(int(v*r) for v in base)+(255,),1)
  poly(d,[(9,21),(18,12),(22,12),(22,h-11),(10,h-11)],ac)
  poly(d,[(27,16),(w-35,16),(w-26,25),(27,25)],col('#bce7f4',20 if state=='normal' else 45))
  # Three bright hardware segments make the action location recognizable.
  for i in range(3):poly(d,[(w-62+i*11,51),(w-55+i*11,58),(w-62+i*11,65),(w-58+i*11,65),(w-51+i*11,58),(w-58+i*11,51)],ac)
  line(d,[(30,h-16),(w-32,h-16)],col('#02101d'),2)
  if state=='hover':line(d,[(28,h-11),(w-30,h-11)],ac,2)
 else:
  # A soft upper reflection and a recessed lower material anchor content.
  poly(d,[(12,22),(24,10),(w-32,10),(w-17,25),(w-17,40),(12,40)],col('#d1e5ff',12))
  line(d,[(25,11),(102,11)],ac,3)
  line(d,[(w-84,h-11),(w-28,h-11)],col('#617b98'),2)
  poly(d,[(11,48),(14,48),(14,h-38),(11,h-38)],col('#57718e',70))
 save(im,Path(f'ui/{name}.png'))
for n,c in [('button','#57e5ed'),('button_alt','#be99fa')]:material_asset(n,c)
material_asset('button_hover','#97fcff',state='hover')
material_asset('button_pressed','#58b9c8',state='pressed')
material_asset('panel','#7d9cbd','panel')
material_asset('card','#a090dc','panel')

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
 im,d=canvas(128,128)
 poly(d,[(34,6),(94,6),(122,34),(122,94),(94,122),(34,122),(6,94),(6,34)],z,b)
 if k==5:
  # Solar polarity magnet, expanding orbital field.
  ell(d,(23,23,105,105),None,m,2)
  ell(d,(32,32,96,96),None,b,2)
  line(d,[(45,43),(45,69),(51,83),(76,83),(83,69),(83,43)],b,12)
  line(d,[(45,40),(45,52)],a,12);line(d,[(83,40),(83,52)],a,12)
 elif k==6:
  # Katana dash.
  poly(d,[(32,98),(43,72),(88,25),(101,20),(96,34),(53,81)],b,a)
  line(d,[(36,70),(56,89)],a,5)
  line(d,[(23,45),(56,45)],a,3);line(d,[(18,59),(44,59)],a,2)
  line(d,[(66,93),(96,93)],b,3)
 else:
  # Venom droplet with warning-fang center.
  poly(d,[(64,20),(97,67),(95,87),(81,103),(49,103),(33,87),(31,67)],m,b)
  poly(d,[(46,67),(57,71),(52,87)],a)
  poly(d,[(72,71),(83,67),(77,87)],a)
  line(d,[(47,53),(57,46)],a,2)
 save(glow(im),Path(f'icons/ability_{k}.png'))
print('v1.1 assets: refined EMNIO brand, tactile metal UI, 8 distinct skin sets.')

# v1.2 compact navigation pictograms, neutral platinum/cyan language.
for name in ('serpent','shop','mission','record','achievement'):
 im,d=canvas(96,96)
 ink=col('#cfebf7');ac=col('#67deec');shadow=col('#314961')
 if name=='serpent':
  # Continuous coil silhouette with a visible triangular, eyed head.
  poly(d,[(14,29),(29,14),(61,14),(80,29),(75,44),(36,44),(28,53),(63,53),(79,68),(65,82),(27,82),(13,68),(25,58),(35,68),(57,68),(62,64),(28,64),(14,52),(23,32),(59,32),(62,28),(37,27),(29,36)],ink)
  poly(d,[(59,12),(80,21),(86,31),(76,35),(61,27)],ac)
  ell(d,(71,21,74,24),col('#071a2b'))
 elif name=='shop':
  poly(d,[(20,35),(76,35),(82,79),(14,79)],None,ink)
  line(d,[(20,35),(76,35),(82,79),(14,79),(20,35)],ink,4)
  d.arc((31*S,13*S,65*S,55*S),180,360,fill=ac,width=4*S)
  ell(d,(40,50,56,66),ac)
  line(d,[(45,54),(50,54),(45,60),(51,60)],col('#0e2436'),2)
 elif name=='mission':
  line(d,[(71,77),(24,77),(24,23),(36,23)],ink,4)
  line(d,[(58,23),(71,23),(71,77)],ink,4)
  rect(d,(35,16,59,30),ac)
  for y in (43,62):
   line(d,[(32,y),(36,y+4),(43,y-5)],ac,3)
   line(d,[(50,y),(62,y)],ink,3)
 elif name=='record':
  # Flag on the summit of an ascending record chart.
  line(d,[(16,77),(16,59),(31,59),(31,77),(39,77),(39,43),(54,43),(54,77),(62,77),(62,27),(77,27),(77,77)],ink,3)
  line(d,[(15,79),(81,79)],ac,3)
  line(d,[(68,26),(68,9)],ac,3)
  poly(d,[(69,8),(84,12),(69,19)],ac)
 else:
  # A medal framed by a sparse laurel; no dense unreadable detail.
  poly(d,[(48,15),(58,36),(81,40),(64,56),(68,79),(48,68),(28,79),(32,56),(15,40),(38,36)],ink)
  poly(d,[(48,27),(54,42),(69,45),(58,54),(59,67),(48,60),(37,67),(38,54),(28,45),(42,42)],ac)
  for side in(-1,1):
   line(d,[(48+side*33,75),(48+side*39,59),(48+side*37,43)],shadow,3)
 save(im,Path(f'icons/{name}.png'))
# White energy sprite for a single batch tinted by per-instance colors.
im,d=canvas(64,64)
for r in range(29,0,-1):ell(d,(32-r,32-r,32+r,32+r),(255,255,255,int(180*(1-r/30)**3)))
ell(d,(27,27,37,37),(255,255,255,255))
save(im,Path('particles/energy.png'))
# New original floor material: tileable inset metal octagonal deck panels,
# sparse cyan terminals, restrained manufactured bevels; a single GPU texture.
im,d=canvas(512,512)
d.rectangle((0,0,512*S,512*S),fill=col('#080f1c'))
for x in range(-128,512,128):
 for y in range(-128,512,128):
  points=[(x+16,y+3),(x+111,y+3),(x+125,y+17),(x+125,y+111),(x+111,y+125),(x+17,y+125),(x+3,y+111),(x+3,y+16)]
  poly(d,points,col('#101b2a'),col('#1b2a3d'))
  line(d,[(x+18,y+5),(x+110,y+5),(x+122,y+18)],col('#253447'),1)
  line(d,[(x+6,y+110),(x+18,y+122),(x+110,y+122)],col('#050b15'),2)
  poly(d,[(x+26,y+24),(x+102,y+24),(x+104,y+27),(x+24,y+27)],col('#152438'))
  line(d,[(x+16,y+48),(x+16,y+76)],col('#1e3245'),1)
  line(d,[(x+111,y+48),(x+111,y+76)],col('#1e3245'),1)
  # Docking latch and direction markers are intentionally dim, behind food.
  rect(d,(x+56,y+56,x+72,y+72),col('#0a1422'),col('#20364a'),1)
  line(d,[(x+60,y+64),(x+68,y+64)],col('#36616c'),2)
  for sx,sy in [(20,20),(108,108)]:ell(d,(x+sx-1,y+sy-1,x+sx+1,y+sy+1),col('#36515f'))
  if (x//128+y//128)%3==0:
   line(d,[(x+45,y+109),(x+75,y+109)],col('#23515d'),2)
save(im,Path('arenas/neon_city.png'))
print('v1.2 authored navigation icons, neutral energy sprite, inset metal arena tile generated.')

# Final v1.2 reference-aligned original materials and glossy species.
# Generated EMNIO GAMES and War Serpent brand PNGs are never edited by these tools.
import runpy
runpy.run_path(str(ROOT/'tools'/'generate_snake_sprites.py'), run_name='__main__')
runpy.run_path(str(ROOT/'tools'/'generate_lobby_materials.py'), run_name='__main__')
# Authored compatibility wordmark also spells out the full studio name.
im,d=canvas(1000,270)
x=105
for char in 'EMNIO':
 shapes=letters[char]
 poly(d,[(x+u*1.65,20+v*1.65) for u,v in shapes[0]],col('#f2f7ff'))
 if char=='O':poly(d,[(x+u*1.65,20+v*1.65) for u,v in shapes[1]],(0,0,0,0))
 x+=(max(pt[0] for pt in shapes[0])+29)*1.65
studiofont=ImageFont.truetype(str(A/'fonts/Display.ttf'),31*S)
d.text((314*S,201*S),'G A M E S',font=studiofont,fill=col('#a8c1d6'))
save(im,Path('branding/emnio_wordmark.png'))
