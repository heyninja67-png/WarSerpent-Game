# Local desktop-rendered validation

Xvfb was initially absent. For actual Godot rendering checks, Debian's `xvfb` package `2:21.1.16-1.3+deb13u3` was downloaded using the system APT client with a local writable configuration/state and the official `https://deb.debian.org/debian trixie main` repository. The repository uses `signed-by=/usr/share/keyrings/debian-archive-keyring.gpg`; APT signature and package hash verification remained enabled. The package was extracted locally, not installed globally.

- Local executable: `/workspace/toolchains/xvfb/usr/bin/Xvfb`
- Package SHA-256: `365da2b6c93339f34337c434a9489bb6411a240fa47b9f49693d3091745f28c2`
- Display: `:99`, 1280×720, depth 24.
- X.Org server: 21.1.16, confirmed with `xdpyinfo`.
- All required shared libraries were already available; `ldd` reported no missing libraries.
- Startup helper `tools/start_display.sh` was executed successfully and detects an existing ready display.

Use:

```sh
./tools/start_display.sh
DISPLAY=:99 XDG_CONFIG_HOME=/workspace/.config XDG_DATA_HOME=/workspace/.local/share XDG_CACHE_HOME=/workspace/.cache godot --path .
```

The server listens only on local Unix sockets (`-nolisten tcp`). It allows local connections for the isolated development container (`-ac`). This helper provides desktop rendering; it does not simulate Android hardware, drivers, lifecycle, or touch input. An Android execution test must be reported separately.
