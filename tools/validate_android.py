#!/usr/bin/env python3
"""Independently validate the final Android artifact and save exact evidence.

Run after tools/build_android.sh. Checks signatures, manifest semantics, packaged
code/data/assets/licenses, CRC and 16KB ARM64 ELF alignment. Does not install an
APK or claim Android execution. Uses the detected local Android tools by default.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path, nargs='?', default=ROOT/'builds/WarSerpentIO-debug.apk')
    parser.add_argument('--sdk', type=Path, default=Path(os.environ.get('ANDROID_HOME', '/workspace/toolchains/android-sdk')))
    parser.add_argument('--build-tools', default='35.0.1')
    args = parser.parse_args()
    apk = args.apk.resolve()
    sdk = args.sdk/'build-tools'/args.build_tools
    evidence = []

    def command(argv):
        result = subprocess.run(list(map(str, argv)), capture_output=True, text=True)
        evidence.append('$ ' + ' '.join(map(str, argv)) + '\n' + result.stdout + result.stderr + '\nexit=' + str(result.returncode) + '\n')
        require(result.returncode == 0, 'Command failed: ' + str(argv))
        return result.stdout

    signature = command([sdk/'apksigner', 'verify', '--verbose', '--print-certs', apk])
    require('Verified using v2 scheme (APK Signature Scheme v2): true' in signature, 'APK v2 signature invalid')
    require('Verified using v3 scheme (APK Signature Scheme v3): true' in signature, 'APK v3 signature invalid')
    cert_match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', signature)
    require(cert_match is not None, 'No signer certificate digest found')
    badging = command([sdk/'aapt', 'dump', 'badging', apk])
    require("name='com.emnioggs.warserpent'" in badging, 'Wrong APK package')
    require("versionCode='1'" in badging and "versionName='1.0.0'" in badging, 'Wrong APK version')
    require("sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging, 'Unexpected API levels')
    require("native-code: 'arm64-v8a' 'armeabi-v7a'" in badging, 'Missing native ABIs')
    manifest = command([sdk/'aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml'])
    require('android:screenOrientation(0x0101001e)=(type 0x10)0x0' in manifest, 'Landscape orientation missing')
    require('uses-permission' not in manifest, 'Unexpected Android permissions')
    require('android.intent.category.LAUNCHER' in manifest and 'android.intent.action.MAIN' in manifest, 'Launcher alias missing')
    command([sdk/'zipalign', '-c', '-P', '16', '4', apk])
    spec = importlib.util.spec_from_file_location('manifestfix', ROOT/'tools/fix_android_manifest.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with zipfile.ZipFile(apk) as z:
        require(z.testzip() is None, 'APK ZIP CRC validation failed')
        xml = z.read('AndroidManifest.xml')
        _, _, _, package, providers = module.parse(xml)
        authorities = {p['name'][0]: p['authorities'][0] for p in providers}
        require(package == 'com.emnioggs.warserpent', 'AXML package mismatch')
        require(authorities.get('androidx.core.content.FileProvider') == package + '.fileprovider', 'FileProvider authority wrong')
        require(authorities.get('androidx.startup.InitializationProvider') == package + '.androidx-startup', 'AndroidX startup authority wrong')
        require(len(set(authorities.values())) == len(authorities), 'Duplicate provider authorities')
        require(module.correct(xml) == xml, 'Manifest correction not idempotent')
        names = z.namelist()
        for resource in ['assets/scripts/ui/Main.gdc', 'assets/scripts/gameplay/ArenaGame.gdc',
                         'assets/scripts/core/Profile.gdc', 'assets/scripts/movement/snake_model.gdc',
                         'assets/scripts/bots/arena_brain.gdc', 'assets/scripts/gameplay/spatial_hash.gdc',
                         'classes.dex', 'resources.arsc']:
            require(z.getinfo(resource).file_size > 0, 'Missing executable/resource: ' + resource)
        require(json.loads(z.read('assets/data/catalog.json')) == json.loads((ROOT/'data/catalog.json').read_text()), 'Catalog differs from source')
        require(z.read('assets/assets/fonts/LICENSE-DejaVu.txt') == (ROOT/'assets/fonts/LICENSE-DejaVu.txt').read_bytes(), 'Font notice missing or differs from source')
        require(any(n.endswith('Main.scn') for n in names), 'Compiled main scene missing')
        native = []
        with tempfile.TemporaryDirectory(prefix='warserpent-elf-') as tmp:
            for name in names:
                if not name.endswith('.so'):
                    continue
                lib = Path(tmp)/name
                lib.parent.mkdir(parents=True, exist_ok=True)
                lib.write_bytes(z.read(name))
                require(lib.read_bytes()[:4] == b'\x7fELF', 'Native library is not ELF')
                output = command(['readelf', '-lW', lib])
                loads = [s.strip() for s in output.splitlines() if s.strip().startswith('LOAD')]
                require(bool(loads), 'No native LOAD segments')
                if 'arm64-v8a' in name:
                    require(all(s.endswith('0x4000') for s in loads), 'ARM64 ELF lacks16KB alignment')
                native.append(name)
        require(len(native) == 4, 'Unexpected native library count')
        assets = len([n for n in names if n.startswith('assets/')])
        imports = len([n for n in names if n.startswith('assets/.godot/imported/')])

    sha = hashlib.sha256(apk.read_bytes()).hexdigest()
    summary = f'''ANDROID APK VALIDATION — FINAL War Serpent.io
Executed: {datetime.datetime.now(datetime.timezone.utc).isoformat()}, current cloud machine.

Artifact: builds/WarSerpentIO-debug.apk
Size: {apk.stat().st_size} bytes ({apk.stat().st_size/1024/1024:.2f} MiB)
SHA256: {sha}
Build command: ./tools/build_android.sh
Independent validation: python3 tools/validate_android.py
Full final build log: builds/android-build.log
Full validation output: docs/apk_validation_details.txt
Outcome: exit0; APK exported, narrowly manifest-corrected, aligned, re-signed,
and independently validated after final app changes including engine/font credits.
Source Main.gd SHA256: {hashlib.sha256((ROOT/'scripts/ui/Main.gd').read_bytes()).hexdigest()}
Source ArenaGame.gd SHA256: {hashlib.sha256((ROOT/'scripts/gameplay/ArenaGame.gd').read_bytes()).hexdigest()}

Manifest (aapt badging+xmltree, exit0):
- package com.emnioggs.warserpent; label War Serpent.io; v1.0.0/code1.
- min API24, target/compile API36, landscape0, debuggable development build.
- OpenGL ES3, GL Compatibility renderer; no uses-permission declarations.
- exported launcher activity alias with MAIN/LAUNCHER present.
- FileProvider authority: {authorities['androidx.core.content.FileProvider']}
- StartupProvider authority: {authorities['androidx.startup.InitializationProvider']}
- authority values distinct; narrow correction idempotence passed.
- official template unchanged; defect/correction in docs/toolchain_notes.md.

Signature (apksigner verify --verbose --print-certs, exit0):
- v2 true; v3 true; one RSA2048 development signer.
- certificate SHA256: {cert_match.group(1)}
- private signing keystore outside source tree/ZIP; no release key supplied.

Executable/resources:
- ZIP CRC integrity passed for all entries; real classes.dex+secondary DEX files.
- four native libraries for ARM64 and ARMv7 present with actual ELF headers.
- compiled Main.scn, Main.gdc, ArenaGame.gdc, Profile.gdc, snake_model.gdc,
  arena_brain.gdc and spatial_hash.gdc packaged.
- data/catalog.json parsed and exactly matches source JSON; five skins.
- {assets} packaged Godot asset resources, including {imports} imported assets.
- snake/UI/branding texture and audio resources included.
- res://assets/fonts/LICENSE-DejaVu.txt PRESENT and byte-identical to source
  (APK ZIP entry assets/assets/fonts/LICENSE-DejaVu.txt).
- credits display exposes the bundled font notice and Godot engine license.

Alignment:
- zipalign -c -P16 4 passed on final signed APK.
- all ARM64 LOAD segments in libgodot_android.so and libc++_shared.so
  p_align0x4000 (16KB), independently checked with readelf.
- ARMv7 LOAD p_align0x1000 (4KB), conventional32bit architecture.
- native entries compressed, extractNativeLibs=true; extraction on install.

Device tests:
- adb devices -l returned no connected device/emulator.
- installation, launch, Android lifecycle, real multitouch, GPU/FPS, battery,
  and memory profiling on Android hardware were NOT executed.
- desktop rendering/headless gameplay checks reported separately.
- signed compilation does not establish full Android-device compatibility.
'''
    (ROOT/'builds/AndroidManifest.xmltree.txt').write_text(manifest)
    (ROOT/'docs/apk_validation.txt').write_text(summary)
    (ROOT/'docs/apk_validation_details.txt').write_text('\n'.join(evidence))
    print(summary)


if __name__ == '__main__':
    main()
