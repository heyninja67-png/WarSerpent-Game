# Original cyber snake artwork

Version 1.2.1 restores the eight original angular cyber snake sets from the v1.1 source commit `e31130e13de1bd6b8ebee193da3f64602aa14b5d`, as requested by the user. All 24 PNG files match those original files byte for byte.

Run `python3 tools/generate_classic_snakes.py` from the repository root to reproduce only these snake PNGs. The compatibility command `python3 tools/generate_snake_sprites.py` invokes the same original generator. The main `tools/generate_assets.py` now uses the classic generator too; it no longer selects the superseded glossy artwork.

`SHA256SUMS` contains the reference SHA-256 digests. `RESTORE_PROOF.json` records the verification: two generator runs and the compatibility entry point each matched all 24 reference hashes; the other 50 PNG assets were unchanged during restoration. The restoration preserves the current EMNIO GAMES mark, War Serpent.io logo and icon, gold lobby materials and purple arena floor.

These original authored sprites remain CC0; see `assets/LICENSE.md`.
