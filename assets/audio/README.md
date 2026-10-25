# Original War Serpent.io soundtrack and sound effects

All music and sound effects are original, synthesized for Emnio with no external recordings, samples, commercial melodies, or copyrighted game assets. The audio is dedicated to the public domain under **CC0-1.0**: https://creativecommons.org/publicdomain/zero/1.0/ . Attribution is appreciated but not required.

## v1.1 soundtrack

- `music_menu.ogg` — **Neon Coil**. Original synthwave hook, C minor / A-flat / E-flat / B-flat harmonic progression, warm stereo pads, syncopated bassline, bells, kick, snare, swung hats, and a final phrase fill.
- `music_arena.ogg` — **Overdrive**. The same musical identity arranged with a driving octave bass, four-on-floor kick, sixteenth-note hats, faster arpeggios, and a brighter final hook.

Both tracks: 16 bars, 4/4, **85 BPM**, **45.176463 seconds**, **44.1 kHz stereo**, Ogg Vorbis. Circular delay and a small wrap crossfade make each score suitable for a continuous loop. Enable `AudioStreamOggVorbis.loop` in Godot. Suggested music starting volume is -14 dB (independent from effects); adjust by device and the player's volume setting. Changing from menu to arena should crossfade rather than cut the current note.

`tools/generate_audio.py` rebuilds v1.1 music and the additional sound effects. It requires Python 3, NumPy and FFmpeg with libvorbis. WAV intermediates are temporary and are excluded from the project. All notes, rhythms, synthesis and mixing are visible in the generator.

## Effects

Original compatibility effects remain: `tap`, `collect`, `boost`, `ability`, `death`, `unlock`. The 12-second `ambient.wav` from v1.0 is retained only for backwards compatibility; the application should select the new OGG music.

v1.1 adds distinct `hover`, `pause`, `victory`, `hit`, `purchase`, `error` and `start` WAVs. These are 44.1 kHz, 16-bit mono PCM. Earlier effects remain 22.05 kHz mono PCM.

## Validation scope

`audio_metadata.json` records source PCM and decoded Vorbis measurements, duration, sample rate, channels, file size, measured peak/RMS levels, finite samples, clipped sample counts and loop endpoint differences. FFmpeg decoded both OGG tracks successfully; no clipped samples, NaNs or infinities were found. Encoded-track peaks are below -1.2 dBFS. The small decoded endpoint differences reflect lossy Vorbis encoding; the source PCM endpoints match exactly. No listening test on a physical Android device was performed by the audio-generation task.
