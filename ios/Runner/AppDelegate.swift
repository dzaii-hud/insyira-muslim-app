import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Diwajibkan flutter_local_notifications. Tanpa ini iOS tidak menampilkan
    // notifikasi yang jatuh saat aplikasi sedang dibuka, dan ketukan pada
    // notifikasi tidak diteruskan ke aplikasi (di Android perilaku itu bawaan).
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
