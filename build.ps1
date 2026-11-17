param(
    [string]$VersionName = "1.0",
    [int]$VersionCode = 1,
    [string]$TargetSdk = "34",
    [switch]$V1Only,
    [string]$Suffix = "",
    [string]$PackageName = "id.sch.smkpgri1po.siakad"
)

$ErrorActionPreference = 'Stop'

$root   = 'C:\Users\guru01\AndroidBuild'
$env:JAVA_HOME = "$root\jdk"
$env:PATH = "$root\jdk\bin;$env:PATH"

$sdk     = "$root\sdk"
$buildTools = "$sdk\build-tools\34.0.0"
$androidJar = "$sdk\platforms\android-34\android.jar"
$app     = "$root\app"
$build   = "$root\build"
$dist    = "$root\dist"
$keystore = "$root\siakad-release.keystore"
$ksPass  = 'SiakadPgri2026!'
$ksAlias = 'siakad'
$minSdk  = 14

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "GAGAL: $msg" -ForegroundColor Red; exit 1 }

foreach ($p in @("$buildTools\aapt2.exe", "$buildTools\d8.bat", "$buildTools\zipalign.exe",
                 "$buildTools\apksigner.bat", $androidJar)) {
    if (-not (Test-Path $p)) { Fail "Komponen tidak ditemukan: $p" }
}

Step "Membersihkan folder build"
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$build\gen", "$build\classes", "$build\dex", $dist | Out-Null

# Jika package diminta berbeda, buat salinan sumber dengan package baru
# agar aplikasi bisa dipasang berdampingan dengan versi lama yang bertanda tangan lain.
if ($PackageName -ne 'id.sch.smkpgri1po.siakad') {
    Step "Menyiapkan varian package: $PackageName"
    $appWork = "$build\app-$($PackageName -replace '[^A-Za-z0-9]','_')"
    Copy-Item $app $appWork -Recurse -Force
    $manifestPath = "$appWork\AndroidManifest.xml"
    $manifestText = Get-Content $manifestPath -Raw -Encoding UTF8
    $manifestText = $manifestText.Replace('package="id.sch.smkpgri1po.siakad"', "package=`"$PackageName`"")
    [System.IO.File]::WriteAllText($manifestPath, $manifestText, (New-Object System.Text.UTF8Encoding($false)))
    $javaPath = "$appWork\src\id\sch\smkpgri1po\siakad\MainActivity.java"
    $javaText = Get-Content $javaPath -Raw -Encoding UTF8
    $javaText = $javaText.Replace('package id.sch.smkpgri1po.siakad;', "package $PackageName;")
    [System.IO.File]::WriteAllText($javaPath, $javaText, (New-Object System.Text.UTF8Encoding($false)))
    $app = $appWork
}

Step "Kompilasi resource (aapt2 compile)"
& "$buildTools\aapt2.exe" compile --dir "$app\res" -o "$build\res.zip"
if ($LASTEXITCODE -ne 0) { Fail "aapt2 compile" }

Step "Menautkan resource + manifest (aapt2 link)"
& "$buildTools\aapt2.exe" link `
    -o "$build\base.apk" `
    -I $androidJar `
    --manifest "$app\AndroidManifest.xml" `
    -R "$build\res.zip" `
    --java "$build\gen" `
    --min-sdk-version $minSdk `
    --target-sdk-version $TargetSdk `
    --version-code $VersionCode `
    --version-name $VersionName `
    --auto-add-overlay
if ($LASTEXITCODE -ne 0) { Fail "aapt2 link" }

Step "Kompilasi Java (javac)"
$sources = @()
$sources += Get-ChildItem "$app\src" -Recurse -Filter *.java | ForEach-Object { $_.FullName }
$sources += Get-ChildItem "$build\gen" -Recurse -Filter *.java | ForEach-Object { $_.FullName }
& "$env:JAVA_HOME\bin\javac.exe" `
    -source 8 -target 8 `
    -bootclasspath $androidJar `
    -encoding UTF-8 `
    -nowarn `
    -d "$build\classes" `
    $sources
if ($LASTEXITCODE -ne 0) { Fail "javac" }

Step "Membungkus kelas menjadi JAR"
& "$env:JAVA_HOME\bin\jar.exe" --create --file "$build\classes.jar" -C "$build\classes" .
if ($LASTEXITCODE -ne 0) { Fail "jar" }

Step "Konversi ke DEX (d8)"
& "$buildTools\d8.bat" --lib $androidJar --min-api $minSdk --release `
    --output "$build\dex" "$build\classes.jar"
if ($LASTEXITCODE -ne 0) { Fail "d8" }

Step "Menyisipkan classes.dex ke APK"
Copy-Item "$build\base.apk" "$build\unsigned.apk" -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open("$build\unsigned.apk", 'Update')
try {
    $existing = $zip.GetEntry('classes.dex')
    if ($existing) { $existing.Delete() }
    $entry = $zip.CreateEntry('classes.dex', [System.IO.Compression.CompressionLevel]::Optimal)
    $outStream = $entry.Open()
    try {
        $inStream = [System.IO.File]::OpenRead("$build\dex\classes.dex")
        try { $inStream.CopyTo($outStream) } finally { $inStream.Dispose() }
    } finally { $outStream.Dispose() }
} finally { $zip.Dispose() }

Step "Menyelaraskan APK (zipalign)"
& "$buildTools\zipalign.exe" -f -p 4 "$build\unsigned.apk" "$build\aligned.apk"
if ($LASTEXITCODE -ne 0) { Fail "zipalign" }

if (-not (Test-Path $keystore)) {
    Step "Membuat keystore penandatangan"
    & "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
        -keystore $keystore -alias $ksAlias `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass $ksPass -keypass $ksPass `
        -dname "CN=SIAKAD SMK PGRI 1 Ponorogo, OU=IT, O=SMK PGRI 1 Ponorogo, L=Ponorogo, ST=Jawa Timur, C=ID"
    if ($LASTEXITCODE -ne 0) { Fail "keytool" }
}

# Varian v1 saja dipakai untuk perangkat/instalasi lama yang menolak skema v2/v3.
$v2 = if ($V1Only) { "false" } else { "true" }
$v3 = if ($V1Only) { "false" } else { "true" }

$apkName = "SIAKAD-SMKPGRI1PO-v$VersionName$Suffix.apk"
Step "Menandatangani APK (apksigner) -> $apkName"
& "$buildTools\apksigner.bat" sign `
    --ks $keystore --ks-pass "pass:$ksPass" --key-pass "pass:$ksPass" `
    --ks-key-alias $ksAlias `
    --v1-signing-enabled true --v2-signing-enabled $v2 --v3-signing-enabled $v3 `
    --min-sdk-version $minSdk `
    --out "$dist\$apkName" `
    "$build\aligned.apk"
if ($LASTEXITCODE -ne 0) { Fail "apksigner" }

Step "Verifikasi tanda tangan"
& "$buildTools\apksigner.bat" verify --min-sdk-version $minSdk --print-certs "$dist\$apkName"
if ($LASTEXITCODE -ne 0) { Fail "verifikasi APK" }

$apk = Get-Item "$dist\$apkName"
Write-Host ""
Write-Host "APK BERHASIL DIBUAT" -ForegroundColor Green
Write-Host "  File    : $($apk.FullName)"
Write-Host "  Ukuran  : $([math]::Round($apk.Length/1KB,1)) KB"
Write-Host "  minSdk  : $minSdk / targetSdk: $TargetSdk / v1only: $V1Only"
