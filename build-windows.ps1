# Builds MultiVNC for Windows (Release) and stages a runnable package in .\dist
# Prereqs: VS 2022 Build Tools (C++), CMake, Python + Conan 2 (see CLAUDE.md).
# Missing tools are installed automatically via install-toolchain.ps1.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Find-Tool($name, $fallback) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path $fallback) { return $fallback }
    return $null
}

function Test-VsBuildTools {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return -not [string]::IsNullOrWhiteSpace($path)
}

$cmakeFallback = "C:\Program Files\CMake\bin\cmake.exe"
$conanFallback = "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts\conan.exe"

$cmake = Find-Tool "cmake" $cmakeFallback
$conan = Find-Tool "conan" $conanFallback

if (-not ($cmake -and $conan -and (Test-VsBuildTools))) {
    Write-Host "Toolchain incomplete - running install-toolchain.ps1..."
    & "$PSScriptRoot\install-toolchain.ps1"
    $cmake = Find-Tool "cmake" $cmakeFallback
    $conan = Find-Tool "conan" $conanFallback
    if (-not $cmake) { throw "cmake still not found; open a new terminal and re-run" }
    if (-not $conan) { throw "conan still not found; open a new terminal and re-run" }
}

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
