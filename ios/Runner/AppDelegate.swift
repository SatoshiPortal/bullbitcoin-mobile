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
    excludeSensitiveFilesFromBackup()

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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
