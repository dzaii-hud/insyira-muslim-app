# ---------------------------------------------------------------------------
# Membuat kunci rilis (upload key) untuk Google Play.
#
#   powershell -ExecutionPolicy Bypass -File deploy\android\buat-keystore.ps1
#
# Hasilnya:
#   %USERPROFILE%\.insyira\insyira-upload.jks        <- kuncinya (JANGAN hilang)
#   %USERPROFILE%\.insyira\SANDI-KEYSTORE.txt        <- sandinya (JANGAN hilang)
#   android\key.properties                           <- dipakai Gradle (masuk .gitignore)
#
# Sandi dibuat acak di sini dan sengaja TIDAK pernah ditampilkan ke layar
# supaya tidak terekam di log percakapan. Buka berkas SANDI-KEYSTORE.txt
# kalau perlu melihatnya, lalu SIMPAN CADANGANNYA di luar komputer ini
# (Google Drive pribadi / password manager).
#
# Kunci ini TIDAK boleh di-commit ke git: siapa pun yang punya berkasnya bisa
# mengunggah pembaruan palsu atas nama aplikasi ini.
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$folderKunci = Join-Path $env:USERPROFILE '.insyira'
$berkasJks   = Join-Path $folderKunci 'insyira-upload.jks'
$berkasSandi = Join-Path $folderKunci 'SANDI-KEYSTORE.txt'
$alias       = 'insyira-upload'
$dname       = 'CN=Insyira Muslim App, OU=Mobile, O=Insyira, L=Pekanbaru, ST=Riau, C=ID'

# --- 1. Cari keytool --------------------------------------------------------
$kandidat = @(
    'D:\AndroidStudio\jbr\bin\keytool.exe',
    'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
    (Join-Path $env:JAVA_HOME 'bin\keytool.exe')
)
$keytool = $kandidat | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $keytool) {
    $keytool = (Get-ChildItem 'C:\', 'D:\' -Filter 'keytool.exe' -Recurse -Depth 4 -ErrorAction SilentlyContinue |
        Select-Object -First 1).FullName
}
if (-not $keytool) { throw 'keytool.exe tidak ditemukan. Pasang JDK / Android Studio dulu.' }
Write-Host "Keytool : $keytool"

# --- 2. Jangan menimpa kunci yang sudah ada --------------------------------
if (Test-Path $berkasJks) {
    throw "Kunci sudah ada di $berkasJks dan TIDAK ditimpa. Hapus dulu kalau memang mau membuat yang baru."
}

New-Item -ItemType Directory -Force -Path $folderKunci | Out-Null

# --- 3. Sandi acak 28 karakter (hanya huruf & angka) -----------------------
# Huruf/angka saja supaya aman di berkas .properties (tanda = : \ # ! dan spasi
# punya arti khusus di sana) dan aman dilempar ke keytool.
$karakter = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
$rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$acak  = New-Object byte[] 28
$rng.GetBytes($acak)
$sb = New-Object System.Text.StringBuilder
foreach ($b in $acak) { [void]$sb.Append($karakter[$b % $karakter.Length]) }
$sandi = $sb.ToString()

# --- 4. Buat keystore ------------------------------------------------------
# 10.000 hari (~27 tahun). Google Play mensyaratkan kunci masih berlaku
# minimal sampai 22 Oktober 2033.
& $keytool -genkeypair -v `
    -keystore $berkasJks -storetype PKCS12 `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $alias -storepass $sandi -keypass $sandi `
    -dname $dname

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $berkasJks)) { throw 'Pembuatan keystore GAGAL.' }

# --- 5. Tulis key.properties untuk Gradle ----------------------------------
# storeFile memakai garis miring miring (/) karena garis miring balik adalah
# karakter escape di berkas .properties.
$storeFile = $berkasJks.Replace('\', '/')
$isiKeyProperties = @"
storePassword=$sandi
keyPassword=$sandi
keyAlias=$alias
storeFile=$storeFile
"@
$tujuanKeyProperties = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'android\key.properties'
[System.IO.File]::WriteAllText($tujuanKeyProperties, $isiKeyProperties, [System.Text.UTF8Encoding]::new($false))

# --- 6. Tulis catatan sandi (di luar repo) ---------------------------------
$isiCatatan = @"
KUNCI RILIS APLIKASI INSYIRA MUSLIM APP
=======================================
Berkas kunci : $berkasJks
Alias        : $alias
Sandi        : $sandi

JANGAN PERNAH:
  - mengunggah berkas ini atau catatan ini ke internet (GitHub, Drive publik)
  - mengirimkannya lewat WhatsApp/chat biasa
  - menghapus berkas ini tanpa punya cadangan

SIMPAN CADANGAN di tempat aman (Google Drive pribadi / password manager).
Kalau berkas ini hilang DAN kunci disimpan sendiri (tanpa Play App Signing),
aplikasi tidak akan bisa diperbarui lagi selamanya.
"@
[System.IO.File]::WriteAllText($berkasSandi, $isiCatatan, [System.Text.UTF8Encoding]::new($false))

# --- 7. Tampilkan sidik jari (BUKAN sandi) ---------------------------------
Write-Host ''
Write-Host '=== Sidik jari kunci rilis (dibutuhkan untuk Google Sign-In / Firebase) ==='
& $keytool -list -v -keystore $berkasJks -storepass $sandi -alias $alias 2>$null |
    Select-String -Pattern 'SHA1:|SHA256:'

Write-Host ''
Write-Host "Kunci     : $berkasJks"
Write-Host "Sandi     : $berkasSandi  (dibuat, isinya tidak ditampilkan di sini)"
Write-Host "key.properties : $tujuanKeyProperties"
Write-Host ''
Write-Host 'LANGKAH WAJIB: buka berkas sandi di atas, lalu simpan cadangannya di tempat aman.'
