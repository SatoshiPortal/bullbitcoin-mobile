import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // workmanager_apple spawns a separate FlutterEngine per background task
    // (see BackgroundWorker.swift in workmanager_apple). Plugins registered
    // against `self` above only attach to the main app's engine — the BG
    // engine starts with an empty plugin registry. Without this callback,
    // every platform-channel call from tasksHandler (shared_preferences,
    // flutter_secure_storage, drift, lwk, etc.) fails with `channel-error`
    // "Unable to establish connection on channel: ...". Registering the
    // generated registrant against the BG engine makes all plugins usable
    // in the BG isolate.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.mobile.bitcoin-sync-id",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.mobile.liquid-sync-id",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.mobile.swaps-sync-id",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.mobile.logs-prune-id",
      frequency: NSNumber(value: 20 * 60)
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
