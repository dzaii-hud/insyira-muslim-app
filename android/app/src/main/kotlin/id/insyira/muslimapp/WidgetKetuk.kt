package id.insyira.muslimapp

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Penanganan ketukan pada widget.
 *
 * Widget yang tidak bisa diketuk membuat pengguna buntu: melihat jadwal tapi
 * tidak tahu harus ke mana untuk detailnya. Karena itu seluruh permukaan widget
 * dibuat membuka aplikasi.
 */
internal object WidgetKetuk {

    /** PendingIntent untuk membuka aplikasi Insyira. */
    fun bukaAplikasi(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            // CLEAR_TOP supaya tidak menumpuk aktivitas baru setiap kali diketuk;
            // NEW_TASK wajib karena widget berjalan di luar tugas aplikasi.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
