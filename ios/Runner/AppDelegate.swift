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
      withIdentifier: "com.bullbitcoin.app.bitcoinSync",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.app.liquidSync",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.app.swapsSync",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.app.logsPrune",
      frequency: NSNumber(value: 20 * 60)
    )
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.bullbitcoin.app.servicesCheck",
      frequency: NSNumber(value: 20 * 60)
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
