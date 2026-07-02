import 'package:flutter/widgets.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Enables screen-capture privacy for as long as [child] is mounted, and wraps
/// it in [ExcludeSemantics] so the secret never reaches the accessibility tree
/// (or a screen reader). Privacy is enabled in `initState` and disabled in
/// `dispose` — NOT in an async `FutureBuilder` (the live app's racy pattern the
/// audit flagged, where a frame could render before `screenshotOff` resolves).
///
/// Screen-capture blocking is best-effort (Apple offers no guaranteed block);
/// `no_screenshot` calls are swallowed if the platform channel is unavailable
/// (e.g. in widget tests) so the seal never depends on them succeeding.
///
/// APP-SWITCHER SNAPSHOT: the OS snapshots the app when it backgrounds, and on
/// iOS `FLAG_SECURE` does not cover that snapshot. So whenever the app is not
/// `resumed` the child is covered by an opaque box — the secret never appears
/// in the multitasking thumbnail. The child stays in the tree (kept under the
/// cover via a passthrough `Stack`) so its state/identity survive backgrounding
/// and it is not re-read on resume.
class PrivacyGuard extends StatefulWidget {
  const PrivacyGuard({super.key, required this.child});
  final Widget child;

  /// Test seam for the `no_screenshot` side effect. Production leaves this null
  /// and the real platform channel is used; a test can inject a spy to assert
  /// the ref-counted enable/disable transitions without a platform channel.
  @visibleForTesting
  static void Function({required bool enabled})? debugSetCapture;

  /// Key of the opaque cover painted over the child while backgrounded.
  @visibleForTesting
  static const coverKey = Key('privacy_guard_cover');

  @override
  State<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends State<PrivacyGuard>
    with WidgetsBindingObserver {
  /// `no_screenshot` is a GLOBAL, non-ref-counted singleton. If two guards are
  /// mounted at once, a naive `screenshotOn()` in one's `dispose` would re-enable
  /// capture while the other's secret is still visible. Ref-count so capture is
  /// blocked while ANY guard is mounted and only re-enabled when the LAST one
  /// unmounts.
  static int _mounted = 0;

  /// True while the app is not foreground-`resumed`: cover the child so the
  /// secret is absent from the OS app-switcher snapshot.
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seed from the CURRENT lifecycle state — a guard mounted while the app is
    // already backgrounded must cover immediately, or the OS snapshots the secret
    // on the first frame.
    _obscured = WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    if (_mounted++ == 0) _set(enabled: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (--_mounted == 0) _set(enabled: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscure = state != AppLifecycleState.resumed;
    if (obscure != _obscured) setState(() => _obscured = obscure);
  }

  void _set({required bool enabled}) {
    final override = PrivacyGuard.debugSetCapture;
    if (override != null) {
      override(enabled: enabled);
      return;
    }
    // Fire-and-forget in an async wrapper so async MissingPluginExceptions
    // (e.g. Linux desktop) are caught here, not escaped to the zone handler.
    Future<void> apply() async {
      try {
        final ns = NoScreenshot.instance;
        await (enabled ? ns.screenshotOff() : ns.screenshotOn());
      } catch (_) {
        // Best-effort: platform channel may be absent (tests / unsupported OS).
      }
    }
    apply();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        // Passthrough so the child lays out exactly as it would unwrapped; the
        // opaque cover is painted over it only while backgrounded.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (_obscured)
              const Positioned.fill(
                child: ColoredBox(
                    key: PrivacyGuard.coverKey, color: Color(0xFF000000)),
              ),
          ],
        ),
      );
}
