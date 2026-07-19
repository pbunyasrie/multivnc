# Builds MultiVNC for Windows (Release) and stages a runnable package in .\dist
# Prereqs: VS 2022 Build Tools (C++), CMake, Python + Conan 2 (see CLAUDE.md)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Resolve-Tool($name, $fallback) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path $fallback) { return $fallback }
    throw "$name not found on PATH or at $fallback"
}

$cmake = Resolve-Tool "cmake" "C:\Program Files\CMake\bin\cmake.exe"
$conan = Resolve-Tool "conan" "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts\conan.exe"

git submodule update --init libsshtunnel libvncserver libwxservdisc
if ($LASTEXITCODE -ne 0) { throw "submodule init failed" }

& $conan install . --output-folder=build --build=missing --settings=build_type=Release
if ($LASTEXITCODE -ne 0) { throw "conan install failed" }

& $cmake -S . -B build "-DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake" "-DCMAKE_BUILD_TYPE=Release"
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

& $cmake --build build --config Release
if ($LASTEXITCODE -ne 0) { throw "build failed" }

& $cmake --install build --config Release --prefix "$PSScriptRoot\dist"
if ($LASTEXITCODE -ne 0) { throw "install failed" }

Write-Host "`nDone. Runnable package: $PSScriptRoot\dist\multivnc.exe"
