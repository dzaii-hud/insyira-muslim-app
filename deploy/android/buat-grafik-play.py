"""Membuat grafik untuk listing Google Play Store.

Menghasilkan dua berkas di `test-file/play-listing/`:

  icon-512.png            512x512  — ikon aplikasi untuk listing
  feature-graphic.png    1024x500  — gambar utama di halaman toko (WAJIB, tanpa transparansi)

Jalankan dari akar proyek Flutter:

    python deploy/android/buat-grafik-play.py

Sumber grafis: `web/icons/Icon-512.png` — hasil generator ikon PWA
(`test-file/generate_pwa_icons.py`) yang sudut putihnya sudah ditambal, sehingga
aman ditempel di atas latar berwarna.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# --- Lokasi berkas -----------------------------------------------------------
AKAR = Path(__file__).resolve().parents[2]
SUMBER_LOGO = AKAR / "web" / "icons" / "Icon-512.png"
FOLDER_KELUARAN = AKAR / "test-file" / "play-listing"

# --- Warna merek -------------------------------------------------------------
HIJAU_TUA = (0, 53, 39)      # 0xFF003527 — warna utama aplikasi
HIJAU_MUDA = (10, 107, 77)   # 0xFF0A6B4D
EMAS = (198, 160, 78)
TEKS_TERANG = (240, 250, 245)
TEKS_REDUP = (168, 223, 198)

FONT_TEBAL = Path(r"C:\Windows\Fonts\segoeuib.ttf")
FONT_BIASA = Path(r"C:\Windows\Fonts\segoeui.ttf")


def buat_gradasi(lebar: int, tinggi: int) -> Image.Image:
    """Gradasi diagonal dari hijau tua (kiri atas) ke hijau muda (kanan bawah)."""
    gambar = Image.new("RGB", (lebar, tinggi))
    piksel = gambar.load()
    for y in range(tinggi):
        for x in range(lebar):
            # Bobot diagonal 0..1
            t = (x / lebar * 0.65) + (y / tinggi * 0.35)
            t = min(1.0, max(0.0, t))
            piksel[x, y] = tuple(
                round(HIJAU_TUA[i] + (HIJAU_MUDA[i] - HIJAU_TUA[i]) * t) for i in range(3)
            )
    return gambar


def teks_tengah(gambar: Image.Image, teks: str, font, y: int, warna) -> None:
    """Menulis teks rata tengah pada posisi x tertentu."""
    draw = ImageDraw.Draw(gambar)
    kotak = draw.textbbox((0, 0), teks, font=font)
    lebar = kotak[2] - kotak[0]
    draw.text((gambar.width // 2 - lebar // 2, y), teks, font=font, fill=warna)


def sudut_membulat(gambar: Image.Image, radius: int) -> Image.Image:
    """Tempelkan sudut membulat pada logo supaya terlihat seperti kartu ikon.

    Logo aslinya persegi dengan tambalan gelap di sudut; kalau ditempel apa
    adanya di atas gradasi, tepinya terlihat seperti kotak yang gagal dibuang.
    """
    topeng = Image.new("L", gambar.size, 0)
    ImageDraw.Draw(topeng).rounded_rectangle(
        [0, 0, gambar.width - 1, gambar.height - 1], radius=radius, fill=255
    )
    hasil = Image.new("RGBA", gambar.size, (0, 0, 0, 0))
    hasil.paste(gambar, (0, 0), topeng)
    return hasil


def buat_feature_graphic() -> Path:
    """1024x500: logo di kiri, nama & fitur di kanan."""
    lebar, tinggi = 1024, 500
    kanvas = buat_gradasi(lebar, tinggi)
    draw = ImageDraw.Draw(kanvas)

    # Logo sebagai kartu ikon bersudut membulat
    sisi = 240
    logo = Image.open(SUMBER_LOGO).convert("RGBA").resize((sisi, sisi), Image.LANCZOS)
    logo = sudut_membulat(logo, radius=54)
    kanvas.paste(logo, (82, 130), logo)

    # Teks di sisi kanan
    font_judul = ImageFont.truetype(str(FONT_TEBAL), 52)
    font_fitur = ImageFont.truetype(str(FONT_BIASA), 25)
    font_kecil = ImageFont.truetype(str(FONT_BIASA), 21)

    kiri_teks = 400
    draw.text((kiri_teks, 160), "Insyira", font=font_judul, fill=TEKS_TERANG)
    lebar_insyira = draw.textbbox((0, 0), "Insyira ", font=font_judul)[2]
    draw.text((kiri_teks + lebar_insyira, 160), "Muslim App", font=font_judul, fill=EMAS)

    # Garis emas pemisah
    draw.rectangle([kiri_teks + 2, 238, kiri_teks + 96, 243], fill=EMAS)

    draw.text((kiri_teks, 268), "Al-Qur'an  •  Jadwal Sholat  •  Kiblat  •  Kajian",
              font=font_fitur, fill=TEKS_REDUP)
    draw.text((kiri_teks, 316), "Dzikir harian, fawaidh, dan kajian video",
              font=font_kecil, fill=TEKS_REDUP)

    FOLDER_KELUARAN.mkdir(parents=True, exist_ok=True)
    tujuan = FOLDER_KELUARAN / "feature-graphic.png"
    # Play TIDAK menerima feature graphic ber-transparansi -> simpan RGB tanpa alpha.
    kanvas.convert("RGB").save(tujuan, format="PNG", optimize=True)
    return tujuan


def siapkan_ikon_512() -> Path:
    """Salin ikon 512 dari paket web (sudah ditambal sudutnya)."""
    FOLDER_KELUARAN.mkdir(parents=True, exist_ok=True)
    tujuan = FOLDER_KELUARAN / "icon-512.png"
    ikon = Image.open(SUMBER_LOGO).convert("RGBA").resize((512, 512), Image.LANCZOS)
    ikon.save(tujuan, format="PNG", optimize=True)
    return tujuan


if __name__ == "__main__":
    print("ikon   :", siapkan_ikon_512())
    print("grafis :", buat_feature_graphic())
    print()
    print("Unggah keduanya di Play Console > Grow > Store listing > Graphics.")
    print("Ukuran yang diminta Play: ikon 512x512, feature graphic 1024x500.")
