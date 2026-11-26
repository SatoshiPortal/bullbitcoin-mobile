import Flutter
import Sentry

public final class BullReportingPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "bullbitcoin/bull_reporting",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(BullReportingPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let dsn = call.arguments as? String, !dsn.isEmpty else {
                result(FlutterError(code: "invalid_dsn", message: "Expected a nonempty DSN.", details: nil))
                return
            }
            SentrySDK.start { options in
                options.dsn = dsn
                options.enableLogs = false
                options.enableMetrics = false
                options.sendDefaultPii = false
                options.enableCaptureFailedRequests = false
                options.attachScreenshot = false
                options.attachViewHierarchy = false
                options.shutdownTimeInterval = 0
            }
            result(nil)
        case "close":
            SentrySDK.close()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
