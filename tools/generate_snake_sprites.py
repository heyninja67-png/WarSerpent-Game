#!/usr/bin/env python3
"""Original glossy eight-species snake artwork; CC0. Reproducible vector-like PNGs.
No external/reference game image is read. Heads point right and tails point left.
"""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'assets'/'snakes'
S=4
# bright, midtone, shadow, highlight, eye
PALETTES=[('#36e9ff','#1488bb','#073c6c','#dcffff','#a5fbff'),
('#ffa14a','#d84930','#78233d','#ffed99','#ffe65e'),
('#c5f6ff','#61b1dc','#37559b','#ffffff','#459eff'),
('#a8e7ec','#557f98','#263c63','#efffff','#78f7bc'),
('#cb9eff','#7b46bd','#392368','#f7e5ff','#a9fffa'),
('#ffe59d','#dc9e3c','#805132','#fffbe5','#ffad42'),
('#f3f8ff','#bbc5d6','#465274','#ffffff','#ff6c77'),
('#bcff54','#6bcf48','#287146','#f4ffd4','#eaef60')]
def C(h,a=255):h=h.lstrip('#');return tuple(int(h[i:i+2],16) for i in(0,2,4))+(a,)
def can(w,h):
 im=Image.new('RGBA',(w*S,h*S));return im,ImageDraw.Draw(im)
def pts(x):return [(round(a*S),round(b*S))for a,b in x]
def poly(d,x,fill,outline=None,width=1):
 d.polygon(pts(x),fill=fill)
 if outline:d.line(pts(x+[x[0]]),fill=outline,width=round(width*S),joint='curve')
def ellipse(d,box,fill,outline=None,width=1):d.ellipse(tuple(round(v*S)for v in box),fill=fill,outline=outline,width=round(width*S))
def line(d,x,c,w=1):d.line(pts(x),fill=c,width=round(w*S),joint='curve')
def bezier(points,n=32):
 out=[]
 for i in range(n+1):
  t=i/n;u=1-t
  out.append((u*u*u*points[0][0]+3*u*u*t*points[1][0]+3*u*t*t*points[2][0]+t*t*t*points[3][0],u*u*u*points[0][1]+3*u*u*t*points[1][1]+3*u*t*t*points[2][1]+t*t*t*points[3][1]))
 return out
def save(im,name):
 A.mkdir(parents=True,exist_ok=True)
 im.resize((im.width//S,im.height//S),Image.Resampling.LANCZOS).save(A/name)
def jelly_volume(im,bounds,bright,mid,dark):
 """Layered soft 3D body, all authored primitives rather than edited imagery."""
 d=ImageDraw.Draw(im)
 x1,y1,x2,y2=bounds
 ellipse(d,(x1,y1+2,x2,y2+2),C(dark),C(dark),1)
 ellipse(d,(x1,y1,x2,y2),C(mid),C(dark),1.2)
 for i in range(12):
  q=i/12
  # Top light is broad, softly curved and saturated, not a hard flat disc.
  mix=tuple(round(int(mid[j:j+2],16)*(1-q)+int(bright[j:j+2],16)*q)for j in(1,3,5))+(255,)
  ellipse(d,(x1+1+q*2,y1+1,x2-1-q*2,y2-3-q*(y2-y1)*.37),mix)
 return d
def eye(d,cx,cy,size,iris,far=False):
 # A bright ocular sclera and dark offset pupil make the character readable in motion.
 ellipse(d,(cx-size-1,cy-size*1.08-1,cx+size+1,cy+size*1.08+1),C('#122446'))
 ellipse(d,(cx-size,cy-size*1.08,cx+size,cy+size*1.08),C('#f7fdff'))
 ellipse(d,(cx-size*.20,cy-size*.68,cx+size*.87,cy+size*.80),C(iris))
 ellipse(d,(cx+size*.20,cy-size*.50,cx+size*.78,cy+size*.64),C('#102340'))
 ellipse(d,(cx+size*.20,cy-size*.60,cx+size*.49,cy-size*.22),C('#ffffff'))
 ellipse(d,(cx+size*.54,cy+size*.31,cx+size*.70,cy+size*.47),C('#d4f7ff'))
 if far:line(d,[(cx-size,cy-size*.90),(cx+size*.60,cy-size*.60)],C('#304463'),1.5)
for k,(bright,mid,dark,highlight,iris) in enumerate(PALETTES):
 b,m,z,h,e=map(C,(bright,mid,dark,highlight,iris))
 # HEAD: broad friendly/competitive sculpted faces with unmistakably distinct silhouettes.
 im,d=can(96,76)
 if k==0:
  poly(d,[(9,29),(6,9),(25,19),(28,4),(43,19),(51,9),(59,25)],z,b,1.2)
  poly(d,[(14,49),(8,64),(31,54)],m,b)
 elif k==1:
  poly(d,[(10,38),(3,18),(17,24),(16,5),(34,18),(43,2),(50,18),(62,11),(66,29)],mid,b,1.2)
  poly(d,[(18,47),(9,66),(34,57)],z,C('#ffb963'))
 elif k==2:
  poly(d,[(9,32),(12,9),(25,21),(35,1),(45,21),(58,8),(61,31)],C('#88c9ec'),h,1.1)
  line(d,[(35,3),(35,26)],C('#ffffff'),1)
 elif k==3:
  poly(d,[(8,26),(20,13),(48,11),(65,23),(67,51),(44,62),(15,56),(7,43)],z,b,1.5)
  poly(d,[(15,19),(42,17),(52,23),(21,29)],C('#c9eff2'))
  ellipse(d,(7,30,24,49),C('#273f61'),b,2)
  line(d,[(10,34),(21,34)],C('#b2ffbd'),2)
 elif k==4:
  poly(d,[(10,35),(2,8),(28,21),(41,6),(57,24),(61,47),(29,67),(11,61),(20,48)],z,b,1.2)
  poly(d,[(7,56),(24,49),(18,68),(38,57)],m,C('#b99ee8'))
 elif k==5:
  for ang in range(115,256,28):
   t=math.radians(ang);u=math.radians(ang+9)
   poly(d,[(32+22*math.cos(t),39+22*math.sin(t)),(32+37*math.cos(u),39+37*math.sin(u)),(32+22*math.cos(t+.25),39+22*math.sin(t+.25))],m,b)
  ellipse(d,(8,15,59,64),m,b,2)
  ellipse(d,(15,22,52,57),z,h)
 elif k==6:
  poly(d,[(4,30),(12,11),(30,6),(51,11),(68,25),(62,47),(17,50)],z,C('#e3eaf5'),1.5)
  poly(d,[(10,24),(2,5),(28,14),(36,3),(44,18),(64,5),(62,29)],C('#bd364d'),C('#ffadb7'),1)
  poly(d,[(15,28),(30,18),(49,21),(57,29),(40,37)],b)
 else:
  poly(d,[(17,6),(36,10),(52,24),(51,52),(34,69),(11,63),(2,42),(6,20)],z,b,1.5)
  poly(d,[(19,15),(30,18),(40,30),(38,52),(25,60),(14,48),(10,31)],m)
  ellipse(d,(16,26,32,47),z,C('#ecff90'),1.5)
  ellipse(d,(20,30,28,42),C('#b7fb66'))
 # Long blended neck and cheek draw over ornament bases.
 jelly_volume(im,(19,22,91,61),bright,mid,dark);d=ImageDraw.Draw(im)
 ellipse(d,(34,15,79,59),m)
 ellipse(d,(35,16,77,51),b)
 ellipse(d,(43,17,72,38),tuple(round(int(bright[i:i+2],16)*.6+int(highlight[i:i+2],16)*.4) for i in (1,3,5))+(255,))
 ellipse(d,(61,31,93,57),m)
 ellipse(d,(65,31,91,48),b)
 # Species-specific ornamental armor/energy treatment kept behind expressive eyes.
 if k==0:
  poly(d,[(24,25),(33,21),(28,32),(37,30),(26,44),(28,33),(21,35)],h)
  line(d,[(22,49),(35,46),(39,51)],C('#60d7ef'),2)
 elif k==1:
  for x,y in[(25,31),(35,24),(32,46)]:
   poly(d,[(x,y),(x+6,y-6),(x+10,y+2),(x+4,y+6)],C('#ffbf62'))
 elif k==2:
  poly(d,[(28,23),(42,19),(36,34)],h)
  poly(d,[(25,34),(37,36),(31,47)],C('#91d8f6'))
  line(d,[(35,24),(39,29)],C('#ffffff'),1)
 elif k==3:
  poly(d,[(19,25),(37,22),(44,30),(37,39),(19,40)],C('#45687c'),C('#d9f6fa'))
  line(d,[(23,29),(35,29)],C('#9affca'),2)
  ellipse(d,(27,43,39,55),z,b);ellipse(d,(31,47,35,51),C('#8effae'))
 elif k==4:
  line(d,bezier([(21,33),(43,17),(29,46),(44,46)]),C('#e3c6ff'),2)
  for x,y in[(25,25),(30,48),(42,24)]:ellipse(d,(x,y,x+2,y+2),h)
 elif k==5:
  poly(d,[(33,21),(38,10),(45,19),(50,11),(55,22)],C('#ffd564'),C('#fff9cd'))
  ellipse(d,(37,29,47,39),C('#9f5d23'),C('#ffe6a2'));ellipse(d,(40,32,44,36),h)
 elif k==6:
  poly(d,[(20,23),(40,18),(51,26),(40,32),(24,31)],h,C('#8c9bab'))
  line(d,[(25,25),(39,23)],C('#cb3a50'),3)
  poly(d,[(24,47),(41,50),(47,57),(31,58)],C('#cd4052'),C('#ffd1d4'))
 elif k==7:
  for x,y in[(30,31),(37,25),(35,45)]:ellipse(d,(x,y,x+4,y+4),C('#e1ff7b'))
 # Far eye partly occluded by near eye: both look right, large readable catchlights.
 eye(d,74,28,7.0,iris,True)
 eye(d,66,38,10.0,iris)
 # Gentle eyebrow tilt gives competitive personality; eye stays visible.
 line(d,bezier([(56,27),(62,23),(69,24),(75,30)]),z,1.8)
 # Muzzle highlight, smiling mouth and nostril.
 ellipse(d,(81,35,85,38),z)
 ellipse(d,(76,37,80,40),C(highlight,180))
 line(d,bezier([(71,51),(78,56),(85,51),(89,48)]),z,1.8)
 line(d,[(72,51),(73,54)],z,1.2)
 if k in(1,7):poly(d,[(81,52),(83,59),(86,51)],C('#fffbea'))
 if k==7:ellipse(d,(84,56,88,62),C('#cfff5c'))
 save(im,f'head_{k}.png')
 # BODY: rounded glossy capsule with broad continuous center overlap, subtle scales.
 im,d=can(64,64)
 jelly_volume(im,(-1,4,65,60),bright,mid,dark);d=ImageDraw.Draw(im)
 # Underbelly ridge adds depth while leaving silhouette connected.
 line(d,bezier([(3,48),(19,58),(43,58),(61,47)]),C(highlight,80),1.2)
 if k==0:
  for x in(-2,20,42):
   line(d,[(x,17),(x+13,25),(x+9,32),(x+19,36),(x+11,47)],C('#075f88'),2)
   line(d,[(x+4,21),(x+12,25),(x+8,32)],C('#c2fcff'),1.2)
 elif k==1:
  for x in(-4,18,40):
   poly(d,[(x,22),(x+12,12),(x+25,25),(x+12,36)],C('#b94632'),C('#ffb459'))
   poly(d,[(x+3,40),(x+13,30),(x+24,42),(x+13,51)],C('#d86735'),C('#ee8f49'))
  line(d,[(0,35),(12,29),(23,36),(35,29),(47,37),(64,30)],C('#ffe38c'),1.2)
 elif k==2:
  for x in(-4,19,42):
   poly(d,[(x,30),(x+12,11),(x+27,30),(x+12,48)],C('#a1d9ef'),C('#e8fcff'),.8)
   poly(d,[(x+12,11),(x+12,48),(x+27,30)],C('#73b9dc'))
   line(d,[(x+12,13),(x+12,46)],C('#ecffff'),1)
 elif k==3:
  for x in(-4,20,44):
   poly(d,[(x,17),(x+17,12),(x+24,22),(x+22,43),(x+5,50),(x-2,39)],C('#567f97'),C('#b3dfe9'),1)
   line(d,[(x+4,20),(x+14,17)],C('#e4ffff'),1)
   line(d,[(x+5,38),(x+17,34)],C('#8affe2'),2)
 elif k==4:
  for x in(-6,18,42):
   line(d,bezier([(x,19),(x+28,20),(x,38),(x+26,44)]),C('#b589e7'),2)
   line(d,bezier([(x,20),(x+19,22),(x+8,31),(x+23,35)]),C('#e4c5ff'),.8)
  for x,y in((9,38),(27,15),(46,43)):ellipse(d,(x,y,x+2,y+2),C('#e7deff'))
 elif k==5:
  for x in(-6,17,40):
   poly(d,[(x,31),(x+13,11),(x+27,31),(x+13,51)],C('#d29a4e'),C('#ffe7a9'),1)
   poly(d,[(x+6,28),(x+13,16),(x+19,28),(x+13,33)],C('#fff3c5'))
  line(d,[(0,34),(64,34)],C('#f8cf75'),1.5)
 elif k==6:
  for x in(-6,17,40):
   poly(d,[(x,19),(x+20,13),(x+28,28),(x+21,48),(x,45),(x+5,30)],C('#e8ecf8'),C('#7e8eab'),1)
   poly(d,[(x+4,23),(x+18,19),(x+22,26),(x+8,30)],C('#ffffff'))
   line(d,[(x+5,36),(x+21,35)],C('#ec6573'),3)
   line(d,[(x+7,42),(x+17,41)],C('#64738d'),1)
 else:
  for x in(-4,18,40):
   for y in(20,40):poly(d,[(x,y),(x+12,y-10),(x+24,y),(x+12,y+10)],C('#88df48'),C('#b9f96b'),.7)
  for x,y in((8,31),(29,27),(50,33)):
   ellipse(d,(x-4,y-4,x+4,y+4),C('#2f8b47'),C('#ddff9a'),1)
 # Smooth specular highlight authored above pattern, sufficiently understated for real play.
 line(d,bezier([(7,17),(20,9),(39,9),(54,15)]),C(highlight,145),1.6)
 save(im,f'body_{k}.png')
 # TAIL: a rounded flowing taper, not a disconnected arrowhead.
 im,d=can(96,64)
 upper=bezier([(3,34),(26,34),(54,14),(94,8)])
 lower=bezier([(94,56),(56,53),(33,36),(3,34)])
 poly(d,upper+lower,z,b,1)
 upper2=bezier([(12,34),(36,32),(63,19),(94,15)])
 lower2=bezier([(94,43),(58,42),(34,35),(12,34)])
 poly(d,upper2+lower2,m)
 line(d,bezier([(28,32),(52,24),(74,20),(92,20)]),C(highlight,180),1.5)
 for x in(55,73,87):
  line(d,[(x,23-(x-55)*.1),(x-5,34),(x,45+(x-55)*.1)],C(dark,180),1)
 if k==6:line(d,bezier([(45,35),(66,35),(82,36),(93,35)]),C('#e96376'),3)
 if k==7:
  for x in(54,72,88):ellipse(d,(x-2,30,x+2,34),C('#daff7b'))
 save(im,f'tail_{k}.png')
print('Generated 8 distinct glossy, expressive snake species (24 RGBA sprites).')
