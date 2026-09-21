<#
.SYNOPSIS
    Bangun aplikasi web Insyira lalu deploy ke Railway.

.DESCRIPTION
    Empat langkah:

      1. `flutter build web --release`
      2. Menyiapkan folder konteks kecil di `deploy/web/context/`
      3. Menulis `config.json` berisi alamat API ke dalam konteks itu
      4. `railway up` HANYA folder konteks tersebut

    ── Kenapa pakai folder konteks? ────────────────────────────────────────
    Seluruh proyek ini 3,5 GB. Folder `build/` untuk platform lain saja
    2,98 GB, sementara yang dibutuhkan image web hanya `build/web` (252 MB).

    Cara yang mula-mula dipakai adalah menyaring dengan `.railwayignore`,
    tapi hasilnya rapuh: pada satu percobaan, Dockerfile-nya sendiri ikut
    terbuang sehingga Railway gagal dengan pesan `couldn't locate the
    dockerfile ... in code archive`, dan yang terkirim cuma 12 MB dari
    252 MB yang seharusnya.

    Folder konteks menghapus seluruh ketergantungan itu: yang diunggah memang
    hanya folder itu, jadi tidak ada berkas abaikan yang bisa salah. Hasilnya
    juga lebih ringan dan pasti.

.PARAMETER ApiBaseUrl
    Alamat API backend, WAJIB diakhiri /api.
    Contoh: https://api.pusatoleolehpekanbaru.id/api

.PARAMETER GoogleWebClientId
    Client ID Google tipe "Web application". Boleh dikosongkan kalau login
    Google di web belum dipakai.

.PARAMETER LewatiBuild
    Lewati `flutter build web`. Berguna kalau baru saja build dan hanya ingin
    mengganti alamat API lalu deploy ulang. Jauh lebih cepat.

.PARAMETER Service
    Nama service di Railway. Default: insyira-web

.EXAMPLE
    .\deploy\web\deploy.ps1 -ApiBaseUrl https://api.pusatoleolehpekanbaru.id/api

.EXAMPLE
    # Build sudah ada, cuma ganti alamat API lalu deploy lagi
    .\deploy\web\deploy.ps1 -ApiBaseUrl https://api.pusatoleolehpekanbaru.id/api -LewatiBuild
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [string]$GoogleWebClientId = '',

    [switch]$LewatiBuild,

    [string]$Service = 'insyira-web'
)

# ⚠️ Sengaja 'Continue', bukan 'Stop'.
#
# Flutter dan Railway CLI menulis peringatan biasa ke stderr (misalnya
# "Wasm dry run succeeded"), dan PowerShell 5.1 mengangkat keluaran stderr
# dari perintah native menjadi objek error. Dengan 'Stop', skrip berhenti
# hanya karena sebuah peringatan — build yang sebenarnya berhasil pun
# dilaporkan gagal.
#
# Karena itu keberhasilan perintah native diperiksa lewat $LASTEXITCODE,
# dan kesalahan yang benar-benar fatal tetap dihentikan dengan `throw`.
$ErrorActionPreference = 'Continue'

# Tentukan folder akar proyek dari lokasi skrip ini (deploy/web/deploy.ps1),
# supaya skrip bisa dijalankan dari folder mana pun.
$rootProyek = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $rootProyek

$folderKonteks = Join-Path $rootProyek 'deploy\web\context'
$folderHtml = Join-Path $folderKonteks 'html'

Write-Host ''
Write-Host '===============================================' -ForegroundColor Cyan
Write-Host ' Deploy WEB Insyira ke Railway' -ForegroundColor Cyan
Write-Host '===============================================' -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Periksa alamat API sebelum melakukan apa pun yang memakan waktu.
# Salah alamat di sini berarti aplikasi ter-deploy tapi tidak bisa memanggil
# API sama sekali — dan kesalahannya baru terlihat setelah online.
# ---------------------------------------------------------------------------
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

if ($ApiBaseUrl -notmatch '^https://') {
    Write-Host ''
    Write-Host 'PERINGATAN: alamat API tidak memakai https.' -ForegroundColor Yellow
    Write-Host '  Halaman web yang dibuka lewat https TIDAK BISA memanggil API http' -ForegroundColor Yellow
    Write-Host '  (diblokir browser sebagai mixed content). Login akan gagal.' -ForegroundColor Yellow
    Write-Host ''
}

if ($ApiBaseUrl -notmatch '/api$') {
    throw "ApiBaseUrl harus diakhiri '/api'. Nilai sekarang: $ApiBaseUrl"
}

# ---------------------------------------------------------------------------
# 1. Build
# ---------------------------------------------------------------------------
Write-Host ''
if ($LewatiBuild) {
    Write-Host '[1/4] Build dilewati (-LewatiBuild).' -ForegroundColor DarkGray

    if (-not (Test-Path (Join-Path $rootProyek 'build\web\index.html'))) {
        throw 'build\web belum ada. Jalankan tanpa -LewatiBuild dulu.'
    }
} else {
    Write-Host '[1/4] Membangun aplikasi web...' -ForegroundColor Green
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web gagal.' }
}

# ---------------------------------------------------------------------------
# 2. Siapkan folder konteks
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/4] Menyiapkan folder konteks...' -ForegroundColor Green

# Dibersihkan dulu supaya berkas dari build sebelumnya tidak tertinggal.
# Kalau tertinggal, berkas lama yang sudah tidak ada di build baru akan tetap
# ikut ter-deploy dan sulit dilacak.
if (Test-Path $folderKonteks) {
    Remove-Item -Recurse -Force $folderKonteks
}
New-Item -ItemType Directory -Path $folderHtml -Force | Out-Null

Copy-Item (Join-Path $rootProyek 'deploy\web\Dockerfile') $folderKonteks -Force
Copy-Item (Join-Path $rootProyek 'deploy\web\nginx.conf.template') $folderKonteks -Force
Copy-Item (Join-Path $rootProyek 'build\web\*') $folderHtml -Recurse -Force

$ukuranMb = (Get-ChildItem $folderHtml -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ('      isi konteks: {0:N1} MB' -f $ukuranMb) -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 3. Tulis config.json
#
# Berkas ini dibaca aplikasi SAAT DIJALANKAN (lihat lib/config.dart), bukan
# saat build. Jadi mengubah isinya tidak memerlukan build ulang — cukup
# jalankan skrip ini lagi dengan -LewatiBuild.
#
# Ditulis SETELAH penyalinan: proses build Flutter menyalin isi folder `web/`
# ke hasil build, jadi berkas yang ditulis lebih dulu akan tertimpa.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[3/4] Menulis config.json...' -ForegroundColor Green

$isiConfig = [ordered]@{
    apiBaseUrl        = $ApiBaseUrl
    googleWebClientId = $GoogleWebClientId
}

# ⚠️ Ditulis lewat .NET, BUKAN `Set-Content -Encoding utf8`.
# PowerShell 5.1 selalu menambahkan BOM (\uFEFF) di awal berkas dengan cara
# itu, dan `jsonDecode` di Dart MENOLAK BOM sebagai "Unexpected character".
# Akibatnya aplikasi web diam-diam gagal membaca config.json lalu memakai
# alamat API bawaan — kegagalan yang sangat sulit dilacak karena tidak ada
# pesan error di layar.
$teksConfig = $isiConfig | ConvertTo-Json
$pathConfig = Join-Path $folderHtml 'config.json'

[System.IO.File]::WriteAllText(
    $pathConfig,
    $teksConfig,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host "      apiBaseUrl        : $ApiBaseUrl"
if ([string]::IsNullOrWhiteSpace($GoogleWebClientId)) {
    Write-Host '      googleWebClientId : (kosong - login Google web nonaktif)' -ForegroundColor DarkGray
} else {
    Write-Host "      googleWebClientId : $GoogleWebClientId"
}

# ---------------------------------------------------------------------------
# 4. Kirim ke Railway
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[4/4] Mengirim ke Railway...' -ForegroundColor Green
Write-Host '      (hanya deploy/web/context yang diunggah)' -ForegroundColor DarkGray
Write-Host ''

# ⚠️ --no-gitignore WAJIB.
# Folder konteks ada di dalam .gitignore supaya tidak mengotori git status.
# Tanpa opsi ini, Railway justru membuang folder yang sedang kita kirim.
#
# --path-as-root membuat folder konteks menjadi akar arsip, sehingga
# Dockerfile dan html/ berada di posisi yang diharapkan Dockerfile.
#
# Percobaan ulang: mengunggah ~252 MB dalam satu permintaan HTTP. Pada
# koneksi yang kurang stabil ini kadang gagal dengan pesan samar seperti
# `error sending request for url (...)`, padahal tidak ada yang salah dengan
# konfigurasinya — percobaan berikutnya biasanya langsung berhasil.
$maksPercobaan = 3
$unggahanBerhasil = $false

for ($percobaan = 1; $percobaan -le $maksPercobaan; $percobaan++) {
    railway up 'deploy/web/context' --path-as-root --no-gitignore --service $Service

    if ($LASTEXITCODE -eq 0) {
        $unggahanBerhasil = $true
        break
    }

    if ($percobaan -lt $maksPercobaan) {
        Write-Host ''
        Write-Host "      Unggahan gagal (percobaan $percobaan dari $maksPercobaan)." -ForegroundColor Yellow
        Write-Host '      Mencoba lagi...' -ForegroundColor Yellow
        Write-Host ''
    }
}

if (-not $unggahanBerhasil) {
    Write-Host ''
    Write-Host "Deploy gagal setelah $maksPercobaan percobaan." -ForegroundColor Red
    Write-Host 'Periksa:' -ForegroundColor Yellow
    Write-Host '  - sudah `railway login`?' -ForegroundColor Yellow
    Write-Host "  - service '$Service' ada di project yang terhubung?" -ForegroundColor Yellow
    Write-Host '  - koneksi internet stabil?' -ForegroundColor Yellow
    throw 'railway up gagal.'
}

Write-Host ''
Write-Host 'Selesai.' -ForegroundColor Cyan
