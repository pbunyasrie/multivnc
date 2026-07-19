# Installs the toolchain needed to build MultiVNC on Windows (see CLAUDE.md).
# Idempotent: checks each component and only installs what is missing.
# Requires winget. VS Build Tools / CMake are machine-wide installs and may
# trigger UAC prompts. The VS Build Tools download is ~3 GB.
$ErrorActionPreference = "Stop"

function Test-VsBuildTools {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return -not [string]::IsNullOrWhiteSpace($path)
}

function Find-RealPython {
    # Avoid the WindowsApps store shim, which is not a real python.exe
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -notlike "*WindowsApps*") { return $cmd.Source }
    $known = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
    if (Test-Path $known) { return $known }
    return $null
}

function Find-Conan {
    $cmd = Get-Command conan -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $known = "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts\conan.exe"
    if (Test-Path $known) { return $known }
    return $null
}

$winget = @("--silent", "--accept-package-agreements", "--accept-source-agreements")

if (-not (Test-VsBuildTools)) {
    Write-Host "Installing Visual Studio 2022 Build Tools + C++ workload (~3 GB, 10-20 min)..."
    winget install --id Microsoft.VisualStudio.2022.BuildTools @winget --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
    if ($LASTEXITCODE -ne 0) { throw "VS Build Tools install failed (exit $LASTEXITCODE)" }
} else { Write-Host "VS Build Tools with C++ workload: OK" }

if (-not (Get-Command cmake -ErrorAction SilentlyContinue) -and -not (Test-Path "C:\Program Files\CMake\bin\cmake.exe")) {
    Write-Host "Installing CMake..."
    winget install --id Kitware.CMake @winget
    if ($LASTEXITCODE -ne 0) { throw "CMake install failed (exit $LASTEXITCODE)" }
} else { Write-Host "CMake: OK" }

if (-not (Find-RealPython)) {
    Write-Host "Installing Python 3.12..."
    winget install --id Python.Python.3.12 @winget
    if ($LASTEXITCODE -ne 0) { throw "Python install failed (exit $LASTEXITCODE)" }
} else { Write-Host "Python: OK" }

if (-not (Find-Conan)) {
    Write-Host "Installing Conan (pip --user)..."
    $py = Find-RealPython
    if (-not $py) { throw "Python not found even after install; open a new terminal and re-run" }
    & $py -m pip install --user --quiet conan
    if ($LASTEXITCODE -ne 0) { throw "pip install conan failed" }
} else { Write-Host "Conan: OK" }

if (-not (Test-Path "$env:USERPROFILE\.conan2\profiles\default")) {
    Write-Host "Creating default Conan profile..."
    $conan = Find-Conan
    & $conan profile detect
    if ($LASTEXITCODE -ne 0) { throw "conan profile detect failed" }
} else { Write-Host "Conan default profile: OK" }

Write-Host "`nToolchain ready."
