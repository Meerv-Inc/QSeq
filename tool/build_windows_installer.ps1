# QSeq — Windows release build + installer, with optional Authenticode signing
# via Azure Artifact Signing (formerly Trusted Signing).
#
# Unsigned (works today):
#   powershell -File tool\build_windows_installer.ps1
#
# Signed (once the Meerv Inc. Azure Artifact Signing account is validated):
#   1. Install the signing client (once):
#        dotnet tool install --global Azure.CodeSigning.Client   # or download the
#        Microsoft.Trusted.Signing.Client NuGet and note the path to
#        Azure.CodeSigning.Dlib.dll (x64)
#   2. Create installer\signing-metadata.json from the .example.json with the
#      account's Endpoint / CodeSigningAccountName / CertificateProfileName.
#   3. Authenticate: `az login`, or set AZURE_TENANT_ID / AZURE_CLIENT_ID /
#      AZURE_CLIENT_SECRET for a service principal.
#   4. Set QSEQ_SIGN_DLIB to the full path of Azure.CodeSigning.Dlib.dll and run
#      this script — it signs QSeq.exe, then the setup.exe + uninstaller.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

# --- 1. Flutter release build -------------------------------------------------
flutter build windows
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
$exe = Join-Path $repo 'build\windows\x64\runner\Release\QSeq.exe'

# --- 2. signing configuration ---------------------------------------------------
function Find-SignTool {
    $kits = 'C:\Program Files (x86)\Windows Kits\10\bin'
    if (Test-Path $kits) {
        $hit = Get-ChildItem $kits -Directory |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1
        if ($hit) { return $hit }
    }
    $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$dlib = $env:QSEQ_SIGN_DLIB
$metadata = Join-Path $repo 'installer\signing-metadata.json'
$signtool = Find-SignTool
$signing = $dlib -and (Test-Path $dlib) -and (Test-Path $metadata) -and $signtool

if ($signing) {
    # /tr = Microsoft's Artifact Signing timestamp authority (RFC 3161).
    $signCmd = "`"$signtool`" sign /v /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 /dlib `"$dlib`" /dmdf `"$metadata`""
    Write-Host '== signing QSeq.exe =='
    Invoke-Expression "$signCmd `"$exe`""
    if ($LASTEXITCODE -ne 0) { throw 'signing QSeq.exe failed' }
} else {
    Write-Warning ('Building UNSIGNED: ' + $(
        if (-not $signtool) { 'signtool.exe not found (install a Windows 10/11 SDK).' }
        elseif (-not $dlib -or -not (Test-Path $dlib)) { 'set QSEQ_SIGN_DLIB to Azure.CodeSigning.Dlib.dll.' }
        else { 'create installer\signing-metadata.json (see the .example.json).' }))
}

# --- 3. Inno Setup ---------------------------------------------------------------
$iscc = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) { throw "ISCC.exe not found at $iscc" }
if ($signing) {
    # Inno replaces $f with each file to sign (setup.exe and the uninstaller).
    & $iscc /DSign "/Sazuresign=$signCmd `$f" installer\qseq.iss
} else {
    & $iscc installer\qseq.iss
}
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }

$setup = Join-Path $repo 'dist\qseq-windows-setup.exe'
Write-Host "== built $setup =="
if ($signing) {
    & $signtool verify /pa /v $setup
    if ($LASTEXITCODE -ne 0) { throw 'signature verification failed' }
    Write-Host '== signature verified =='
}
Get-FileHash $setup -Algorithm SHA256 | Format-List
