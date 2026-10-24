#!/usr/bin/env python3
"""Install only missing local Android SDK archives, verified against Google's XML.

Uses HTTPS certificate validation and Google's SHA-1 archive checksums from
repository2-1.xml (the checksum algorithm currently published by Google).
No global paths are changed. ANDROID_HOME overrides the default local SDK path.
"""
import concurrent.futures
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SDK = Path(os.environ.get('ANDROID_HOME', '/workspace/toolchains/android-sdk'))
CACHE = Path(os.environ.get('WARSERPENT_DOWNLOAD_CACHE', '/workspace/toolchains/downloads'))
BASE = 'https://dl.google.com/android/repository/'
PACKAGES = {
    'build-tools;35.0.1': ('build-tools_r35.0.1_linux.zip', 'e009a9b188cfeb1d2b4c318ab5cb4f1ddc368861', 'build-tools/35.0.1'),
    'platforms;android-35': ('platform-35_r02.zip', '0bb560a90a7a2cbd0dd8348224d518b638fe7949', 'platforms/android-35'),
    'platform-tools': ('platform-tools_r37.0.1-linux.zip', '477254aa5f903c15cf51001717bdf347fb6b53e0', 'platform-tools'),
}

def fetch(url, path):
    req = urllib.request.Request(url, headers={'User-Agent':'WarSerpentIO-build/1.0'})
    with urllib.request.urlopen(req, timeout=90) as response, path.open('wb') as out:
        shutil.copyfileobj(response, out)

def install(item):
    name, (archive, expected, dest) = item
    dest = SDK / dest
    if (dest / 'source.properties').exists():
        print(f'{name}: already installed at {dest}', flush=True)
        return
    file = CACHE / archive
    if not file.exists() or hashlib.sha1(file.read_bytes()).hexdigest() != expected:
        fetch(BASE + archive, file)
    actual = hashlib.sha1(file.read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError(f'{archive}: checksum mismatch; not extracting')
    print(f'{archive}: verified SHA-1 {actual}; SHA-256 {hashlib.sha256(file.read_bytes()).hexdigest()}', flush=True)
    with tempfile.TemporaryDirectory(prefix='sdk-', dir=CACHE) as tmp:
        with zipfile.ZipFile(file) as zipped:
            for entry in zipped.infolist():
                target = Path(tmp, entry.filename).resolve()
                if not target.is_relative_to(Path(tmp).resolve()):
                    raise RuntimeError('Unsafe archive path')
                zipped.extract(entry, tmp)
                mode = entry.external_attr >> 16
                if mode:
                    os.chmod(target, mode)
        roots = list(Path(tmp).iterdir())
        if len(roots) != 1:
            raise RuntimeError(f'Unexpected archive layout: {archive}')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(roots[0]), str(dest))
    print(f'{name}: installed at {dest}', flush=True)

if __name__ == '__main__':
    CACHE.mkdir(parents=True, exist_ok=True)
    SDK.mkdir(parents=True, exist_ok=True)
    xml = CACHE / 'android-repository2-1.xml'
    fetch(BASE + 'repository2-1.xml', xml)
    official = ET.parse(xml).getroot()
    for name, (archive, checksum, _) in PACKAGES.items():
        matches = [p for p in official.findall('remotePackage') if p.get('path') == name]
        if not any(a.findtext('url') == archive and a.findtext('checksum') == checksum
                   for p in matches for a in p.findall('archives/archive/complete')):
            raise RuntimeError(f'Pinned official checksum no longer available for {name}; review metadata instead of bypassing validation')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(install, PACKAGES.items()))
    print(f'ANDROID_HOME={SDK}')
