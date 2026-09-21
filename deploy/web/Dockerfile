# syntax=docker/dockerfile:1
#
# Image layanan WEB Insyira: Nginx yang menyajikan hasil `flutter build web`.
#
# ⚠️ Image ini TIDAK membangun aplikasi Flutter-nya sendiri — ia hanya
# mengemas hasil build yang sudah ada. Karena itu proses deploy selalu
# didahului `flutter build web --release`, dan itu sudah diurus skrip
# `deploy/web/deploy.ps1`.
#
# ── Kenapa build di lokal, bukan di Railway? ─────────────────────────────
# SDK Flutter ~1 GB dan membangun web memakan 10-20 menit. Membangunnya di
# komputer sendiri lalu hanya mengirim hasilnya membuat deploy selesai dalam
# hitungan menit, tanpa menghabiskan jatah waktu build di Railway.
#
# ── Cara berkas ini dipakai ──────────────────────────────────────────────
# Berkas ini TIDAK dibaca langsung dari sini. `deploy.ps1` menyiapkan folder
# konteks kecil (`deploy/web/context/`) berisi:
#
#     context/Dockerfile                <- salinan berkas ini
#     context/nginx.conf.template       <- salinan konfigurasi nginx
#     context/html/                     <- isi build/web
#
# lalu mengunggah HANYA folder itu ke Railway.
#
# Alasannya: seluruh proyek ini 3,5 GB (build/ untuk platform lain saja 2,98 GB),
# sedangkan yang dibutuhkan image ini hanya 252 MB. Menyaring 3,5 GB dengan
# berkas .railwayignore terbukti rapuh — pernah kejadian Dockerfile-nya sendiri
# ikut terbuang sehingga build gagal dengan pesan yang membingungkan. Folder
# konteks menghapus seluruh ketergantungan pada berkas abaikan.

FROM nginx:1.29-alpine

# Hapus server contoh bawaan image. Tanpa ini nginx juga mendengarkan port 80
# dengan konfigurasi yang tidak kita inginkan.
RUN rm -f /etc/nginx/conf.d/default.conf

# ⚠️ Nama berkas WAJIB berakhiran `.template`.
# Entrypoint resmi image nginx menjalankan envsubst pada semua berkas di
# /etc/nginx/templates/*.template, lalu menulis hasilnya ke
# /etc/nginx/conf.d/. Inilah cara $PORT dari Railway masuk ke konfigurasi
# tanpa entrypoint buatan sendiri.
COPY nginx.conf.template /etc/nginx/templates/insyira.conf.template

# Buang karakter CR. Proyek ini dikembangkan di Windows, dan isi folder kerja
# bisa berakhiran CRLF. Nginx masih memaafkannya, tapi hasil substitusi $PORT
# tidak selalu, dan kesalahannya sulit ditelusuri.
RUN sed -i 's/\r$//' /etc/nginx/templates/insyira.conf.template

# Isi aplikasi yang disajikan nginx.
COPY html /usr/share/nginx/html

# Nilai cadangan kalau $PORT tidak diisi (misalnya saat mencoba image ini
# di komputer sendiri). Di Railway, nilai ini otomatis ditimpa.
ENV PORT=8080

EXPOSE 8080

