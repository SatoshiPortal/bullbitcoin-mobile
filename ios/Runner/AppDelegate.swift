import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeSensitiveFilesFromBackup()

    // workmanager_apple spawns a separate FlutterEngine per background task
    // (see BackgroundWorker.swift in workmanager_apple). Plugins registered
    // on the main engine only attach to that engine — the BG engine starts
    // with an empty plugin registry. Without this callback, every
    // platform-channel call from tasksHandler (shared_preferences,
    // flutter_secure_storage, drift, lwk, etc.) fails with `channel-error`
    // "Unable to establish connection on channel: ...". Registering the
    // generated registrant against the BG engine makes all plugins usable
    // in the BG isolate.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // BGTaskScheduler only delivers a task to a relaunched app if its launch
    // handler is registered before `didFinishLaunching` returns. Under the
    // UIScene lifecycle plugins register later (on scene connection), so the
    // plugin's own re-registration comes too late; workmanager_apple asks
    // scene apps to call this here.
    WorkmanagerPlugin.registerLaunchHandlers()

    // A fresh install has no saved tasks, so register the ones Dart schedules on iOS (they must be in Info.plist).
    for identifier in [
      "com.bullbitcoin.mobile.wallets-sync-id",
      "com.bullbitcoin.mobile.logs-prune-id",
    ] {
      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: identifier)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene lifecycle: Flutter creates the main engine after
  // `didFinishLaunching`, so plugins are registered here instead.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func excludeSensitiveFilesFromBackup() {
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return
    }

    // Wallet, payjoin, wallet-engine, and TSV log data all live below Documents.
    // Excluding the directory also covers wallet directories created after startup.
    var documentsURL = documentsDirectory
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    // `setResourceValues` is `mutating`, so it needs a `var` receiver.
    // URLResourceValues.isExcludedFromBackup sets NSURLIsExcludedFromBackupKey.
    try? documentsURL.setResourceValues(resourceValues)
  }
}
