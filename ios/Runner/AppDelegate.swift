import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Diwajibkan flutter_local_notifications. Tanpa ini iOS tidak menampilkan
    // notifikasi yang jatuh saat aplikasi sedang dibuka, dan ketukan pada
    // notifikasi tidak diteruskan ke aplikasi (di Android perilaku itu bawaan).
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
