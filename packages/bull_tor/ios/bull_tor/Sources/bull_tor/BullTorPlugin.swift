import Flutter
import Foundation

public final class BullTorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    excludeTorStateFromBackup()
  }

  private static func excludeTorStateFromBackup() {
    do {
      var torStateURL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appendingPathComponent("tor_state", isDirectory: true)
      try FileManager.default.createDirectory(
        at: torStateURL,
        withIntermediateDirectories: true,
        attributes: nil
      )

      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      try torStateURL.setResourceValues(resourceValues)
    } catch {
      NSLog("Failed to exclude Tor state from backup: %@", error.localizedDescription)
    }
  }
}
