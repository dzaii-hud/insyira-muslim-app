# Panduan Deploy Insyira ke Railway

Dokumen ini menjelaskan cara memasang **dua layanan** Insyira di Railway
beserta database-nya. Ikuti berurutan — urutannya penting.

## Alamat yang sudah berjalan

| Untuk apa         | Alamat                                               |
| ----------------- | ---------------------------------------------------- |
| Aplikasi (jamaah) | https://insyiramuslimapp.pusatoleolehpekanbaru.id    |
| Panel admin       | https://api.pusatoleolehpekanbaru.id/admin/dashboard |
| API               | https://api.pusatoleolehpekanbaru.id/api             |
| Web (cadangan)    | https://insyira-web-production.up.railway.app        |
| API (cadangan)    | https://insyira-production.up.railway.app            |

Akun admin: `zafahudzaifah@gmail.com` — passwordnya dipilih sendiri oleh pemilik
akun lewat menu *Daftar* di aplikasi (lihat A.6).

> **`pusatoleolehpekanbaru.id` bukan alamat aplikasi ini.** Domain itu milik
> katalog toko dan di-host terpisah di Hostinger. Aplikasi Insyira memakai
> subdomain `insyiramuslimapp`, sehingga keduanya tidak saling mengganggu.
> Perhatikan ejaannya: domain itu hanya punya satu "oleh".

---

## 1. Gambaran

Ada **tiga** yang dipasang di Railway:

| Nama layanan  | Isi                        | Sumber kode                  | Cara deploy    |
| ------------- | -------------------------- | ---------------------------- | -------------- |
| `insyira-api` | Backend Laravel (API)      | Repo backend (privat)        | Push ke GitHub |
| `insyira-web` | Aplikasi Flutter versi web | Repo ini, folder `build/web` | `railway up`   |
| `Postgres`    | Database                   | Plugin Railway               | —              |

Plus satu hal di luar Railway:

| Kebutuhan      | Untuk apa                                      |
| -------------- | ---------------------------------------------- |
| Object storage | Menyimpan foto ustadz (Railway Bucket / R2 S3) |

### Kenapa harus ada Postgres dan object storage?

Railway menjalankan aplikasi di dalam container, dan **isi container dihapus
setiap kali deploy**. Artinya:

* database SQLite beserta seluruh isinya akan hilang,
* foto ustadz yang diunggah lewat panel admin juga akan hilang.

Karena itu keduanya harus berada di luar container: database di layanan
Postgres, foto di object storage.

### Kenapa web dan backend dipisah?

Backend harus bisa diakses publik lebih dulu, karena aplikasi web tidak ada
gunanya sebelum API-nya bisa dipanggil dari internet. Memisahkan keduanya juga
membuat perubahan di satu sisi tidak memaksa deploy ulang sisi lainnya.

**Urutan pengerjaan: backend dulu, baru web.**

---

## 2. Bagian A — Backend (`insyira-api`)

Semua perintah di bagian ini dijalankan di folder repo backend, bukan di
folder Flutter ini.

### A.1. Buat layanan di Railway

1. Buka [railway.app](https://railway.app) → **New Project** →
   **Deploy from GitHub repo** → pilih repo backend.
2. Railway otomatis mengenali `Dockerfile` dan `railway.json`, jadi tidak ada
   yang perlu diatur di bagian build.

### A.2. Tambahkan database

Di dalam project yang sama: **New** → **Database** → **Add PostgreSQL**.

Layanan Postgres akan menambahkan variabel `DATABASE_URL` ke project.
Variabel itu **tidak** otomatis masuk ke layanan `insyira-api` — lihat
langkah berikut.

### A.3. Isi variabel lingkungan

Buka layanan `insyira-api` → tab **Variables**. Tambahkan satu per satu.

> **Cara menghubungkan ke database:** di halaman Variables, ketik
> `DATABASE_URL` lalu pilih opsi *Add Reference* → `Postgres.DATABASE_URL`.
> Jangan menyalin nilainya secara manual: alamat internal bisa berubah, dan
> referensi akan selalu ikut yang terbaru.

#### Wajib

| Variabel        | Nilai                                   |
| --------------- | --------------------------------------- |
| `APP_ENV`       | `production`                            |
| `APP_DEBUG`     | `false`                                 |
| `APP_KEY`       | hasil `php artisan key:generate --show` |
| `APP_URL`       | `https://<domain-api>` (lihat A.5)      |
| `APP_NAME`      | `Insyira`                               |
| `DATABASE_URL`  | *Reference* → `Postgres.DATABASE_URL`   |
| `DB_CONNECTION` | `pgsql`                                 |
| `FOTO_DISK`     | `s3`                                    |

`APP_DEBUG=false` adalah yang paling penting: kalau dibiarkan `true`, siapa
pun yang memicu error akan melihat isi `.env`, password database, dan semua
kunci rahasia di halaman error.

#### Rahasia yang sudah ada sebelumnya

| Variabel                                                               | Keterangan             |
| ---------------------------------------------------------------------- | ---------------------- |
| `QURAN_CLIENT_ID`, `QURAN_CLIENT_SECRET`                               | dari Developer Console |
| `QURAN_ENV`                                                            | `production`           |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_ALLOWED_AUDIENCES` | login Google           |
| `APPLE_CLIENT_ID`, `APPLE_CLIENT_SECRET`                               | login Apple            |

Salin nilainya dari file `.env` di komputer — **jangan** dari repo, karena
`.env` sengaja tidak ikut di-commit.

#### Object storage (foto ustadz)

Isi setelah langkah A.4:

| Variabel                      | Nilai                                      |
| ----------------------------- | ------------------------------------------ |
| `AWS_ACCESS_KEY_ID`           | dari dashboard object storage              |
| `AWS_SECRET_ACCESS_KEY`       | idem                                       |
| `AWS_BUCKET`                  | nama bucket                                |
| `AWS_ENDPOINT`                | alamat endpoint S3-compatible              |
| `AWS_DEFAULT_REGION`          | biasanya `auto`                            |
| `AWS_USE_PATH_STYLE_ENDPOINT` | `true` (wajib untuk S3-compatible non-AWS) |

#### CORS dan alamat web

Isi **setelah** alamat web diketahui (bagian B). Sementara ini bisa dikosongkan.

| Variabel               | Nilai                                     |
| ---------------------- | ----------------------------------------- |
| `CORS_ALLOWED_ORIGINS` | `https://<domain-web>` (jangan pakai `*`) |
| `INSYIRA_WEB_URL`      | `https://<domain-web>`                    |

### A.4. Buat object storage

Di Railway: **New** → **Bucket** (atau layanan object storage S3-compatible
lain seperti Cloudflare R2).

Setelah bucket dibuat, salin kredensialnya (Access Key, Secret Key, Endpoint,
nama bucket) ke variabel di A.3, lalu **redeploy** layanan `insyira-api`.

> Kalau Railway belum menyediakan Bucket di paket kamu, **Railway Volume** bisa
> jadi jalan sementara: pasang volume di `/app/storage/app/public` dan biarkan
> `FOTO_DISK=public`. Cara ini lebih sederhana, tapi terikat pada satu layanan
> dan tidak bisa dibagi.

### A.5. Buka akses publik

Di layanan `insyira-api`: **Settings** → **Networking** → **Generate Domain**.

Railway memberikan alamat seperti `insyira-api-production.up.railway.app`.
Alamat ini yang dipakai sebagai `APP_URL`.

Kalau punya domain sendiri: **Custom Domain** → arahkan
`api.namadomain.com` (CNAME) ke alamat Railway tersebut.

Setelah alamat pasti, perbarui juga:

* `APP_URL` → `https://<alamat>`
* `GOOGLE_REDIRECT_URI` → `https://<alamat>/api/auth/google/callback`
* `APPLE_REDIRECT_URI` → `https://<alamat>/api/auth/apple/callback`

### A.6. Buat akun admin

Migrasi berjalan otomatis setiap container dinyalakan, tapi **tidak ada satu pun
akun yang dibuat** — termasuk akun admin. Database benar-benar kosong.

**Langkah 1 — buat akunnya dari aplikasi.** Buka alamat web, klik *Daftar
Sekarang*, isi nama, email, dan password pilihanmu. Password tidak pernah perlu
diketahui siapa pun selain kamu.

**Langkah 2 — jadikan admin.** Lewat terminal di komputer, di folder repo
backend:

```powershell
$kode = @'
$u = App\Models\User::where("email", "emailkamu@gmail.com")->first();
$u->is_admin = true;
$u->save();
echo "is_admin=" . ($u->is_admin ? "true" : "false") . PHP_EOL;
'@

$kode | railway ssh -s insyira php artisan tinker
```

Kalau berhasil, keluarannya: `is_admin=true`.

> **Kenapa lewat SSH, bukan `php artisan tinker` di dashboard Railway?**
> Keduanya bisa. SSH lebih enak karena kodenya bisa dikirim lewat stdin
> (lihat contoh di atas), sehingga tidak ada masalah tanda kutip bersarang —
> masalah yang muncul kalau perintah panjang dikirim sebagai argumen.

**Kalau SSH belum bisa dipakai:**

```powershell
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -C insyira-deploy
railway ssh -s insyira echo halo     # akan menawarkan mendaftarkan kunci -> jawab Y
```

Atau tanpa SSH sama sekali: pakai terminal di **dashboard Railway**
(layanan `insyira` → ikon terminal) lalu jalankan `php artisan tinker`.

Setelah itu login di `/admin/dashboard`. Halaman itu akan mengalihkan ke
`/login` selama belum masuk — perilaku normal, bukan error.

### A.7. Verifikasi

```sh
# dari komputer sendiri
curl https://<alamat-api>/up
curl https://<alamat-api>/api/kajian
```

`/up` harus membalas status 200. `/api/kajian` harus membalas `[]` (array
kosong) untuk database yang masih baru.

---

## 3. Bagian B — Web (`insyira-web`)

### B.1. Pasang Railway CLI

Belum terpasang di komputer ini. Node.js sudah tersedia, jadi:

```powershell
npm install -g @railway/cli
railway login
```

### B.2. Buat layanan web

```powershell
cd <folder proyek Flutter ini>
railway init
```

Beri nama project yang sama dengan backend kalau mau (boleh juga project
terpisah), lalu pilih **Empty Service**.

Patokan saat `railway up` nanti:

* yang diunggah = **hanya** folder `deploy/web/context/` (dibuat oleh skrip),
* Dockerfile = `deploy/web/Dockerfile` (disalin ke folder konteks),
* isi image = isi folder konteks, yaitu `html/` ≈ 252 MB.

> **Kenapa pakai folder konteks, bukan menyaring dengan berkas abaikan?**
>
> Seluruh proyek ini 3,5 GB — `build/` untuk platform lain saja 2,98 GB,
> sedangkan yang dibutuhkan image web hanya 252 MB.
>
> Percobaan pertama menyaringnya dengan `.railwayignore`, dan hasilnya rapuh:
> pada suatu percobaan Dockerfile-nya sendiri ikut terbuang sehingga Railway
> gagal dengan `couldn't locate the dockerfile ... in code archive`, dan yang
> terkirim cuma 12 MB dari 252 MB yang seharusnya.
>
> Folder konteks menghapus seluruh ketergantungan itu — yang diunggah memang
> hanya folder tersebut, jadi tidak ada berkas abaikan yang bisa salah.

### B.3. Deploy

```powershell
.\deploy\web\deploy.ps1 -ApiBaseUrl https://<alamat-api>/api
```

Skrip itu melakukan tiga hal: `flutter build web --release`, menulis
`build/web/config.json` berisi alamat API, lalu `railway up`.

> **Alamat API wajib diakhiri `/api`.** Skrip akan menolak jalan kalau tidak.

Kalau mau login Google ikut aktif di web, tambahkan:

```powershell
.\deploy\web\deploy.ps1 `
    -ApiBaseUrl https://<alamat-api>/api `
    -GoogleWebClientId 1234567890-xxxxxxxx.apps.googleusercontent.com
```

### B.4. Buka akses publik

Sama seperti backend: **Settings** → **Networking** → **Generate Domain**.

### B.5. Kembali ke backend

Setelah alamat web diketahui, isi di layanan `insyira-api`:

| Variabel               | Nilai                  |
| ---------------------- | ---------------------- |
| `CORS_ALLOWED_ORIGINS` | `https://<alamat-web>` |
| `INSYIRA_WEB_URL`      | `https://<alamat-web>` |

Tanpa ini, browser akan memblokir semua permintaan dari web ke API.

---

## 4. Alamat API tanpa build ulang

Aplikasi web membaca `config.json` **setiap kali halaman dibuka**, bukan saat
build. Jadi kalau alamat backend berubah:

1. edit `config.json` di server (atau jalankan ulang skrip deploy dengan
   `-LewatiBuild`),
2. selesai — tidak perlu `flutter build` ulang.

Hanya versi **web** yang punya kemudahan ini. Aplikasi Android/iOS tetap
memerlukan build baru karena nilainya terpaket di dalam aplikasi
(`--dart-define=API_BASE_URL=...`).

---

## 5. Ringkasan alur deploy berikutnya

| Yang diubah            | Cara deploy                                                     |
| ---------------------- | --------------------------------------------------------------- |
| Kode backend (Laravel) | `git push` — Railway membangun ulang otomatis                   |
| Kode web (Flutter)     | `.\deploy\web\deploy.ps1 -ApiBaseUrl <alamat>/api`              |
| Hanya alamat API web   | `.\deploy\web\deploy.ps1 -ApiBaseUrl <alamat>/api -LewatiBuild` |
| Variabel lingkungan    | Ubah di dashboard Railway → layanan restart sendiri             |
| Isi database           | Lewat panel admin `/admin/dashboard`                            |

---

## 6. Pemecahan masalah

### Container backend gagal start dengan pesan `APP_KEY belum diisi`

Isi variabel `APP_KEY` di Railway. Buat nilainya dengan:

```sh
php artisan key:generate --show
```

Jalankan di komputer (folder repo backend). Hasilnya berupa
`base64:...` — salin seluruh baris termasuk `base64:`.

### Halaman web terbuka tapi semua data kosong / login gagal

Berarti alamat API di `config.json` salah atau CORS belum diisi. Periksa:

1. buka `https://<alamat-web>/config.json` di browser — pastikan
   `apiBaseUrl` benar dan berakhiran `/api`,
2. buka DevTools → Console — error CORS akan terlihat di sana,
3. pastikan `CORS_ALLOWED_ORIGINS` di backend berisi alamat web **tanpa**
   garis miring di akhir.

### Web tidak bisa memanggil API: "Mixed Content"

Halaman web dibuka lewat `https`, tapi `apiBaseUrl` masih `http`. Browser
memblokirnya. Alamat API wajib `https`.

### Foto ustadz hilang setiap deploy

`FOTO_DISK` masih `public`, atau kredensial object storage salah. Cek
variabel `FOTO_DISK` = `s3` dan `AWS_*` sudah terisi. Lihat log container:
kegagalan akses bucket akan tercatat di sana.

### Perubahan `.env`/Variables tidak terbaca

Container backend men-cache konfigurasi saat start. Setelah mengubah
variabel di dashboard, lakukan **Redeploy** pada layanan tersebut.

### `flutter build web` lambat / folder build besar

Wajar — di dalamnya ada 604 font mushaf QCF (total ~198 MB). Yang diunduh
pengguna hanya font halaman yang dibuka, tapi ukuran foldernya tetap besar.
Ini juga sebabnya deploy web mengirim ~250 MB setiap kali.

### Deploy web terasa lama saat mengunggah

Wajar — isinya memang ~252 MB, mayoritas font mushaf QCF. Yang tidak wajar
adalah kalau angkanya jauh lebih besar: periksa baris `isi konteks:` yang
dicetak skrip di langkah `[2/4]`. Kalau jauh di atas 252 MB, berarti ada yang
salah di penyalinan folder konteks.

### Deploy web gagal: `couldn't locate the dockerfile ... in code archive`

Berarti Dockerfile tidak ikut terunggah. Pastikan `deploy/web/Dockerfile` ada,
lalu jalankan ulang lewat `deploy/web/deploy.ps1` (jangan `railway up` polos) —
skrip itu yang menyiapkan folder konteks beserta Dockerfile-nya.
