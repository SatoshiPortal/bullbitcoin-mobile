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
class PrivacyGuard extends StatefulWidget {
  const PrivacyGuard({super.key, required this.child});
  final Widget child;

  @override
  State<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends State<PrivacyGuard> {
  /// `no_screenshot` is a GLOBAL, non-ref-counted singleton. If two guards are
  /// mounted at once, a naive `screenshotOn()` in one's `dispose` would re-enable
  /// capture while the other's secret is still visible. Ref-count so capture is
  /// blocked while ANY guard is mounted and only re-enabled when the LAST one
  /// unmounts.
  static int _mounted = 0;

  @override
  void initState() {
    super.initState();
    if (_mounted++ == 0) _set(enabled: true);
  }

  @override
  void dispose() {
    if (--_mounted == 0) _set(enabled: false);
    super.dispose();
  }

  void _set({required bool enabled}) {
    try {
      final ns = NoScreenshot.instance;
      enabled ? ns.screenshotOff() : ns.screenshotOn();
    } catch (_) {
      // Best-effort: platform channel may be absent (tests / unsupported OS).
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: widget.child);
}
