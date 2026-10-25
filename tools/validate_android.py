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
EXPECTED_VERSION = '1.2.1'
EXPECTED_VERSION_CODE = 4
VERSION_NOTES = 'android_v1_2_1_validation.md'
CLASSIC_REFERENCE_COMMIT = 'e31130e13de1bd6b8ebee193da3f64602aa14b5d'
CLASSIC_HASH_MAP_SHA256 = '42b8818e9679c97343691727e9cb971c948f3561bf07803b6fe512a7a4e03a18'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_classic_sources(evidence):
    """Verify canonical PNG bytes without requiring Git in a source ZIP.

    The pinned hash-map digest was independently derived from git show of the
    full reference commit. The source-distributed restoration proof supplies
    all24 canonical per-file SHA256 values; imported APK pixels are checked
    separately against these byte-verified sources by the Godot resource probe.
    """
    proof_path = ROOT/'assets/snakes/RESTORE_PROOF.json'
    proof = json.loads(proof_path.read_text())
    require(proof.get('reference_commit') == CLASSIC_REFERENCE_COMMIT, 'Wrong classic snake reference commit')
    digests = proof.get('sha256', {})
    expected_paths = {'assets/snakes/'+part+'_'+str(skin)+'.png' for skin in range(8) for part in ['head','body','tail']}
    require(set(digests) == expected_paths, 'Classic restoration must cover all24 PNG files')
    canonical = json.dumps(digests, sort_keys=True, separators=(',',':')).encode()
    require(hashlib.sha256(canonical).hexdigest() == CLASSIC_HASH_MAP_SHA256, 'Classic source hash manifest differs from independently pinned reference')
    for path, expected in sorted(digests.items()):
        actual = hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
        require(actual == expected, 'Classic snake source differs from reference: '+path)
        evidence.append('Classic reference PNG SHA256 verified '+actual+' '+path+'\n')
    evidence.append('All24 classic PNG files byte-exact to reference '+CLASSIC_REFERENCE_COMMIT+'; canonical manifest SHA256 '+CLASSIC_HASH_MAP_SHA256+'\n')
    return proof_path


def inspect_packaged_game(z, godot, command, evidence):
    """Load compiled game resources from this APK with matching desktop Godot.

    This verifies the packed settings/resources/code; it is not Android execution.
    No app scene is attached to the tree, so no profile is read/written and no
    network connections or game services are started.
    """
    count = struct.unpack_from('<I', z.read('assets/_cl_'))[0]
    raw = z.read('assets/_cl_')
    offset = 4
    argv = []
    require(count < 128, 'Invalid packaged argument count')
    for _ in range(count):
        require(offset + 4 <= len(raw), 'Truncated packaged command line')
        length = struct.unpack_from('<I', raw, offset)[0]
        offset += 4
        require(offset + length <= len(raw), 'Invalid packaged argument length')
        argv.append(raw[offset:offset + length].decode('utf-8'))
        offset += length
    require(offset == len(raw), 'Trailing packaged command-line data')
    require('--fullscreen' in argv and '--edge_to_edge' in argv, 'Immersive/edge-to-edge runtime flags missing')
    require('--remote-debug' not in argv, 'Unexpected debug connection in release APK')
    evidence.append('Packaged Android runtime arguments: ' + json.dumps(argv) + '\n')
    with tempfile.TemporaryDirectory(prefix='warserpent-apk-resources-') as directory:
        root = Path(directory)
        bundle = root/'bundle'
        bundle.mkdir()
        for name in z.namelist():
            if not name.startswith('assets/') or name.endswith('/'):
                continue
            target = (bundle/name[7:]).resolve()
            require(target.is_relative_to(bundle), 'Unsafe APK asset path')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(name))
        icons = []
        for name in z.namelist():
            if 'icon_foreground' in name and name.endswith(('.webp', '.png')):
                target = root/name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(z.read(name))
                icons.append(str(target))
        require(len(icons) == 6, 'Expected six native adaptive foreground densities')
        script = root/'check_packaged_game.gd'
        gdscript = '''extends SceneTree
var checks := 0
var failures := 0
func verify(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 verify(ProjectSettings.get_setting("application/config/version") == __EXPECTED_VERSION__, "Packed game version")
 verify(ProjectSettings.get_setting("application/boot_splash/show_image",true) == false, "Default Godot boot image disabled")
 verify(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Full viewport aspect expansion")
 verify(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "Mobile GL renderer")
 var scene = load("res://scenes/Main.tscn")
 verify(scene is PackedScene, "Compiled main scene load")
 var app = scene.instantiate()
 app.profile.data.settings.music = false
 app.music = AudioStreamPlayer.new()
 app.add_child(app.music)
 var audio_details := {}
 for track in ["menu","arena"]:
  app.set_music_track(track)
  var stream = app.music.stream
  verify(stream is AudioStreamOggVorbis, "Packaged OGG resource " + track)
  verify(stream.loop, "Compiled game method enables loop " + track)
  verify(stream.get_length() > 40.0, "Music duration " + track)
  var playback = stream.instantiate_playback()
  playback.start()
  var pcm = playback.mix_audio(1.0,8192)
  var peak := 0.0
  var finite := true
  for sample in pcm:
   finite = finite and is_finite(sample.x) and is_finite(sample.y)
   peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
  verify(finite, "Finite decoded music samples " + track)
  verify(peak > 0.0001, "Packaged music contains non-silent PCM " + track)
  audio_details[track] = {"duration":stream.get_length(),"loop":stream.loop,"decoded_peak":peak}
  playback.stop()
 for skin in range(8):
  for part in ["head","body","tail"]:
   var texture = load("res://assets/snakes/%s_%d.png" % [part,skin])
   verify(texture is Texture2D and texture.get_width() > 0, "Packaged snake texture")
  verify(load("res://assets/icons/ability_%d.png" % skin) is Texture2D, "Packaged ability texture")
 var network = load("res://scripts/network/OnlineArena.gd")
 verify(network != null and network.can_instantiate(), "Compiled multiplayer script load")
 var room = network.new()
 verify(room.has_method("cache_host_address"), "Latest compiled host address cache")
 room.room_port = 24680
 room.cache_host_address()
 verify(room.host_connection_hint.contains("24680"), "Compiled host HUD hint contains actual UDP port")
 verify(room.valid_lan_ipv4("192.168.1.42") and not room.valid_lan_ipv4("127.0.0.1"), "Compiled host LAN address selection")
 print("PACKAGED_HOST_HINT=",room.host_connection_hint)
 room.free()
 verify(load("res://assets/effects/energy.png") is Texture2D, "Packaged new energy sprite")
 var original_icon = Image.load_from_file(__SOURCE_ICON__)
 var native_paths = __NATIVE_ICONS__
 for path in native_paths:
  var native = Image.load_from_file(path)
  var expected = original_icon.duplicate()
  expected.resize(native.get_width(),native.get_height(),Image.INTERPOLATE_LANCZOS)
  expected.convert(Image.FORMAT_RGBA8)
  native.convert(Image.FORMAT_RGBA8)
  verify(expected.get_data() == native.get_data(), "Native adaptive foreground is custom app artwork")
 var latin_text := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
 for font_name in ["Body","Display"]:
  var packed_font = load("res://assets/fonts/%s.ttf" % font_name)
  verify(packed_font is Font, "Packed font load " + font_name)
  var english_supported := packed_font is Font
  if packed_font is Font:
   for index in range(latin_text.length()):
    english_supported = english_supported and packed_font.has_char(latin_text.unicode_at(index))
  verify(english_supported, "Packed font English glyph coverage " + font_name)
 var branding_details := {}
 for entry in __BRANDING_SOURCES__:
  var packed_texture = load(entry.resource)
  var actual = packed_texture.get_image() if packed_texture is Texture2D else null
  var expected = Image.load_from_file(entry.source)
  verify(actual is Image and not expected.is_empty(), "Packed branding image decode " + entry.label)
  if actual == null or expected.is_empty():
   continue
  verify(actual.get_size() == expected.get_size(), "Packed branding source dimensions " + entry.label)
  actual.convert(Image.FORMAT_RGBA8)
  expected.convert(Image.FORMAT_RGBA8)
  expected.fix_alpha_edges()
  verify(actual.get_data() == expected.get_data(), "Packed branding pixels equal current source after importer alpha fix " + entry.label)
  var digest = HashingContext.new()
  digest.start(HashingContext.HASH_SHA256)
  digest.update(actual.get_data())
  branding_details[entry.label] = {"width":actual.get_width(),"height":actual.get_height(),"pixel_sha256":digest.finish().hex_encode()}
 app.free()
 print("PACKAGED_BRANDING=",JSON.stringify(branding_details))
 print("PACKAGED_GAME_RESOURCE_CHECKS=",checks," FAILURES=",failures)
 print("PACKAGED_MUSIC=",JSON.stringify(audio_details))
 print("PACKAGED_ENGINE_BOOT_IMAGE=false; ASPECT=expand; NATIVE_CUSTOM_ICON_DENSITIES=",native_paths.size())
 quit(1 if failures else 0)
'''
        branding_sources = [
            {'label':'logo','resource':'res://assets/branding/warserpent.png','source':str(ROOT/'assets/branding/warserpent.png')},
            {'label':'icon','resource':'res://assets/branding/icon.png','source':str(ROOT/'assets/branding/icon.png')},
            {'label':'studio','resource':'res://assets/branding/emnio_games.png','source':str(ROOT/'assets/branding/emnio_games.png')},
            {'label':'arena_floor','resource':'res://assets/arenas/neon_city.png','source':str(ROOT/'assets/arenas/neon_city.png')},
        ]
        for skin in range(8):
            for part in ['head','body','tail']:
                path = 'assets/snakes/'+part+'_'+str(skin)+'.png'
                branding_sources.append({'label':'skin_'+str(skin)+'_'+part,'resource':'res://'+path,'source':str(ROOT/path)})
        gdscript = gdscript.replace('__BRANDING_SOURCES__', json.dumps(branding_sources))
        gdscript = gdscript.replace('__EXPECTED_VERSION__', json.dumps(EXPECTED_VERSION))
        gdscript = gdscript.replace('__SOURCE_ICON__', json.dumps(str(ROOT/'assets/branding/icon.png')))
        gdscript = gdscript.replace('__NATIVE_ICONS__', json.dumps(icons))
        script.write_text(gdscript)
        env = os.environ.copy()
        env['XDG_CONFIG_HOME'] = str(root/'config')
        env['XDG_DATA_HOME'] = str(root/'data')
        env['XDG_CACHE_HOME'] = str(root/'cache')
        output = command([godot, '--headless', '--path', bundle, '--script', script], env=env)
        require('SCRIPT ERROR:' not in output and 'ERROR:' not in output, 'Packed resource runner reported errors')
        require('FAILURES=0' in output, 'Packed resource assertions failed')
        check_match = re.search(r'PACKAGED_GAME_RESOURCE_CHECKS=(\d+) FAILURES=0',output)
        require(check_match is not None, 'Resource check count missing')
        branding_match = re.search(r'PACKAGED_BRANDING=(.+)',output)
        require(branding_match is not None, 'Branding pixel evidence missing')
        report = {'checks':int(check_match.group(1)),'branding':json.loads(branding_match.group(1))}
    return argv, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path, nargs='?', default=ROOT/'builds/WarSerpentIO-debug.apk')
    parser.add_argument('--sdk', type=Path, default=Path(os.environ.get('ANDROID_HOME', '/workspace/toolchains/android-sdk')))
    parser.add_argument('--build-tools', default='35.0.1')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--release-template', type=Path, default=Path(os.environ.get('XDG_DATA_HOME','/workspace/.local/share'))/'godot/export_templates/4.6.3.stable/android_release.apk')
    args = parser.parse_args()
    apk = args.apk.resolve()
    sdk = args.sdk/'build-tools'/args.build_tools
    evidence = []
    classic_proof_path = verify_classic_sources(evidence)

    def command(argv, env=None):
        result = subprocess.run(list(map(str, argv)), capture_output=True, text=True, env=env, timeout=90)
        evidence.append('$ ' + ' '.join(map(str, argv)) + '\n' + result.stdout + result.stderr + '\nexit=' + str(result.returncode) + '\n')
        require(result.returncode == 0, 'Command failed: ' + str(argv))
        return result.stdout

    signature = command([sdk/'apksigner', 'verify', '--verbose', '--print-certs', apk])
    require('Verified using v2 scheme (APK Signature Scheme v2): true' in signature, 'APK v2 signature invalid')
    require('Verified using v3 scheme (APK Signature Scheme v3): true' in signature, 'APK v3 signature invalid')
    cert_match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', signature)
    require(cert_match is not None, 'No signer certificate digest found')
    require(cert_match.group(1) == os.environ.get('WARSERPENT_EXPECTED_CERT_SHA256','5764b2c60e35c535276fccf3e112de4f5d5f991c6512f8b584624743d61db620'), 'Signing key differs from installed v1.0.0; update would fail')
    badging = command([sdk/'aapt', 'dump', 'badging', apk])
    require("name='com.emnioggs.warserpent'" in badging, 'Wrong APK package')
    require(f"versionCode='{EXPECTED_VERSION_CODE}'" in badging and f"versionName='{EXPECTED_VERSION}'" in badging, 'Wrong APK version')
    require("sdkVersion:'24'" in badging and "targetSdkVersion:'36'" in badging, 'Unexpected API levels')
    require("native-code: 'arm64-v8a' 'armeabi-v7a'" in badging, 'Missing native ABIs')
    require('application-debuggable' not in badging, 'Optimized build must not be debuggable')
    manifest = command([sdk/'aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml'])
    require('android:screenOrientation(0x0101001e)=(type 0x10)0x0' in manifest, 'Landscape orientation missing')
    permissions = re.findall(r'E: uses-permission[^\n]*\n\s+A: android:name[^\n]*?="([^"]+)"', manifest)
    require(set(permissions) == {'android.permission.INTERNET'}, 'Unexpected permission set: '+repr(permissions))
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
        for resource in ['assets/scripts/ui/Main.gdc', 'assets/scripts/ui/MenuAtmosphere.gdc', 'assets/scripts/ui/LobbyPlatform.gdc',
                         'assets/scripts/ui/SerpentPreview.gdc', 'assets/scripts/gameplay/ArenaGame.gdc',
                         'assets/scripts/core/Profile.gdc', 'assets/scripts/movement/snake_model.gdc',
                         'assets/scripts/bots/arena_brain.gdc', 'assets/scripts/gameplay/spatial_hash.gdc',
                         'classes.dex', 'resources.arsc']:
            require(z.getinfo(resource).file_size > 0, 'Missing executable/resource: ' + resource)
        require(z.read('assets/assets/snakes/RESTORE_PROOF.json') == classic_proof_path.read_bytes(), 'Classic restoration proof missing or changed inside APK')
        require(json.loads(z.read('assets/data/catalog.json')) == json.loads((ROOT/'data/catalog.json').read_text()), 'Catalog differs from source')
        require(z.read('assets/assets/fonts/LICENSE-DejaVu.txt') == (ROOT/'assets/fonts/LICENSE-DejaVu.txt').read_bytes(), 'Font notice missing or differs from source')
        require(any(n.endswith('Main.scn') for n in names), 'Compiled main scene missing')
        require(len(json.loads(z.read('assets/data/catalog.json'))) == 8, 'Expected eight playable skins')
        for track in ['music_menu', 'music_arena']:
            require(any(track in n for n in names), 'Missing background music: '+track)
        require('assets/scripts/network/OnlineArena.gdc' in names, 'Real multiplayer code missing')
        packed_argv, packaged_report = inspect_packaged_game(z,args.godot,command,evidence)
        native = []
        require(args.release_template.is_file(), 'Verified release template missing')
        with zipfile.ZipFile(args.release_template) as reference, tempfile.TemporaryDirectory(prefix='warserpent-elf-') as tmp:
            for name in names:
                if not name.endswith('.so'):
                    continue
                lib = Path(tmp)/name
                lib.parent.mkdir(parents=True, exist_ok=True)
                payload = z.read(name)
                require(hashlib.sha256(payload).digest() == hashlib.sha256(reference.read(name)).digest(), 'Native payload does not match official release template: '+name)
                evidence.append('Official release-template native payload verified SHA256 '+hashlib.sha256(payload).hexdigest()+' '+name+'\n')
                lib.write_bytes(payload)
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
and independently validated after v1.2.1 classic-snake restoration/UI fixes and animation changes; same signing certificate as prior versions.
Source Main.gd SHA256: {hashlib.sha256((ROOT/'scripts/ui/Main.gd').read_bytes()).hexdigest()}
Source ArenaGame.gd SHA256: {hashlib.sha256((ROOT/'scripts/gameplay/ArenaGame.gd').read_bytes()).hexdigest()}
Source OnlineArena.gd SHA256: {hashlib.sha256((ROOT/'scripts/network/OnlineArena.gd').read_bytes()).hexdigest()}
Source MenuAtmosphere.gd SHA256: {hashlib.sha256((ROOT/'scripts/ui/MenuAtmosphere.gd').read_bytes()).hexdigest()}
Source LobbyPlatform.gd SHA256: {hashlib.sha256((ROOT/'scripts/ui/LobbyPlatform.gd').read_bytes()).hexdigest()}
Source SerpentPreview.gd SHA256: {hashlib.sha256((ROOT/'scripts/ui/SerpentPreview.gd').read_bytes()).hexdigest()}
Source logo PNG SHA256: {hashlib.sha256((ROOT/'assets/branding/warserpent.png').read_bytes()).hexdigest()}
Source icon PNG SHA256: {hashlib.sha256((ROOT/'assets/branding/icon.png').read_bytes()).hexdigest()}
Source Emnio Games PNG SHA256: {hashlib.sha256((ROOT/'assets/branding/emnio_games.png').read_bytes()).hexdigest()}

Manifest (aapt badging+xmltree, exit0):
- package com.emnioggs.warserpent; label War Serpent.io; v{EXPECTED_VERSION}/code{EXPECTED_VERSION_CODE}.
- min API24, target/compile API36, landscape0, release-template build (debuggable=false).
- same development signing identity as v1.0; filename retained for download compatibility.
- OpenGL ES3, GL Compatibility renderer; INTERNET permission for real direct multiplayer; no camera/microphone/storage permissions.
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
- four native libraries for ARM64 and ARMv7 present with actual ELF headers;
  every payload SHA256 matches the verified official RELEASE template byte-for-byte.
- compiled Main.scn, Main.gdc, ArenaGame.gdc, Profile.gdc, snake_model.gdc,
  arena_brain.gdc, spatial_hash.gdc, MenuAtmosphere.gdc, LobbyPlatform.gdc and SerpentPreview.gdc packaged.
- data/catalog.json parsed and exactly matches source JSON; eight skins.
- {assets} packaged Godot asset resources, including {imports} imported assets.
- snake/UI/branding texture and audio resources included.
- {packaged_report['checks']} actual packaged-resource assertions passed.
- all24 classic PNG source files are byte-exact to commit {CLASSIC_REFERENCE_COMMIT};
  canonical SHA256 hash-map pin: {CLASSIC_HASH_MAP_SHA256}.
- packed War Serpent logo, app icon, Emnio Games studio logo, purple arena floor
  and all24 restored classic head/body/tail sprite files reconstructed to RGBA8 match current
  source pixels exactly after importer alpha-edge fix; detects stale art.
- decoded logo: {packaged_report['branding']['logo']};
  decoded icon: {packaged_report['branding']['icon']};
  decoded Emnio Games: {packaged_report['branding']['studio']}.
- both packed fonts load and cover English upper/lowercase letters and digits.
- actual packed project.binary: boot_splash/show_image=false, viewport aspect=expand.
- actual Android runtime arguments include --fullscreen and --edge_to_edge.
- all six native adaptive foreground densities exactly match the original custom icon
  after the engine resize; default Godot icon is not used for this native splash.
- compiled Main set_music_track method enables looping for both packed OGG streams;
  each track decodes >40seconds, finite non-silent PCM verified on desktop Godot.
- compiled Main scene, eight snake sprite triplets/icons and OnlineArena resource load.
- Android12+ system app-icon splash remains OS-managed; actual timing/cutouts untested.
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
- release-template selection alone does not establish measured FPS improvements.
'''
    (ROOT/'builds/AndroidManifest.xmltree.txt').write_text(manifest)
    (ROOT/'docs/apk_validation.txt').write_text(summary)
    (ROOT/'docs/apk_validation_details.txt').write_text('\n'.join(evidence))
    notes_path = ROOT/'docs'/VERSION_NOTES
    if notes_path.is_file():
        notes = notes_path.read_text()
        notes = re.sub(r'^\| APK bytes \|.*$', lambda _: '| APK bytes | `'+str(apk.stat().st_size)+'` ('+format(apk.stat().st_size/1024/1024,'.2f')+'MiB) |', notes, flags=re.M)
        notes = re.sub(r'^\| APK SHA256 \|.*$', lambda _: '| APK SHA256 | `'+sha+'` |', notes, flags=re.M)
        notes_path.write_text(notes)
    print(summary)
    print('Packaged Android runtime flags: '+json.dumps(packed_argv))


if __name__ == '__main__':
    main()
