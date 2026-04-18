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

    // Register plugins on the background Flutter engine that workmanager_apple
    // spins up to run our Dart `backgroundTasksHandler`. Without this, calls
    // from the handler into flutter_local_notifications, shared_preferences,
    // path_provider, etc. throw MissingPluginException on iOS and the whole
    // Workmanager task fails silently. Android's workmanager wires this up
    // itself; on iOS the host app has to register explicitly.
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
