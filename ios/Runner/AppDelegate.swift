import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
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
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.mobile.services-check-id",
      frequency: NSNumber(value: 20 * 60)
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
