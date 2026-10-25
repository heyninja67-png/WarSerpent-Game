# War Serpent.io v1.2 identity

`warserpent.png` and `icon.png` were created as new original artwork with OpenAI image generation for Emnio on 2026-10-25. No third-party game logo, character, image, or trademark artwork was used as reference input.

The design brief requested an S-curved cybernetic serpent / dragon with titanium armor, a cyan energy core and restrained magenta edges. The logo uses the exact title **WAR SERPENT.IO**, with no subtitle; the icon has no typography to remain legible on an Android launcher. The two generated PNGs were copied directly into the project, without programmatic image editing.

- Logo: 1942 × 809, RGBA with transparent background.
- Android source icon: 1254 × 1254, RGB, opaque midnight background. Engine export creates launcher icon sizes.

`emnio.png`, `emnio_symbol.png` and `emnio_wordmark.png` remain original vector-path-based studio artwork. `tools/generate_assets.py` reproduces those assets and other authored art; it intentionally preserves the image-generated War Serpent logo and icon distributed with the source project.

See `assets/LICENSE.md` for licenses.

## EMNIO GAMES studio mark

`emnio_games.png` is a new original image-generated studio logo created on 2026-10-25 for the same v1.2 update. Its exact wordmark is **EMNIO GAMES** and its emblem is an interlocking chrome EG energy loop with violet, cyan and a small gold facet. The RGBA source measures 1983 × 793. It is copied directly from the generated original without programmatic image editing. This is the primary studio splash mark. Older authored compatibility wordmarks also include GAMES.

The v1.2 lobby and arena use original authored metallic/gold action materials and purple raised floor blocks. These use the architectural ideas of a character-centered action-game lobby and a readable purple arena, without incorporating any graphics or logos from the user's reference games. Version1.2 briefly used newly authored glossy sprite sets. At the user's request, version1.2.1 restores all24 original angular/cyber snake PNGs byte-for-byte from commit e31130e13de1bd6b8ebee193da3f64602aa14b5d. Restricted generator tools/generate_classic_snakes.py reproduces these originals; assets/snakes/RESTORE_PROOF.json records the exact SHA-256 values. Branding, lobby materials and purple arena remain unchanged. No external game image is read or traced.
