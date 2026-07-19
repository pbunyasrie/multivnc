# MultiVNC — local Windows build notes

This is a clone of https://github.com/bk138/multivnc (upstream default branch: `master`).
It is built locally because upstream publishes no current Windows binaries (releases
only contain Android APKs; CI produces Debug-only artifacts behind a GitHub login).

Purpose: VNC viewer that supports Apple's Diffie-Hellman auth (security type 30),
so it can connect to macOS Screen Sharing with a Mac username/password — which
TightVNC/TigerVNC/UltraVNC cannot.

## Toolchain (installed 2026-07 via winget/pip)

- Visual Studio 2022 Build Tools, C++ workload (`Microsoft.VisualStudio.2022.BuildTools`)
- CMake (`Kitware.CMake`), at `C:\Program Files\CMake\bin\cmake.exe`
- Python 3.12 (`Python.Python.3.12`), per-user install at
  `%LOCALAPPDATA%\Programs\Python\Python312`
- Conan 2.x (`python -m pip install --user conan`); conan.exe lands in
  `%LOCALAPPDATA%\Programs\Python\Python312\Scripts` (not on PATH)

Conan default profile: msvc 194, x86_64, Release, dynamic runtime
(`conan profile detect` — already done, stored in `~/.conan2/profiles/default`).

Toolchain setup is automated: `install-toolchain.ps1` installs any missing
component via winget/pip (idempotent; VS Build Tools is ~3 GB and may show UAC
prompts). `build-windows.ps1` calls it automatically when a tool is missing.

## Building

Run `.\build-windows.ps1` from the repo root. It does, in order:

1. `git submodule update --init libsshtunnel libvncserver libwxservdisc`
   (the `android/*` submodules are not needed for the desktop build)
2. `conan install . --output-folder=build --build=missing -s build_type=Release`
   (all deps come prebuilt from ConanCenter: wxWidgets, OpenSSL, libssh2,
   libjpeg-turbo, libtiff, zlib, gettext)
3. CMake configure with `-DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake`
   (generator: Visual Studio 17 2022)
4. `cmake --build build --config Release`
5. `cmake --install build --config Release --prefix dist`

## Gotchas

- **Do not run the exe from `build\src\Release` directly.** The app resolves its
  toolbar SVGs via `wxStandardPaths::GetResourcesDir()`, and wxWidgets strips
  build-dir names like `Release` from the path, so icons fail to load. The
  installed layout in `dist\` (exe with `light/`, `dark/`, `*.svg` beside it)
  is the runnable, portable package — copy the whole folder to relocate it.
- When passing `-DFOO=bar.baz` args to cmake in PowerShell, quote them
  (`"-DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake"`), otherwise PowerShell
  splits on the dot.
- `build/` and `dist/` are ignored via `.git/info/exclude` (not committed).

## Connecting to macOS

Enter the Mac's address (or use the Bonjour "Discovered Servers" pane), port 5900.
At the auth prompt use the Mac account's username and password — not a VNC password.
