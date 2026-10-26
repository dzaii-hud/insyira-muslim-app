package id.insyira.muslimapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * Widget "Jadwal Kajian" di layar utama.
 *
 * Sama seperti widget jadwal sholat: widget ini TIDAK memanggil API sendiri.
 * Aplikasi menyimpan satu kajian terdekat (judul, waktu, ustadz, lokasi), dan
 * widget hanya menampilkannya.
 *
 * Kalau aplikasi lama tidak dibuka, kajian yang tampil bisa saja sudah lewat.
 * Itu keterbatasan yang diterima dengan sadar — menampilkan data lama jauh
 * lebih ringan daripada membuat widget memanggil jaringan sendiri (yang gagal
 * diam-diam saat sinyal jelek dan menghabiskan baterai).
 */
class JadwalKajianWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_jadwal_kajian)
            isiTampilan(widgetData, views)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetKetuk.bukaAplikasi(context),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun isiTampilan(widgetData: SharedPreferences, views: RemoteViews) {
        val mentah = widgetData.getString(KUNCI_DATA, null)

        if (mentah.isNullOrEmpty()) {
            tampilkanKosong(views, "Buka aplikasi Insyira untuk memuat jadwal kajian")
            return
        }

        try {
            val data = JSONObject(mentah)

            if (!data.optBoolean("ada", false)) {
                tampilkanKosong(views, "Belum ada jadwal kajian berikutnya")
                return
            }

            views.setTextViewText(R.id.kajian_judul, data.optString("judul", "Kajian"))
            views.setTextViewText(R.id.kajian_waktu, data.optString("waktu", ""))
            views.setTextViewText(R.id.kajian_ustadz, data.optString("ustadz", ""))
            views.setTextViewText(R.id.kajian_lokasi, data.optString("lokasi", ""))
            views.setTextViewText(R.id.kajian_status, "")
        } catch (e: Exception) {
            // Data rusak -> jangan menampilkan sesuatu yang tidak bisa dipercaya.
            tampilkanKosong(views, "Buka aplikasi Insyira untuk memuat jadwal kajian")
        }
    }

    private fun tampilkanKosong(views: RemoteViews, pesan: String) {
        views.setTextViewText(R.id.kajian_judul, "Jadwal Kajian")
        views.setTextViewText(R.id.kajian_waktu, "")
        views.setTextViewText(R.id.kajian_ustadz, "")
        views.setTextViewText(R.id.kajian_lokasi, "")
        views.setTextViewText(R.id.kajian_status, pesan)
    }

    private companion object {
        const val KUNCI_DATA = "kajian_terdekat_json"
    }
}
