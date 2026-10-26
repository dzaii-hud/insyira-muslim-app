package id.insyira.muslimapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Widget "Jadwal Sholat" di layar utama.
 *
 * ⚠️ Waktu sholat TIDAK dihitung di sini.
 *
 * Perhitungannya memakai algoritma yang sudah ada di sisi Flutter (adhan).
 * Kalau rumusnya ditulis ulang di Kotlin, akan ada DUA sumber kebenaran yang
 * bisa berbeda diam-diam — misalnya satu memakai sudut Fajr 20°, yang lain 18°,
 * dan selisihnya beberapa menit tanpa terlihat. Karena itu aplikasi menyimpan
 * jadwal beberapa hari ke depan, dan widget hanya memilih baris yang tanggalnya
 * hari ini.
 *
 * Konsekuensinya: kalau aplikasi tidak pernah dibuka lebih lama daripada jumlah
 * hari yang disimpan, widget akan menampilkan ajakan membuka aplikasi. Itu
 * sengaja — lebih baik jujur daripada menampilkan jam yang sudah tidak akurat.
 */
class JadwalSholatWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_jadwal_sholat)
            isiTampilan(context, widgetData, views)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetKetuk.bukaAplikasi(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun isiTampilan(
        context: Context,
        widgetData: SharedPreferences,
        views: RemoteViews,
    ) {
        val tanggalIni = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val mentah = widgetData.getString(KUNCI_DATA, null)
        val baris = cariBarisHariIni(mentah, tanggalIni)

        if (baris == null) {
            // Belum ada data, atau datanya sudah kedaluwarsa (aplikasi lama
            // tidak dibuka). Tampilkan ajakan yang jujur, bukan jam karangan.
            views.setTextViewText(R.id.widget_kota, "Insyira")
            views.setTextViewText(
                R.id.widget_tanggal,
                if (mentah == null) "Jadwal belum tersedia" else "Jadwal perlu diperbarui",
            )
            views.setTextViewText(
                R.id.widget_status,
                "Buka aplikasi Insyira sekali untuk mengisi jadwal",
            )
            ID_WAKTU.forEach { id -> views.setTextViewText(id, "--:--") }
            return
        }

        val kota = baris.optString("kota", "")
        val subuh = baris.optString("subuh", "--:--")

        views.setTextViewText(
            R.id.widget_kota,
            if (kota.isEmpty()) "Jadwal Sholat" else kota,
        )
        views.setTextViewText(R.id.widget_tanggal, formatTanggal(tanggalIni))
        views.setTextViewText(R.id.widget_status, "")

        val waktu = listOf(
            subuh to R.id.widget_subuh,
            baris.optString("dzuhur", "--:--") to R.id.widget_dzuhur,
            baris.optString("ashar", "--:--") to R.id.widget_ashar,
            baris.optString("maghrib", "--:--") to R.id.widget_maghrib,
            baris.optString("isya", "--:--") to R.id.widget_isya,
        )

        val sekarang = SimpleDateFormat("HH:mm", Locale.US).format(Date())

        // Sholat berikutnya = waktu pertama yang lebih lambat dari sekarang.
        // Perbandingan teks "HH:mm" sah karena formatnya selalu dua digit.
        var berikut = -1
        for (i in waktu.indices) {
            if (waktu[i].first > sekarang) {
                berikut = i
                break
            }
        }

        waktu.forEachIndexed { i, pasangan ->
            views.setTextViewText(pasangan.second, pasangan.first)
            views.setTextColor(
                pasangan.second,
                if (i == berikut) Color.parseColor("#FBBF24") else Color.WHITE,
            )
        }
    }

    /**
     * Mencari baris jadwal untuk [tanggal] ("yyyy-MM-dd").
     *
     * Aplikasi menyimpan data sebagai satu objek JSON:
     * `{"hari": [{"t": "2026-10-20", "kota": "...", "subuh": "04:38", ...}]}`
     *
     * Kota ikut disimpan PER BARIS, bukan sekali di luar, supaya jadwal beberapa
     * hari tetap konsisten kalau pengguna berpindah lokasi.
     */
    private fun cariBarisHariIni(mentah: String?, tanggal: String): JSONObject? {
        if (mentah.isNullOrEmpty()) return null

        return try {
            val hari: JSONArray = JSONObject(mentah).optJSONArray("hari") ?: return null

            for (i in 0 until hari.length()) {
                val baris = hari.optJSONObject(i) ?: continue
                if (baris.optString("t") == tanggal) return baris
            }
            null
        } catch (e: Exception) {
            // Data rusak (mis. tersimpan tidak lengkap). Jangan sampai widget
            // menampilkan apa pun yang tidak bisa dipercaya.
            null
        }
    }

    private fun formatTanggal(tanggal: String): String {
        return try {
            val masuk = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(tanggal)
            val keluar = SimpleDateFormat("EEEE, d MMM", Locale("id", "ID"))
            if (masuk == null) "Hari ini" else keluar.format(masuk)
        } catch (e: Exception) {
            "Hari ini"
        }
    }

    private companion object {
        const val KUNCI_DATA = "jadwal_sholat_json"

        val ID_WAKTU = listOf(
            R.id.widget_subuh,
            R.id.widget_dzuhur,
            R.id.widget_ashar,
            R.id.widget_maghrib,
            R.id.widget_isya,
        )
    }
}
