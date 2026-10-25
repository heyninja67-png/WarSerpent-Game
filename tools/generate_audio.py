#!/usr/bin/env python3
"""Original Emnio score: Neon Coil + Overdrive. No samples; CC0-1.0.
Rebuild: python3 tools/generate_audio.py (requires numpy + ffmpeg).
Music: C minor; 85 BPM, 4/4, 16 bars; PCM48k intermediate -> Vorbis.
"""
import json, math, random, struct, subprocess, tempfile, wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/'assets'/'audio'
ROOT.mkdir(parents=True,exist_ok=True)
SR=44100; TAU=math.tau; BPM=85; BEAT=60/BPM; BARS=16; DURATION=BEAT*64
rng=np.random.default_rng(7427)

def midi(n): return 440*2**((n-69)/12)
def envelope(t,d,a=.006,r=.06): return np.minimum(1,t/a)*np.minimum(1,np.maximum(0,(d-t)/r))
def tone(n,d,kind='lead',v=1):
    t=np.arange(round(d*SR))/SR; f=midi(n)
    if kind=='bass':
        x=np.sin(TAU*f*t)+.30*np.sin(TAU*2*f*t)+.12*np.sin(TAU*3*f*t)
        x*=envelope(t,d,.006,.055)*(.70+.30*np.exp(-t*5))
    elif kind=='pad':
        x=np.zeros(len(t))
        for h in range(1,6):
            x+=np.sin(TAU*f*h*t+.13*h)/(h*h)
            x+=.25*np.sin(TAU*f*h*1.0017*t)/(h*h)
        x*=envelope(t,d,.12,.26)
    elif kind=='bell':
        x=(np.sin(TAU*f*t)+.24*np.sin(TAU*f*2*t)+.08*np.sin(TAU*f*3*t))*np.exp(-t*5)*envelope(t,d,.003,.04)
    else:
        x=np.zeros(len(t))
        for h in range(1,6):
            x+=np.sin(TAU*f*h*t)/(h*h)
        x+=.10*np.sin(TAU*f*1.003*t)
        x*=envelope(t,d,.008,.06)*(.62+.38*np.exp(-t*5))
    return x*v

def put(track,x,beat,pan=0,gain=1):
    start=round(beat*BEAT*SR); pos=(start+np.arange(len(x)))%len(track)
    track[pos,0]+=x*gain*math.sqrt((1-pan)/2)
    track[pos,1]+=x*gain*math.sqrt((1+pan)/2)

def drum(which):
    d={'kick':.33,'snare':.23,'hat':.085,'open':.24}[which]
    t=np.arange(round(d*SR))/SR
    if which=='kick':
        phase=TAU*(46*t+(130/48)*(1-np.exp(-48*t)))
        x=.78*np.sin(phase)*np.exp(-t*12)+.1*rng.normal(size=len(t))*np.exp(-t*160)
    elif which=='snare':
        noise=rng.normal(size=len(t)); noise=np.r_[0,np.diff(noise)]*.4
        x=.37*noise*np.exp(-t*18)+.24*np.sin(TAU*180*t)*np.exp(-t*20)
        x+=.07*np.sin(TAU*330*t)*np.exp(-t*26)
    else:
        noise=rng.normal(size=len(t)); noise=np.r_[0,np.diff(noise)]*.22
        x=noise*np.exp(-t*(60 if which=='hat' else 17))
    return x*envelope(t,d,.001,.02)

def delay(track,beats=.75,amount=.24):
    out=track.copy()
    for i in range(1,4):
        shifted=np.roll(track,round(BEAT*beats*i*SR),axis=0)
        if i%2: shifted=shifted[:,::-1]
        out+=shifted*amount**i
    return out

def write_pcm(path,arr,rate=SR):
    if arr.ndim==1: arr=arr[:,None]
    with wave.open(str(path),'wb') as w:
        w.setnchannels(arr.shape[1]); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes((np.clip(arr,-.99,.99)*32767).astype('<i2').tobytes())

def music(arena=False):
    length=round(DURATION*SR)
    pad=np.zeros((length,2),dtype=np.float64); bass=pad.copy(); melody=pad.copy(); arp=pad.copy(); drums=pad.copy()
    # A/B structure: C minor -> A-flat -> E-flat -> B-flat, repeat with countermelody.
    chords=[(48,51,55),(48,51,55),(44,48,51),(44,48,51),(51,55,58),(51,55,58),(46,50,53),(46,50,53)]*2
    roots=[36,36,32,32,39,39,34,34]*2
    # Distinctive original syncopated C-minor hook; 4 phrase variants.
    phrases=[
      [(0,72,.65),(.75,75,.3),(1.25,79,.45),(2,77,.65),(2.75,75,.3),(3.25,74,.5)],
      [(0,72,1.05),(1.5,67,.32),(2,70,.45),(2.75,74,.3),(3.25,75,.5)],
      [(0,75,.65),(.75,79,.3),(1.25,82,.45),(2,79,.65),(2.75,77,.3),(3.25,75,.5)],
      [(0,74,.7),(1,70,.45),(1.75,72,.3),(2.5,74,.4),(3.25,70,.5)],
    ]
    for bar,chord in enumerate(chords):
        beat=bar*4
        for voice,n in enumerate(chord): put(pad,tone(n+12,BEAT*4.15,'pad',.095 if arena else .12),beat,(-.45,0,.45)[voice])
        # Pulsing octave bass: audible tune rather than a static sub-drone.
        pattern=[(0,0),(.75,0),(1.5,12),(2,0),(2.75,7),(3.5,12)]
        if arena: pattern=[(i*.5,12 if i%4==3 else 0) for i in range(8)]
        for b,octave in pattern: put(bass,tone(roots[bar]+octave,BEAT*.40,'bass',.27),beat+b)
        # Motif appears from first bar; repeats with an octave highlight in final phrase.
        motif=phrases[(bar//2)%4]
        for b,n,dur in motif:
            shift=12 if bar in [11,15] and b>2 else 0
            put(melody,tone(n+shift,BEAT*dur,'lead',.16 if arena else .18),beat+b,math.sin((bar+b)*1.4)*.18)
        # Glittering chord arpeggios open the high spectrum without obscuring melody.
        for i in range(8 if arena else 4):
            step=.5 if arena else 1
            n=chord[(i+bar)%3]+24
            put(arp,tone(n,BEAT*.46,'bell',.055 if arena else .045),beat+i*step,(-.65 if i%2 else .65))
        kicks=[0,1,2,3] if arena else [0,1.75,2.5]
        for b in kicks: put(drums,drum('kick'),beat+b,gain=.57 if arena else .47)
        for b in [1,3]: put(drums,drum('snare'),beat+b,gain=.45 if arena else .38)
        hats=16 if arena else 8
        for i in range(hats):
            b=i*(4/hats)+(.025 if i%2 else 0)
            put(drums,drum('open' if i==hats-1 else 'hat'),beat+b,(-.32 if i%2 else .32),gain=(.34 if i%2 else .23))
        # A short tom-like fill before the return gives the 16 bars direction.
        if bar in [7,15]:
            for i,n in enumerate([48,46,43,39]): put(drums,tone(n,BEAT*.22,'bass',.15),beat+3+i*.25,pan=(i-1.5)*.2)
    t=np.arange(length)/SR
    # Slow four-on-floor sidechain breathing; never gates the melody away.
    phase=(t/BEAT)%1
    duck=.76+.24*(1-np.exp(-phase*7))
    instruments=pad+delay(melody,.75,.22)+delay(arp,.5,.2)+bass
    mix=instruments*duck[:,None]+drums
    # Loop-safe circular diffuse echoes for original roomy atmosphere.
    mix+=np.roll(pad,round(.113*SR),axis=0)[:,::-1]*.14
    # Soft saturation only, followed by conservative peak-normalization.
    mix=np.tanh(mix*1.12)
    peak=np.max(np.abs(mix)); mix*=.86/peak
    # Equal-power brief wrap crossfade removes discontinuities at sample loop point.
    cross=round(.012*SR)
    bridge=np.linspace(0,1,cross)
    boundary=(mix[:cross]+mix[-cross:])*.5
    mix[:cross]=mix[:cross]*bridge[:,None]+boundary*(1-bridge[:,None])
    mix[-cross:]=mix[-cross:]*(1-bridge[:,None])+boundary*bridge[:,None]
    # Final endpoint interpolation guarantees continuity at decoder wrap.
    edge=(mix[0]+mix[-1])*.5
    for i in range(96):
        w=(1-i/96)**2
        mix[i]=mix[i]*(1-w)+edge*w
        mix[-i-1]=mix[-i-1]*(1-w)+edge*w
    return mix

def add_sfx(name,d,fn):
    t=np.arange(round(SR*d))/SR; x=fn(t)*envelope(t,d,.004,min(.12,d*.3))
    peak=np.max(np.abs(x))
    if peak>.72: x*=.72/peak
    write_pcm(ROOT/f'{name}.wav',x)

def sfx():
    add_sfx('hover',.095,lambda t:.13*np.sin(TAU*1020*t)*np.exp(-t*25))
    add_sfx('pause',.24,lambda t:.19*(np.sin(TAU*440*t)*(t<.12)+np.sin(TAU*330*t)*(t>=.12))*np.exp(-t*3))
    add_sfx('hit',.25,lambda t:.29*np.sin(TAU*(135*t-160*t*t))*np.exp(-t*14)+.13*rng.normal(size=len(t))*np.exp(-t*25))
    add_sfx('error',.28,lambda t:.16*(np.sin(TAU*140*t)+.35*np.sin(TAU*210*t))*(.55+.45*np.sin(TAU*17*t)) )
    def arpeggio(notes,spacing,amp=.19,decay=4):
        def synth(t):
            x=np.zeros(len(t))
            for i,n in enumerate(notes):
                dt=t-i*spacing; mask=dt>=0; tt=np.maximum(0,dt)
                x+=amp*mask*np.minimum(1,tt/.006)*np.exp(-tt*decay)*(np.sin(TAU*midi(n)*tt)+.18*np.sin(TAU*midi(n)*2*tt))
            return x
        return synth
    add_sfx('purchase',.65,arpeggio([72,79,84],.09,decay=7))
    add_sfx('start',.72,arpeggio([60,67,72,79],.09,.18,5))
    add_sfx('victory',1.65,arpeggio([72,75,79,84,82,84],.14,.17,3.4))

def main():
    sfx(); metadata={}
    for name,arena in [('music_menu',False),('music_arena',True)]:
        mix=music(arena)
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/f'{name}.wav'; write_pcm(p,mix)
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(p),'-c:a','libvorbis','-q:a','5','-metadata','title='+('Neon Coil' if not arena else 'Overdrive'),'-metadata','artist=Emnio','-metadata','license=CC0-1.0',str(ROOT/f'{name}.ogg')],check=True)
        metadata[name]={'title':'Neon Coil' if not arena else 'Overdrive','duration_seconds':len(mix)/SR,'sample_rate':SR,'channels':2,'bpm':BPM,'bars':BARS,'time_signature':'4/4','key':'C minor','peak_dbfs':float(20*np.log10(np.max(np.abs(mix)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(mix*mix)))),'loop_endpoint_difference':float(np.max(np.abs(mix[0]-mix[-1]))),'file_bytes':(ROOT/f'{name}.ogg').stat().st_size}
        raw=subprocess.run(['ffmpeg','-v','error','-i',str(ROOT/f'{name}.ogg'),'-f','f32le','-'],check=True,stdout=subprocess.PIPE).stdout
        decoded=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
        metadata[name]['decoded']={'duration_seconds':len(decoded)/SR,'peak_dbfs':float(20*np.log10(abs(decoded).max())),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(decoded*decoded)))),'finite':bool(np.isfinite(decoded).all()),'clipped_samples':int(np.count_nonzero(abs(decoded)>=1)),'loop_endpoint_difference':float(abs(decoded[0]-decoded[-1]).max())}
        print(name,metadata[name])
    metadata['new_sfx']={}
    for name in ['hover','pause','victory','hit','purchase','error','start']:
        with wave.open(str(ROOT/f'{name}.wav')) as w:
            samples=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2')/32768
            metadata['new_sfx'][name]={'duration_seconds':len(samples)/w.getframerate(),'sample_rate':w.getframerate(),'channels':w.getnchannels(),'peak_dbfs':float(20*np.log10(abs(samples).max())),'clipped_samples':int(np.count_nonzero(abs(samples)>=1))}
    (ROOT/'audio_metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
if __name__=='__main__': main()
