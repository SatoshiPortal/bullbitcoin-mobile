import Flutter
import ObjectiveC
import UIKit

/// Streams the iOS shake gesture (the same one that triggers "Shake to Undo")
/// to Dart on the `com.bullbitcoin.user_feedback/shake` event channel.
///
/// iOS delivers the gesture as a motion event, not as accelerometer data, so
/// this also works in the Simulator (Device > Shake). It reads nothing else.
public final class UserFeedbackPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    fileprivate static weak var active: UserFeedbackPlugin?
    private var sink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = UserFeedbackPlugin()
        let channel = FlutterEventChannel(
            name: "com.bullbitcoin.user_feedback/shake",
            binaryMessenger: registrar.messenger()
        )
        channel.setStreamHandler(plugin)
        registrar.publish(plugin)
        active = plugin
        UIWindow.installShakeHook()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    fileprivate func shook() {
        sink?(true)
    }
}

extension UIWindow {
    private static var shakeHookInstalled = false

    /// Puts a shake check in front of UIWindow's `motionEnded`, then runs the
    /// original implementation under its own selector, so the event still
    /// travels up the responder chain exactly as before.
    fileprivate static func installShakeHook() {
        guard !shakeHookInstalled else { return }
        shakeHookInstalled = true

        let cls: AnyClass = UIWindow.self
        let selector = #selector(UIResponder.motionEnded(_:with:))
        guard let method = class_getInstanceMethod(cls, selector) else { return }

        typealias MotionEnded = @convention(c) (AnyObject, Selector, UIEvent.EventSubtype, UIEvent?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: MotionEnded.self)
        let hook: @convention(block) (AnyObject, UIEvent.EventSubtype, UIEvent?) -> Void = { window, motion, event in
            if motion == .motionShake {
                UserFeedbackPlugin.active?.shook()
            }
            original(window, selector, motion, event)
        }
        let hookImplementation = imp_implementationWithBlock(hook)

        // UIWindow normally inherits motionEnded from UIResponder: add the hook
        // to UIWindow only, so other responders are never touched.
        if !class_addMethod(cls, selector, hookImplementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, hookImplementation)
        }
    }
}
