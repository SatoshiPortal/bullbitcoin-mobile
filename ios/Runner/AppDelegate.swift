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

    // The local SQLite databases are encrypted with a key held in the
    // keychain under `first_unlock_this_device`, which is never restored
    // onto a different device. An iCloud/iTunes backup that carried the
    // databases but not the key would restore a database nothing can
    // open, so the databases are marked "do not back up" instead. See
    // `lib/core/storage/backup_exclusion.dart` for the full rationale.
    //
    // Registered only on the main engine: the workmanager background
    // engine never needs it, and the sweep is driven from the
    // foreground composition root.
    if let controller = window?.rootViewController as? FlutterViewController {
      BackupExclusion.register(messenger: controller.binaryMessenger)
    }

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

/// Sets `URLResourceValues.isExcludedFromBackup` on the paths Dart hands
/// us.
///
/// Lives in `AppDelegate.swift` rather than its own file on purpose:
/// a new `.swift` file has to be added to `project.pbxproj` to be
/// compiled, and a hand-edited pbxproj that silently drops the file
/// would leave the exclusion a no-op with no build error to catch it.
enum BackupExclusion {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "bullbitcoin.com/backup_exclusion",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let paths = arguments["paths"] as? [String]
      else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "excludeFromBackup expects a `paths` list of strings",
            details: nil
          )
        )
        return
      }

      var failures: [String] = []
      for path in paths {
        // Setting the flag on a file that doesn't exist throws, and Dart
        // filters by existence before calling — but the two checks race
        // across the channel hop, so re-check here.
        guard FileManager.default.fileExists(atPath: path) else { continue }
        var url = URL(fileURLWithPath: path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
          try url.setResourceValues(values)
        } catch {
          // Report the failing basename only: the container path
          // contains an install-scoped UUID and this string can end up
          // in a log the user shares.
          failures.append(url.lastPathComponent)
        }
      }

      if failures.isEmpty {
        result(nil)
      } else {
        result(
          FlutterError(
            code: "exclude-failed",
            message: "Could not exclude: \(failures.joined(separator: ", "))",
            details: nil
          )
        )
      }
    }
  }
}
