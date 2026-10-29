import Flutter
import Network
import UIKit

/// Main-engine platform capabilities. Wallet and node state remain in shared Dart/native code.
final class CbfMobileRuntimePlugin: NSObject, FlutterPlugin {
  private let monitor = NWPathMonitor()
  private var networkChannel: FlutterMethodChannel?
  private var backgroundChannel: FlutterMethodChannel?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var available = false
  private var metered: Bool?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CbfMobileRuntimePlugin()
    let network = FlutterMethodChannel(
      name: "com.bullbitcoin.mobile/cbf_network", binaryMessenger: registrar.messenger())
    let background = FlutterMethodChannel(
      name: "com.bullbitcoin.mobile/cbf_background", binaryMessenger: registrar.messenger())
    instance.networkChannel = network
    instance.backgroundChannel = background
    registrar.addMethodCallDelegate(instance, channel: network)
    registrar.addMethodCallDelegate(instance, channel: background)
    instance.monitor.pathUpdateHandler = { [weak instance] path in
      DispatchQueue.main.async {
        guard let instance else { return }
        instance.available = path.status == .satisfied
        instance.metered = path.isExpensive || path.isConstrained
        instance.networkChannel?.invokeMethod("changed", arguments: instance.networkState())
      }
    }
    instance.monitor.start(queue: DispatchQueue(label: "com.bullbitcoin.mobile.cbf_network"))
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "read":
      result(networkState())
    case "begin":
      if backgroundTask == .invalid {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Persist compact filter updates") {
          [weak self] in
          guard let self else { return }
          // Native always ends the assertion, even when the Dart engine no longer responds.
          self.backgroundChannel?.invokeMethod("expired", arguments: nil)
          self.endBackgroundTask()
        }
      }
      result(backgroundTask != .invalid)
    case "end":
      endBackgroundTask()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    monitor.cancel()
    endBackgroundTask()
    networkChannel = nil
    backgroundChannel = nil
  }

  private func networkState() -> [String: Any] {
    ["available": available, "metered": metered.map { $0 as Any } ?? NSNull()]
  }

  private func endBackgroundTask() {
    let task = backgroundTask
    backgroundTask = .invalid
    if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
  }
}
