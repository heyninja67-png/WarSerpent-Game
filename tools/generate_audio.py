#!/usr/bin/env python3
"""Reproducible original War Serpent.io synthesizer; CC0-1.0 audio."""
import math, random, struct, wave
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
RATE = 22050
TAU = math.tau
rng = random.Random(7427)
def write(name, duration, sample, stereo=False):
    ROOT.mkdir(parents=True, exist_ok=True)
    channels = 2 if stereo else 1
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(channels); wav.setsampwidth(2); wav.setframerate(RATE)
        data = bytearray()
        for i in range(round(duration*RATE)):
            t = i/RATE
            v = sample(t, duration)
            vals = v if stereo else [v]
            for x in vals: data += struct.pack('<h', round(max(-.98,min(.98,x))*32767))
        wav.writeframes(data)
def env(t,d,a=.008,release=.08): return min(1,t/a)*min(1,(d-t)/release)
write('tap',.12,lambda t,d: .22*env(t,d)*math.sin(TAU*(900*t-1100*t*t))*math.exp(-t*20))
write('collect',.18,lambda t,d: .18*env(t,d)*math.sin(TAU*(650*t+1500*t*t))*math.exp(-t*12))
write('boost',.55,lambda t,d: env(t,d)*(.11*math.sin(TAU*(85*t+100*t*t))+.035*rng.uniform(-1,1))*math.exp(-t*2))
write('ability',.72,lambda t,d: env(t,d)*(.12*math.sin(TAU*(180*t+320*t*t))+.065*math.sin(TAU*(360*t+700*t*t)))*math.exp(-t*2.6))
write('death',.9,lambda t,d: env(t,d,release=.3)*(.19*math.sin(TAU*(145*t-65*t*t))+.06*rng.uniform(-1,1))*math.exp(-t*3))
notes=[523.251,659.255,783.991,1046.502]
def unlock(t,d):
    sound=0
    for i,f in enumerate(notes):
        dt=t-i*.095
        if dt>0: sound+=.12*min(1,dt/.008)*math.exp(-dt*5)*math.sin(TAU*f*dt)
    return sound*env(t,d,release=.25)
write('unlock',1.0,unlock)
# Original 8-bar C-minor suspended atmosphere. Frequencies are exact loop multiples
# so every oscillator and modulation meets at the 12-second boundary.
def ambient(t,d):
    left=right=0
    for n,(freq,amp,pan) in enumerate([(65.4166667,.065,-.1),(97.9166667,.035,.1),(130.8333333,.03,-.4),(155.5833333,.028,.3),(196,.02,-.2),(261.6666667,.016,.4)]):
        f=round(freq*d)/d
        mod=.76+.24*math.cos(TAU*(n+1)*t/d)
        v=amp*math.sin(TAU*f*t)*mod
        left+=v*(1-pan); right+=v*(1+pan)
    step=int(t/.375)
    note=[392,466.1666667,523.25,587.3333333,523.25,466.1666667,392,349.25][step%8]
    nt=t% .375
    arp=.028*math.sin(TAU*note*nt)*math.exp(-nt*14)*min(1,nt/.008)
    kick=.075*math.sin(TAU*(48*nt+1.1*(1-math.exp(-nt*30))))*math.exp(-nt*28)
    # Slow fade at loop edge avoids any transient discontinuity.
    edge=min(1,t/.04,(d-t)/.04)
    return [(left+arp*.65+kick)*edge,(right+arp+kick)*edge]
write('ambient',12,ambient,True)
print('Generated 7 original WAV assets in',ROOT)
