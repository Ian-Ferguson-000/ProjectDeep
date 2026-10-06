"""Build short combat cues from CC0 recordings (requires numpy and soundfile).

Downloads are cached outside the shipped assets. Run from any directory; source
URLs, constituent filenames and hashes are preserved in the asset manifest.
"""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'build/audio_combat_sources'
OUT = ROOT / 'assets/audio/combat'
RATE = 44100
SOURCES = {
    'swishes': ('artisticdude', 'https://opengameart.org/content/swishes-sound-pack',
                'https://opengameart.org/sites/default/files/swishes.zip'),
    'tinysized': ('Jan Schupke (Vehicle)', 'https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx',
                 'https://opengameart.org/sites/default/files/tinysized.zip'),
    'rpg': ('rubberduck', 'https://opengameart.org/content/80-cc0-rpg-sfx',
            'https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip'),
    'fireball': ('Julien Matthey', 'https://opengameart.org/content/fireball-1',
                 'https://opengameart.org/sites/default/files/105016__julien-matthey__jm-fx-fireball-01.wav'),
}


def fetch():
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / '.gdignore').touch()
    for key, (_, _, url) in SOURCES.items():
        target = CACHE / (key + ('.wav' if key == 'fireball' else '.zip'))
        if not target.exists():
            urllib.request.urlretrieve(url, target)
        if key != 'fireball' and not (CACHE / key).exists():
            with zipfile.ZipFile(target) as archive:
                archive.extractall(CACHE / key)


def recording(group, filename, speed=1.0, duration=0.6):
    path = CACHE / 'fireball.wav' if group == 'fireball' else CACHE / group / filename
    data, rate = sf.read(path, always_2d=True)
    data = data.mean(axis=1)
    data -= data.mean()
    # Trim silence so feedback begins at the action, then limit the tail.
    active = np.flatnonzero(np.abs(data) > np.max(np.abs(data)) * 0.02)
    if not len(active):
        raise ValueError(f'Silent source: {path}')
    data = data[max(0, active[0] - int(rate * 0.003)):active[-1] + 1]
    count = min(int(len(data) * RATE / rate / speed), int(duration * RATE))
    data = np.interp(np.arange(count) * rate * speed / RATE, np.arange(len(data)), data)
    data /= max(np.max(np.abs(data)), 1e-9)
    return data, {'creator': SOURCES[group][0], 'source': SOURCES[group][1],
                  'download': SOURCES[group][2], 'recording': filename,
                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                  'speed': speed, 'max_duration': duration}


def cue(name, layers):
    parts, provenance = [], []
    for group, filename, speed, duration, gain, delay in layers:
        data, source = recording(group, filename, speed, duration)
        start = int(delay * RATE)
        parts.append((start, data * gain))
        source.update(gain=gain, delay=delay)
        provenance.append(source)
    data = np.zeros(max(start + len(part) for start, part in parts))
    for start, part in parts:
        data[start:start + len(part)] += part
    # Tiny attack and a longer release remove edit clicks without softening hits.
    attack, release = min(88, len(data)), min(1323, len(data))
    data[:attack] *= np.linspace(0, 1, attack)
    data[-release:] *= np.linspace(1, 0, release)
    peak, rms = np.max(np.abs(data)), np.sqrt(np.mean(data * data))
    data *= min(0.8 / max(peak, 1e-9), 0.22 / max(rms, 1e-9))
    path = OUT / (name + '.wav')
    sf.write(path, data, RATE, subtype='PCM_16')
    return {'file': 'combat/' + path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'creator': '; '.join(dict.fromkeys(p['creator'] for p in provenance)),
            'source': list(dict.fromkeys(p['source'] for p in provenance)),
            'license': 'CC0-1.0', 'license_file': 'combat/License.txt',
            'modified': True, 'processing': 'tools/build_combat_audio.py', 'inputs': provenance}


def main():
    fetch()
    OUT.mkdir(parents=True, exist_ok=True)
    assets = []
    for variant, swish in enumerate((5, 7, 9), 1):
        assets.append(cue(f'sword_swing_{variant:02}', [
            ('swishes', f'swishes/swish-{swish}.wav', 0.88, 0.24, 1, 0)]))
    for variant in (1, 2):
        v = f'{variant:02}'
        recipes = {
            'cast_aether': [('rpg', f'spell_{v}.ogg', 0.9, 0.55, 1, 0)],
            'cast_fire': [('fireball', 'fireball.wav', 1.1 if variant == 1 else 0.95, 0.65, 1, 0)],
            'cast_ice': [('tinysized', 'sfx-cc0/compressed-air-spray-01.wav', 1.05, 0.42, 0.8, 0),
                         ('tinysized', f'sfx-cc0/wood-twigs-break-{v}.wav', 1.35, 0.3, 0.5, 0.025)],
            'cast_lightning': [('tinysized', 'sfx-cc0/paralyzer-discharge-01.wav', 1.05 if variant == 1 else 0.9, 0.42, 1, 0)],
            'cast_growth': [('tinysized', 'sfx-cc0/chimes-wood-rattle.wav', 0.85 if variant == 1 else 1.05, 0.5, 0.7, 0),
                            ('tinysized', f'sfx-cc0/wood-twigs-break-{v}.wav', 0.8, 0.4, 0.3, 0)],
            'impact_fire': [('rpg', f'spell_fire_{6 if variant == 1 else 7:02}.ogg', 0.85, 0.38, 1, 0)],
            'impact_ice': [('tinysized', f'sfx-cc0/wood-twigs-break-{v}.wav', 1.4, 0.28, 1, 0)],
            'impact_lightning': [('tinysized', 'sfx-cc0/paralyzer-discharge-01.wav', 1.4 if variant == 1 else 1.2, 0.22, 1, 0)],
            'impact_aether': [('rpg', f'spell_{v}.ogg', 0.75, 0.24, 1, 0)],
        }
        for name, layers in recipes.items():
            assets.append(cue(f'{name}_{v}', layers))
    manifest_path = ROOT / 'assets/audio/sources.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['assets'] = [a for a in manifest['assets'] if not a['file'].startswith('combat/')] + assets
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Built {len(assets)} combat recordings')


if __name__ == '__main__':
    main()
