"""Build cached mono PCM from the user's gun.mp3. Requires numpy and libsndfile.
Run from any directory: python tools/audio/prepare_player_cannon.py
Timing/pitch stay unchanged; only attenuation and a 2ms edge fade are applied.
"""
import ctypes as c
import ctypes.util
from pathlib import Path
import wave
import numpy as np

class Info(c.Structure):
    _fields_ = [('frames', c.c_int64), ('samplerate', c.c_int), ('channels', c.c_int),
                ('format', c.c_int), ('sections', c.c_int), ('seekable', c.c_int)]

folder = Path(__file__).resolve().parents[2] / 'assets/audio'
library = ctypes.util.find_library('sndfile')
if not library:
    raise RuntimeError('libsndfile is required to decode MP3')
lib = c.CDLL(library)
lib.sf_open.argtypes = [c.c_char_p, c.c_int, c.POINTER(Info)]
lib.sf_open.restype = c.c_void_p
lib.sf_readf_float.argtypes = [c.c_void_p, c.c_void_p, c.c_int64]
lib.sf_readf_float.restype = c.c_int64
lib.sf_close.argtypes = [c.c_void_p]
info = Info()
handle = lib.sf_open(str(folder / 'gun.mp3').encode(), 16, c.byref(info))
if not handle:
    raise RuntimeError('Could not open gun.mp3')
try:
    audio = np.zeros((info.frames, info.channels), dtype=np.float32)
    read = lib.sf_readf_float(handle, audio.ctypes.data, info.frames)
    if read != info.frames:
        raise RuntimeError('Incomplete MP3 decode')
finally:
    lib.sf_close(handle)
mono = audio.mean(axis=1)
gain = min(1.0, 0.60 / max(0.00001, float(abs(mono).max())))
mono *= gain
fade = min(int(0.002 * info.samplerate), len(mono) // 2)
if fade:
    mono[:fade] *= np.linspace(0, 1, fade)
    mono[-fade:] *= np.linspace(1, 0, fade)
with wave.open(str(folder / 'player_cannon.wav'), 'wb') as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(info.samplerate)
    output.writeframes((np.clip(mono, -1, 1) * 32767).astype('<i2').tobytes())
print(f'player_cannon.wav: {len(mono)/info.samplerate:.3f}s, gain {gain:.4f}')
