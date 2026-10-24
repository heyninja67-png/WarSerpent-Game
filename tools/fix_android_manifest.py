#!/usr/bin/env python3
"""Correct Godot 4.6.3 direct-export AndroidX provider authority, then re-sign.

Godot export_plugin.cpp rewrites every provider authority to .fileprovider.
This narrow AXML edit adds one string and updates only the startup provider's
android:authorities value. All other ZIP entries are retained byte-for-byte
when decompressed. Build helpers then align and sign with a local debug key.
No engine code, source templates, checksums, or signature checks are bypassed.
"""
import argparse
import hashlib
import os
from pathlib import Path
import struct
import tempfile
import zipfile

U32 = lambda b, p: struct.unpack_from('<I', b, p)[0]
ANDROID = 'http://schemas.android.com/apk/res/android'
NONE = 0xffffffff


def decode_pool(chunk):
    header_size = struct.unpack_from('<H', chunk, 2)[0]
    count, styles, flags, start, style_start = struct.unpack_from('<5I', chunk, 8)
    # Godot's Android exporter uses an unstyled UTF-16 string pool.
    if styles or flags & 0x100:
        raise ValueError('Unexpected AXML string-pool format; refusing broad rewrite')
    strings = []
    for n in range(count):
        pos = start + U32(chunk, header_size + n * 4)
        length = struct.unpack_from('<H', chunk, pos)[0]
        pos += 2
        if length & 0x8000:
            length = ((length & 0x7fff) << 16) | struct.unpack_from('<H', chunk, pos)[0]
            pos += 2
        strings.append(bytes(chunk[pos:pos + length * 2]).decode('utf-16le'))
    return strings


def encode_pool(strings):
    raw = bytearray()
    offsets = []
    for value in strings:
        encoded = value.encode('utf-16le')
        length = len(encoded) // 2
        offsets.append(len(raw))
        if length >= 0x8000:
            raw.extend(struct.pack('<HH', 0x8000 | (length >> 16), length & 0xffff))
        else:
            raw.extend(struct.pack('<H', length))
        raw.extend(encoded + b'\0\0')
    while len(raw) % 4:
        raw.append(0)
    start = 28 + len(strings) * 4
    return bytearray(struct.pack('<HHI5I', 1, 28, start + len(raw), len(strings), 0, 0, start, 0)
                     + struct.pack('<' + 'I' * len(offsets), *offsets) + raw)


def parse(xml):
    if len(xml) < 8 or struct.unpack_from('<HH', xml) != (3, 8) or U32(xml, 4) != len(xml):
        raise ValueError('Invalid binary AndroidManifest.xml')
    chunks = []
    pos = 8
    while pos < len(xml):
        kind, header, size = struct.unpack_from('<HHI', xml, pos)
        if size < header or pos + size > len(xml):
            raise ValueError('Invalid binary XML chunk')
        chunks.append(bytearray(xml[pos:pos + size]))
        pos += size
    pools = [i for i, c in enumerate(chunks) if struct.unpack_from('<H', c)[0] == 1]
    if len(pools) != 1:
        raise ValueError('Expected exactly one AXML string pool')
    pool_index = pools[0]
    strings = decode_pool(chunks[pool_index])
    providers = []
    package = None
    for index, chunk in enumerate(chunks):
        if struct.unpack_from('<H', chunk)[0] != 0x102:
            continue
        tag = strings[U32(chunk, 20)]
        attribute_start, attribute_size, attribute_count = struct.unpack_from('<HHH', chunk, 24)
        attrs = {}
        for n in range(attribute_count):
            off = 16 + attribute_start + n * attribute_size
            ns, name, raw, value_size, reserved, data_type, data = struct.unpack_from('<IIIHBBI', chunk, off)
            name = strings[name]
            val = strings[data] if data_type == 3 else data
            attrs[name] = (val, index, off, data_type)
        if tag == 'manifest':
            package = attrs['package'][0]
        if tag == 'provider':
            providers.append(attrs)
    return chunks, strings, pool_index, package, providers


def correct(xml):
    chunks, strings, pool_index, package, providers = parse(xml)
    if package != 'com.emnioggs.warserpent':
        raise ValueError('Unexpected package; refusing to modify unrelated APK')
    startup = [p for p in providers if p.get('name', (None,))[0] == 'androidx.startup.InitializationProvider']
    files = [p for p in providers if p.get('name', (None,))[0] == 'androidx.core.content.FileProvider']
    if len(startup) != 1 or len(files) != 1:
        raise ValueError('Expected exact known Godot AndroidX providers')
    current, chunk_index, offset, data_type = startup[0]['authorities']
    desired = package + '.androidx-startup'
    if current == desired:
        return xml
    if current != package + '.fileprovider' or data_type != 3:
        raise ValueError('Unexpected startup provider authority; manual diagnosis required')
    if files[0]['authorities'][0] != package + '.fileprovider':
        raise ValueError('Unexpected FileProvider authority')
    # Append instead of replacing a string shared by any other manifest field.
    new_index = len(strings)
    strings.append(desired)
    struct.pack_into('<I', chunks[chunk_index], offset + 8, new_index)  # raw string
    struct.pack_into('<I', chunks[chunk_index], offset + 16, new_index)  # typed string
    chunks[pool_index] = encode_pool(strings)
    body = b''.join(chunks)
    result = struct.pack('<HHI', 3, 8, 8 + len(body)) + body
    _, _, _, verified_package, verified = parse(result)
    authorities = [p['authorities'][0] for p in verified]
    if len(authorities) != len(set(authorities)):
        raise ValueError('Duplicate provider authorities remain')
    if desired not in authorities or package + '.fileprovider' not in authorities:
        raise ValueError('Manifest semantic postcondition failed')
    if correct(result) != result:
        raise ValueError('Manifest correction is not idempotent')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.apk) as source:
        if source.testzip() is not None:
            raise ValueError('Invalid source APK ZIP CRC')
        original = source.read('AndroidManifest.xml')
        modified = correct(original)
        if original == modified:
            print('AndroidX authority already correct; no edit')
            return
        original_hashes = {n: hashlib.sha256(source.read(n)).digest()
                           for n in source.namelist() if n != 'AndroidManifest.xml' and not signature(n)}
        with tempfile.NamedTemporaryFile(prefix='manifest-fixed-', suffix='.apk', dir=args.apk.parent, delete=False) as temp:
            dest = Path(temp.name)
        try:
            with zipfile.ZipFile(dest, 'w') as target:
                for entry in source.infolist():
                    if signature(entry.filename):
                        continue
                    target.writestr(entry, modified if entry.filename == 'AndroidManifest.xml' else source.read(entry.filename))
            with zipfile.ZipFile(dest) as target:
                if target.testzip() is not None:
                    raise ValueError('Corrected APK failed ZIP CRC')
                for name, expected in original_hashes.items():
                    if hashlib.sha256(target.read(name)).digest() != expected:
                        raise ValueError('Unrelated APK payload modified: ' + name)
                assert correct(target.read('AndroidManifest.xml')) == target.read('AndroidManifest.xml')
            os.replace(dest, args.apk)
        finally:
            dest.unlink(missing_ok=True)
    print('Corrected AndroidX startup authority; semantic/idempotence/CRC/unrelated-payload checks passed')
    print('APK must now be aligned and re-signed; old signatures intentionally removed')


def signature(name):
    return name.startswith('META-INF/') and (name.endswith(('.RSA', '.DSA', '.EC', '.SF')) or name == 'META-INF/MANIFEST.MF')


if __name__ == '__main__':
    main()
