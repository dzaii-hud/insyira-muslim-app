# Panduan Build & Rilis iOS — dari nol

Panduan ini ditulis untuk yang **belum pernah** menyentuh iOS/Xcode. Semua
perintah di sini dijalankan **di Mac**, bukan di Windows. Kalau ada bagian yang
tidak cocok dengan kondisi Mac-mu, berhenti di situ dan catat pesan errornya —
jangan dilanjutkan.

Yang sudah siap di dalam repo (tidak perlu diurus lagi):

- Folder `ios/` lengkap dengan `Runner.xcworkspace`.
- Ikon aplikasi iOS semua ukuran, termasuk 1024×1024 untuk App Store (sudah
  tanpa transparansi — syarat Apple).
- Izin kamera dan lokasi sudah ditulis di `ios/Runner/Info.plist`.
- Nama tampilan aplikasi: **Insyira Muslim App**.
- Bundle ID sudah `id.insyira.muslimapp` (samakan dengan Android) dan versi iOS
  minimum 15.0.
- `ios/Podfile` + izin kamera iOS (`PERMISSION_CAMERA=1`).
- Suara notifikasi adzan `ios/Runner/adzan.caf` (29 detik, sudah di bundle).
- Delegate notifikasi di `AppDelegate.swift`.
- Sign in with Apple: `ios/Runner/Runner.entitlements` sudah terpasang di
  ketiga konfigurasi build (Bagian 5.2).
- Privacy manifest `ios/Runner/PrivacyInfo.xcprivacy` (sudah masuk Resources).
- `ITSAppUsesNonExemptEncryption = false` — pertanyaan export compliance tidak
  muncul lagi saat upload.
- Slot `GIDClientID` + URL scheme Google **sudah ada** di `Info.plist`, masih
  berisi nilai placeholder.
- Skrip build rilis: `deploy/ios/build-ipa.sh` (Bagian 8).

Yang **masih manual**:

- Login Google di iOS (Bagian 6.3) — isi dua nilai placeholder, butuh OAuth
  client dari Google Cloud Console milikmu.
- Endpoint hapus akun di backend (Bagian 6.6) — kode aplikasinya sudah selesai,
  Laravel-nya yang belum ada.

---

## 0. Istilah yang akan sering muncul

| Istilah | Artinya |
|---|---|
| **Xcode** | Aplikasi buatan Apple untuk membuat aplikasi iOS. Termasuk editor kode + alat build + emulator. |
| **Simulator** | "HP iPhone palsu" di dalam Mac. Kamera tidak ada, lokasi bisa diatur manual. |
| **CocoaPods / Podfile** | Pengelola "library pihak ketiga" versi iOS. Android punya Gradle, iOS punya CocoaPods. `Podfile` = daftar resep library. |
| **Bundle ID** | ID unik aplikasi di iOS, misalnya `id.insyira.muslimapp`. Tidak boleh sama dengan aplikasi orang lain. Sama seperti `applicationId` di Android. |
| **Team** | Akun Apple yang menandatangani aplikasi. Tanpa ini aplikasi tidak bisa dipasang ke iPhone. |
| **Signing / Sertifikat** | Tanda tangan digital bahwa aplikasi ini benar dari kamu. Xcode mengurus otomatis kalau `Team` sudah diisi. |
| **Archive / IPA** | Hasil build final. `IPA` = file aplikasi iOS, sama seperti `APK`/`AAB` di Android. |
| **TestFlight** | Tempat mengirim aplikasi ke tester sebelum rilis di App Store. |
| **App Store Connect** | Situs Apple untuk mengelola aplikasi: nama, screenshot, tester, rilis. |

---

## 1. Yang harus disiapkan

1. **Mac** (Apple Silicon atau Intel, macOS versi terbaru).
2. **Xcode** dari Mac App Store — sudah kamu unduh. Ukurannya belasan GB,
   pastikan ruang disk sisa minimal ~40 GB.
3. **Flutter 3.38.x** di Mac (proyek ini butuh Dart `^3.10.4`).
4. **CocoaPods** (dipasang di Bagian 3).
5. **Akun Apple** — dua pilihan:

| | Apple ID gratis | Apple Developer Program |
|---|---|---|
| Biaya | Rp0 | ±$99/tahun (±Rp1,6 juta) |
| Uji di iPhone sendiri | ✅ (aplikasi mati setelah 7 hari, harus pasang ulang) | ✅ |
| TestFlight | ❌ | ✅ |
| Kirim ke App Store | ❌ | ✅ |

Saran: mulai dengan Apple ID gratis dulu untuk memastikan aplikasi jalan,
baru daftar Developer Program saat sudah siap kirim ke tester.

---

## 2. Pindahkan kode ke Mac

Kode terbaru ada di Windows dan **belum di-push** ke GitHub, jadi `git clone`
di Mac akan menghasilkan versi lama. Di Windows dulu:

```powershell
git add -A
git commit -m "wip: persiapan build iOS"
git push origin main
```

Di Mac:

```bash
git clone https://github.com/dzaii-hud/insyira-muslim-app.git
cd insyira-muslim-app
```

### Kalau mau mengirim project ke orang lain

**Jangan** men-zip folder project apa adanya. Folder di Windows berukuran
**±6,9 GB / 34.569 berkas**, sebagian besarnya sampah build (`build/` 5,9 GB,
`.dart_tool/` 394 MB, `deploy/web/context/` 252 MB) — dan yang lebih berbahaya,
di dalamnya ada **rahasia**:

| Berkas | Kenapa tidak boleh dibagikan |
|---|---|
| `android/key.properties` | Memuat kata sandi keystore unggah Google Play. Kalau bocor, orang lain bisa menerbitkan pembaruan palsu atas nama aplikasi ini. |
| `test-file/` | Sengaja di-`gitignore` karena bisa memuat kredensial. |
| `%USERPROFILE%\.insyira\*.jks` | Kunci keystore itu sendiri — jangan pernah disalin ke mana pun. |

Cara yang benar, pilih salah satu:

- **Paling aman & sederhana — clone dari GitHub.** Sama seperti perintah di atas.
  Penolakan/penerimaan akses tetap di tangan pemilik repo.
- **Kirim sebagai arsip bersih** (hanya berkas yang dilacak git, tanpa sampah
  build dan tanpa rahasia). Pastikan semua perubahan sudah di-commit dulu,
  lalu di Windows:

  ```powershell
  git archive --format=zip --output=..\insyira-sumber.zip HEAD
  ```

  Hasilnya hanya beberapa MB (kode + aset), dan penerima cukup
  `unzip insyira-sumber.zip` lalu `flutter pub get`.
- **Jangan pakai** "kirim folder" biasa / zip manual / share lewat Drive
  folder mentah.

---

## 3. Pasang alat di Mac

Buka aplikasi **Terminal** (Command + Spasi → ketik "Terminal").

```bash
# 1. Xcode: buka sekali lewat Finder/Launchpad, setujui lisensi yang muncul.
#    Lalu di Terminal:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS     # unduh runtime Simulator (beberapa GB)

# 2. CocoaPods (jangan pakai "sudo gem install", sering gagal di Mac baru)
brew install cocoapods

# 3. Flutter
brew install --cask flutter

# 4. Cek semuanya
flutter doctor -v
```

`flutter doctor -v` harus menampilkan **✓** untuk:

- `Flutter`
- `Xcode - develop for iOS and macOS`
- `CocoaPods`

Kalau ada tanda `✗` atau `!` di salah satunya, beresin dulu bagian itu sebelum
lanjut. Kalau pesannya "Xcode version too new/unsupported", jalankan
`flutter upgrade`.

---

## 4. Jalankan pertama kali di Simulator

```bash
flutter pub get
cd ios && pod install && cd ..
open -a Simulator
flutter run --dart-define=API_BASE_URL=https://api.pusatoleolehpekanbaru.id/api
```

Catatan:

- `pod install` pertama bisa **10–20 menit** (mengunduh library). Kalau gagal
  karena repo lama, jalankan `pod repo update` lalu ulangi.
- **Selalu** sertakan `--dart-define=API_BASE_URL=...` saat build/run. Tanpa
  itu aplikasi memakai alamat IP lokal komputer (`http://192.168.18.4:8000`)
  dan semua data online (kajian, fawaidh) akan kosong — persis masalah yang
  pernah terjadi di build Android `+10`.
- Di Simulator: menu `Features → Location → Custom` untuk mengatur koordinat
  (misalnya Pekanbaru: `0.5071, 101.4478`). **Kamera tidak ada** di Simulator,
  jadi fitur AR Kiblat harus diuji di iPhone asli.

---

## 5. Setting Xcode (wajib, sekali saja)

```bash
open ios/Runner.xcworkspace
```

> Penting: buka yang **`.xcworkspace`**, bukan `.xcodeproj`. Kalau salah,
> library dari CocoaPods tidak ikut termuat dan build gagal.

### 5.1 Isi Team dan Bundle ID

1. Di panel kiri, klik ikon paling atas bernama **Runner**.
2. Pilih tab **Signing & Capabilities**.
3. Centang **Automatically manage signing**.
4. **Team**: pilih nama kamu / Apple ID kamu. (Kalau kosong, klik
   `Add an Account…` dan login dengan Apple ID.)

**Bundle Identifier** sudah diisi `id.insyira.muslimapp` di repo — jadi tidak
perlu diganti. Jangan diubah ke `com.example.*` lagi: Apple **menolak** awalan
itu saat upload ke App Store, dan ID ini harus sama dengan yang nanti dipakai
di App Store Connect dan OAuth client Google (Bagian 6.3).

### 5.2 "Sign in with Apple" — ✅ sudah beres di repo

`ios/Runner/Runner.entitlements` sudah ada dan dipakai oleh ketiga konfigurasi
build (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`). Di Xcode tidak
perlu klik **+ Capability** lagi — cukup pilih **Team** di Bagian 5.1, dan
*Automatically manage signing* akan membuat App ID beserta capability-nya.

Kenapa wajib: tombol "Masuk dengan Apple" di aplikasi memakai library
`sign_in_with_apple`; tanpa capability ini login Apple langsung gagal di iOS.
Bonus: Apple mewajibkan Sign in with Apple kalau aplikasi punya login pihak
ketiga (Google).

⚠️ Capability ini **tidak tersedia** untuk Apple ID gratis. Kalau build dengan
akun gratis, Xcode berhenti dengan pesan `Provisioning profile doesn't include
the com.apple.developer.applesignin entitlement`. Untuk sekadar mencoba di
iPhone sendiri sementara waktu, kosongkan dulu
`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` di `project.pbxproj`
(boleh dikembalikan setelah keanggotaan Developer Program aktif).

### 5.3 Versi iOS minimum

Sudah diatur ke **15.0** di dua tempat dan **tidak perlu diubah**:

- `ios/Podfile` → `platform :ios, '15.0'`
- `ios/Runner.xcodeproj` → `IPHONEOS_DEPLOYMENT_TARGET = 15.0`

Angka 15.0 dipilih karena plugin dengan syarat tertinggi (`home_widget`) butuh
iOS 14.0. Kalau nanti ada plugin baru yang menuntut versi lebih tinggi,
`pod install` akan berhenti dengan pesan jelas — naikkan angka di **kedua**
tempat itu.

---

## 6. Tambahan khas iOS untuk aplikasi ini

Empat hal ini tidak ada padanannya di Android. **Tiga di antaranya sudah
dikerjakan di dalam repo**, jadi tinggal satu yang perlu kamu urus sendiri
(6.3, karena butuh akun Google Cloud Console).

### 6.1 Izin kamera — ✅ sudah beres

`ios/Podfile` sudah ada di repo dan `post_install`-nya menyalakan
`PERMISSION_CAMERA=1` (jalur lama, CocoaPods).

Tapi sejak Flutter memakai **Swift Package Manager**, `permission_handler_apple`
dipasang lewat SPM — dan di jalur itu macro **tidak** dibaca dari Podfile.
Yang dipakai adalah **kunci di `Info.plist`**:

| Kunci `Info.plist` | Izin yang otomatis menyala |
|---|---|
| `NSCameraUsageDescription` | `Permission.camera` (AR Kiblat) |
| `NSLocationWhenInUseUsageDescription` | `Permission.location` |

Keduanya sudah ada di `ios/Runner/Info.plist`, jadi izin kamera aktif di kedua
jalur tanpa perlu diubah. Jangan hapus kedua kunci itu — kalau dihapus,
`Permission.camera.request()` akan selalu dijawab "ditolak" tanpa pesan apa pun.

⚠️ Kalau `Info.plist` diubah, hapus sekali cache build supaya SPM membaca ulang:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

Isi `post_install` di repo (untuk referensi):

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      definisi = config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] || ['$(inherited)']
      definisi = [definisi] if definisi.is_a?(String)
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] =
        (definisi + ['PERMISSION_CAMERA=1']).uniq

      versi = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] || '15.0'
      if Gem::Version.new(versi) < Gem::Version.new('15.0')
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end
```

### 6.2 Suara adzan — ✅ sudah beres

Berkas `ios/Runner/adzan.caf` sudah ada di repo (29 detik, mono, 1,2 MB), sudah
terdaftar di bundle Xcode sebagai resource, dan `notification_service.dart`
sudah menunjuk ke `adzan.caf`.

Kenapa harus `.caf` dan 29 detik: iOS **mengabaikan** suara notifikasi kustom
yang lebih dari **30 detik** dan diam-diam memutar suara bawaan. File aslinya
(`assets/audios/adzan.mp3`) 6,4 MB dan jauh lebih panjang.

Kalau nanti suara adzannya diganti, buat ulang `.caf` di Mac:

```bash
brew install ffmpeg       # sekali saja
ffmpeg -y -i assets/audios/adzan.mp3 -t 29 -ar 22050 -ac 1 -c:a pcm_s16le ios/Runner/adzan.caf
```

### 6.3 Login Google — ⚠️ ini yang masih manual

Login Google di iOS butuh "OAuth client" tipe **iOS** dari Google Cloud
Console (yang ada sekarang hanya tipe Web/Android).

1. Buka <https://console.cloud.google.com/apis/credentials> dengan akun pemilik
   project `38106971142`.
2. **Create Credentials → OAuth client ID → Application type: iOS**.
3. **Bundle ID**: `id.insyira.muslimapp` (harus sama persis dengan Bagian 5.1).
4. Salin **iOS client ID** (bentuknya `xxxx.apps.googleusercontent.com`) dan
   **iOS URL scheme** (kebalikannya, misalnya `com.googleusercontent.apps.xxxx`).
5. Ganti dua nilai placeholder di `ios/Runner/Info.plist` (keduanya sudah ada
   di dalam `<dict>`, tidak perlu menambah blok baru):

```xml
	<key>GIDClientID</key>
	<string>ISI_IOS_CLIENT_ID_DI_SINI.apps.googleusercontent.com</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>com.googleusercontent.apps.ISI_IOS_CLIENT_ID_DI_SINI</string>
			</array>
		</dict>
	</array>
```

Ganti `ISI_IOS_CLIENT_ID_DI_SINI` dengan bagian depan client ID (tanpa
`.apps.googleusercontent.com`). Selama masih placeholder, tombol login Google
di iOS akan gagal — Android dan web tidak terpengaruh.

`serverClientId` untuk backend sudah diisi di `lib/config.dart`
(client ID tipe Web), jadi tidak perlu diubah.

### 6.4 Notifikasi saat aplikasi sedang terbuka — ✅ sudah beres

`ios/Runner/AppDelegate.swift` di repo sudah memuat baris yang diwajibkan
`flutter_local_notifications`. Tanpa itu, iOS tidak menampilkan notifikasi
yang jatuh saat aplikasi sedang dibuka, dan ketukan pada notifikasi tidak
diteruskan ke aplikasi.

Catatan: bentuknya **wajib** `self as? UNUserNotificationCenterDelegate`
(optional cast), sesuai dokumentasi plugin. Menulisnya `= self` langsung akan
gagal compile karena `FlutterAppDelegate` tidak mengumumkan protokol itu di
header publiknya.

### 6.5 UIScene lifecycle — ✅ sudah beres

iOS 27 **menolak menjalankan** aplikasi yang belum memakai UIScene lifecycle.
Gejalanya membingungkan: `Xcode build done` berhasil, tapi aplikasi langsung
mati dan `flutter run` kembali ke prompt tanpa pesan error yang jelas. Kalau
dibiarkan, yang muncul hanya kotak peringatan:

```
Your iOS app has not been migrated to the UIScene lifecycle.
UIScene lifecycle is required on iOS 27 and later.
```

Repo ini sudah dimigrasikan secara manual (karena `AppDelegate.swift` kita
sudah dimodifikasi untuk notifikasi, sehingga migrasi otomatis Flutter menolak
jalan — migrasi otomatis hanya mau menyentuh file yang masih persis sama
dengan template). Dua perubahannya:

1. `ios/Runner/AppDelegate.swift` → `AppDelegate` memakai
   `FlutterImplicitEngineDelegate`, dan plugin didaftarkan di
   `didInitializeImplicitFlutterEngine` (bukan lagi di
   `didFinishLaunchingWithOptions`).
2. `ios/Runner/Info.plist` → ditambah `UIApplicationSceneManifest` dengan
   `UISceneDelegateClassName = FlutterSceneDelegate`.

Jangan hapus keduanya. Kalau nanti `flutter create .` dijalankan ulang atau
project dibuat dari nol, bagian ini harus dipasang lagi.

### 6.6 Hapus akun di dalam aplikasi — ⚠️ sisi aplikasi sudah, backend belum

Apple (guideline 5.1.1(v)) **menolak** aplikasi yang punya pendaftaran akun
tapi hanya menyediakan *tautan* ke halaman web untuk menghapus akun.

**Sisi aplikasi — ✅ sudah selesai:**

- `AuthService.hapusAkun()` di `lib/services/auth_service.dart` memanggil
  `DELETE {API_BASE_URL}/auth/account` dengan token Bearer.
- Tombol **Hapus Akun** ada di `settings_screen.dart`, tepat di bawah
  "Keluar Akun", lengkap dengan dialog konfirmasi yang menyebutkan data apa
  saja yang ikut terhapus.
- Sesudah berhasil: sesi lokal dibersihkan dan pengguna diarahkan ke layar
  login. Kalau server menolak, pengguna **tetap** login supaya bisa
  mencoba lagi.

**Sisi backend — ⚠️ ini yang harus ditambahkan (Laravel):**

```php
// routes/api.php
Route::middleware('auth:sanctum')->delete('/auth/account', [AuthController::class, 'hapusAkun']);

// app/Http/Controllers/Api/AuthController.php
public function hapusAkun(Request $request)
{
    $user = $request->user();

    // Hapus data milik user lebih dulu kalau tabelnya tidak memakai
    // foreign key onDelete('cascade'). Sesuaikan dengan skema yang ada.
    $user->tokens()->delete();
    $user->delete();

    return response()->json(['message' => 'Akun berhasil dihapus.']);
}
```

Yang perlu dipastikan:

1. Endpoint mengembalikan **200** saat berhasil.
2. Semua data terkait user (token, catatan fawaidh, runtutan dzikir, dsb.)
   ikut terhapus — reviewer bisa memeriksa ini.
3. Endpoint menolak permintaan tanpa token (401), dan **tidak** menghapus
   akun pengguna lain.

Cara mengujinya sebelum kirim ke App Store:

```bash
TOKEN=<token-login-dari-aplikasi>
curl -X DELETE https://api.pusatoleolehpekanbaru.id/api/auth/account \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" -i
```

Halaman web `hapus-akun.html` tetap boleh dipertahankan sebagai penjelasan
tambahan, tapi tidak bisa menggantikan tombol di dalam aplikasi.

### 6.7 Privacy manifest & export compliance — ✅ sudah beres

Dua berkas/hal yang berhubungan dengan pertanyaan Apple saat upload:

- `ios/Runner/PrivacyInfo.xcprivacy` mendeklarasikan `NSPrivacyTracking = false`,
  data yang dikumpulkan (nama, email, user ID — semuanya terkait akun, bukan
  untuk tracking), serta required-reason API yang dipakai
  (`UserDefaults`, `FileTimestamp`, `SystemBootTime`, `DiskSpace`). Berkas ini
  sudah masuk ke **Build Phases → Copy Bundle Resources**.
- `ITSAppUsesNonExemptEncryption = false` di `Info.plist`, karena aplikasi
  hanya memakai HTTPS standar. Tanpa itu, App Store Connect menanyakan export
  compliance untuk setiap build.

Kalau nanti menambah SDK/paket baru, periksa apakah manifest-nya perlu
diperbarui (biasanya paket Flutter sudah membawa `PrivacyInfo.xcprivacy`
sendiri lewat CocoaPods/SPM).

---

## 7. Uji di iPhone asli

1. Colok iPhone ke Mac, pilih **Trust** di iPhone.
2. Di iPhone: **Settings → Privacy & Security → Developer Mode → On**
   (iPhone akan restart; hanya muncul setelah terhubung ke Xcode sekali).
3. `flutter devices` untuk melihat nama iPhone.
4. `flutter run -d "nama-iphone" --dart-define=API_BASE_URL=https://api.pusatoleolehpekanbaru.id/api`

Kalau muncul "Untrusted Developer": di iPhone buka **Settings → General →
VPN & Device Management → Developer App → Trust**.

Yang **wajib** dicoba di HP asli: AR Kiblat (kamera), kompas, notifikasi adzan,
dzikir, login Google, login Apple, unggah/bagikan.

---

## 8. Build untuk TestFlight / App Store

Naikkan dulu nomor build di `pubspec.yaml` (sama seperti `versionCode` di
Android — Apple juga menolak nomor build yang sudah pernah dipakai):

```yaml
version: 1.0.0+13
```

Cara tercepat, pakai skrip yang sudah ada di repo (naikkan build number
sekaligus kalau perlu):

```bash
export GOOGLE_WEB_CLIENT_ID=<client-id-web-yang-dipakai-backend>
BUILD_NUMBER=14 ./deploy/ios/build-ipa.sh
```

Skrip itu menjalankan `flutter clean`, `flutter pub get`, `pod install`, lalu
`flutter build ipa --release` dengan `--dart-define` yang benar.

Kalau ingin manual:

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..

flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.pusatoleolehpekanbaru.id/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<client-id-web-yang-dipakai-backend>
```

Hasil build:

- `build/ios/archive/Runner.xcarchive`
- `build/ios/ipa/*.ipa`

Cara mengirim:

- **Cara 1 (paling gampang):** `open build/ios/archive/Runner.xcarchive` →
  Xcode terbuka → tombol **Distribute App** → **App Store Connect** →
  **Upload**.
- **Cara 2:** unduh aplikasi **Transporter** dari Mac App Store, lalu seret
  file `.ipa` ke sana.

Setelah upload, tunggu 5–30 menit sampai build muncul di App Store Connect →
TestFlight, baru bisa diundang ke tester.

### Membuat aplikasi di App Store Connect (sekali saja)

1. <https://appstoreconnect.apple.com> → **My Apps → + → New App**.
2. **Bundle ID** pilih `id.insyira.muslimapp`.
3. Isi nama, bahasa utama (Indonesia), kategori (mis. Lifestyle/Education).
4. Siapkan: deskripsi, kata kunci, **URL kebijakan privasi** (wajib),
   screenshot iPhone 6,9" dan 6,5", ikon App Store, usia minimum.
5. **App Privacy**: isi data apa yang dikumpulkan (email, nama, lokasi).
6. Kalau aplikasi punya pendaftaran akun, Apple mewajibkan fitur **hapus
   akun** di dalam aplikasi.

Catatan khusus Indonesia: aplikasi yang beredar di Indonesia perlu terdaftar
**PSE Kominfo**. Prosesnya lewat <https://pse.kominfo.go.id> (butuh NIB/akta
usaha). Ini terpisah dari proses Apple.

---

## 9. Pemecahan masalah yang paling sering

| Gejala | Penyebab & solusi |
|---|---|
| `Signing for "Runner" requires a development team` | Bagian 5.1 belum selesai — isi **Team**. |
| `No such module 'xxx'` / `module not found` | Buka `.xcworkspace` yang salah, atau `pod install` belum jalan. |
| `pod install` gagal soal versi minimum iOS | Naikkan `IPHONEOS_DEPLOYMENT_TARGET` di `Podfile` (Bagian 6.1) dan di Xcode (5.3). |
| Aplikasi terbuka tapi semua data kosong | Build tanpa `--dart-define=API_BASE_URL=...`. |
| Tombol AR Kiblat tidak bereaksi | `pod install` belum dijalankan, atau izin kamera ditolak di iOS Settings. Cek `ios/Podfile` memuat `PERMISSION_CAMERA=1`. |
| Notifikasi adzan tidak bersuara | Pastikan `adzan.caf` ada di **Target → Runner → Build Phases → Copy Bundle Resources**. Ingat juga, iPhone dalam mode senyap **mematikan** suara notifikasi. |
| Login Google gagal di iOS | Bagian 6.3 (GIDClientID + URL scheme) belum ada. |
| Login Apple error `authorization failed` | Capability Sign in with Apple (5.2) belum aktif, atau pakai akun gratis (kadang tidak tersedia). |
| `Unable to boot the Simulator` | Tutup Simulator, jalankan `xcrun simctl shutdown all`, buka lagi. |
| Build sangat lambat / Mac panas | Wajar pada build pertama; berikutnya jauh lebih cepat. |

---

## 10. Urutan singkat (ringkasan)

```bash
# di Windows
git add -A && git commit -m "..." && git push origin main

# di Mac
git clone https://github.com/dzaii-hud/insyira-muslim-app.git
cd insyira-muslim-app
flutter pub get
cd ios && pod install && cd ..
open -a Simulator
flutter run --dart-define=API_BASE_URL=https://api.pusatoleolehpekanbaru.id/api

# setelah Bagian 5 & 6 selesai
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.pusatoleolehpekanbaru.id/api
open build/ios/archive/Runner.xcarchive   # Distribute App → App Store Connect
```
