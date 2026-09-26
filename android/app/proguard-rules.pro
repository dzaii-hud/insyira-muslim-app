# =============================================================================
# ATURAN R8 / PROGUARD  —  WAJIB, JANGAN DIHAPUS
# =============================================================================
#
# Kenapa berkas ini ada
# ---------------------
# Plugin `flutter_local_notifications` menyimpan daftar notifikasi terjadwal ke
# SharedPreferences memakai Gson:
#
#     new TypeToken<ArrayList<NotificationDetails>>() {}.getType()
#
# Cara itu bergantung pada atribut `Signature` milik kelas anonim TypeToken
# tersebut. Pada build RILIS, R8 membuang atribut itu, sehingga Gson melempar:
#
#     java.lang.RuntimeException: Missing type parameter
#
# Masalahnya, `loadScheduledNotifications()` dipanggil oleh SEMUA jalur penting:
#
#     zonedSchedule()  -> saveScheduledNotification()  -> loadScheduledNotifications()
#     cancel(id)       -> removeNotificationFromCache() -> loadScheduledNotifications()
#     cancelAll()      -> cancelAllNotifications()      -> loadScheduledNotifications()
#
# Jadi di build rilis SELURUH penjadwalan notifikasi gagal — adzan tidak pernah
# dijadwalkan, pengingat dzikir juga tidak. Di build debug semuanya tampak
# normal, jadi bug ini hanya muncul di aplikasi yang benar-benar dibagikan ke
# pengguna. Terbukti lewat `adb logcat -s flutter` pada APK rilis 26 Sep 2026.
#
# ⚠️ Kalau berkas ini dihapus atau tidak didaftarkan di `build.gradle.kts`,
#    adzan akan mati lagi DI BUILD RILIS SAJA.

# --- Gson: butuh informasi tipe generik tetap utuh ---
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# --- Model & kelas plugin notifikasi ---
# buildGson() memakai RuntimeTypeAdapterFactory.registerSubtype(...) yang
# menyimpan NAMA KELAS sebagai penanda tipe di dalam JSON. Karena itu kelas
# plugin sengaja TIDAK diobfuskasi: kalau namanya berubah, jadwal notifikasi
# yang sudah tersimpan di HP tidak bisa dibaca lagi.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
