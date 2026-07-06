import 'package:flutter/foundation.dart';
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
/// FIRST-FRAME GAP CLOSED: `screenshotOff()` is ASYNC (no synchronous
/// capture-block API exists), so the opening frames could once render the
/// secret before the platform block landed. The child is now painted UNDER the
/// SAME opaque cover until capture-blocking is confirmed active — so a capture
/// already in progress catches only the cover, never the secret, even on frame
/// one. The child stays in the tree throughout (state/identity preserved); only
/// its pixels are hidden until the block is confirmed.
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
  /// Honored ONLY in debug builds (`kDebugMode`) so it is release-inert — a
  /// release binary can never route capture-blocking through an injected spy.
  @visibleForTesting
  static void Function({required bool enabled})? debugSetCapture;

  /// Key of the opaque cover painted over the child while backgrounded.
  @visibleForTesting
  static const coverKey = Key('privacy_guard_cover');

  /// Resets the process-global capture state ([_PrivacyGuardState._mounted],
  /// generation, and the confirmation notifier) between tests — the statics
  /// otherwise leak across test cases and, e.g., a prior test leaving the block
  /// confirmed would hide a later test's first-frame cover. No-op in production.
  @visibleForTesting
  static void debugReset() => _PrivacyGuardState._debugReset();

  /// Observe the process-global capture-confirmation state (see M1/M2). Test-only.
  @visibleForTesting
  static bool get debugCaptureConfirmed =>
      _PrivacyGuardState._captureConfirmed.value;

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

  /// Monotonic generation stamped on every `_set` call. The async enable
  /// completion only writes [_captureConfirmed] if its generation is still the
  /// latest — so a disable (or a later enable) that ran while an enable was in
  /// flight can't be clobbered by the stale completion resurrecting a `true`
  /// (the M2 window: a stale `true` would let the NEXT guard skip its
  /// first-frame cover while capture is actually allowed).
  static int _generation = 0;

  /// OBSERVABLE process-global: true once the platform capture-block is
  /// CONFIRMED active. Every mounted guard listens, so a guard mounted in the
  /// SAME frame as the one that armed the block still reveals its child when the
  /// async `screenshotOff()` lands — previously only the guard that called
  /// `_set(enabled: true)` learned of the confirmation, leaving any sibling
  /// mounted that frame covered forever (the M1 defect). Until it is true, every
  /// guard's `build` paints the opaque cover so pre-confirmation frames leak
  /// nothing to a capture already running.
  static final ValueNotifier<bool> _captureConfirmed = ValueNotifier(false);

  static void _debugReset() {
    _mounted = 0;
    _generation = 0;
    _captureConfirmed.value = false;
  }

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
    // Rebuild this guard whenever the shared confirmation flips (see M1) — a
    // guard mounted before the block is confirmed must uncover once it lands,
    // even if a DIFFERENT guard is the one that armed it. Added AFTER `_set` so
    // the synchronous test-seam path (which flips the notifier inside `_set`)
    // can't re-enter setState during this initState — the first `build` reads
    // the fresh value directly.
    _captureConfirmed.addListener(_onConfirmedChanged);
    // If capture is already confirmed active (an earlier guard turned it on, or
    // this guard enabled it synchronously via the test seam) the child is safe
    // to render from frame one; otherwise `build` covers it until the async
    // `screenshotOff()` lands and flips the shared notifier (see `_set`).
  }

  @override
  void dispose() {
    _captureConfirmed.removeListener(_onConfirmedChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (--_mounted == 0) _set(enabled: false);
    super.dispose();
  }

  void _onConfirmedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscure = state != AppLifecycleState.resumed;
    if (obscure != _obscured) setState(() => _obscured = obscure);
    // Defense-in-depth: on RESUME, re-assert capture-blocking. A legacy
    // PrivacyScreen mixin writes the SAME process-global NoScreenshot without
    // this guard's ref-count, so it can clear FLAG_SECURE (e.g. popping a
    // legacy screen) while a guarded secret is still on screen; the ref-count
    // won't re-trigger _set. Re-applying on resume closes the window whenever a
    // lifecycle transition follows. (The full fix — making the mixin
    // ref-count-aware / per-flow-atomic migration — is an app-side Phase-6
    // task; see ADOPTION.md.)
    if (state == AppLifecycleState.resumed) _set(enabled: true);
  }

  void _set({required bool enabled}) {
    // Every call takes the next generation; only the latest may write the
    // confirmed state on completion (see [_generation]).
    final gen = ++_generation;
    // The test seam is honored ONLY in debug (kDebugMode) so it is release-inert
    // — a release build can never route through an injected spy.
    final override = kDebugMode ? PrivacyGuard.debugSetCapture : null;
    if (override != null) {
      override(enabled: enabled);
      // Synchronous seam → the block's state is known immediately.
      _captureConfirmed.value = enabled;
      return;
    }
    // Decided to turn capture OFF → new guards must cover until it is re-armed.
    // Set eagerly (and synchronously) so a guard mounting in this same frame
    // sees the un-confirmed state and covers.
    if (!enabled) _captureConfirmed.value = false;
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
    final f = apply();
    if (enabled) {
      // Reveal the child only once the platform capture-block is CONFIRMED
      // (success or a swallowed platform error — either way the async gap has
      // closed and we should not keep the secret hidden forever). Skip if a
      // newer `_set` has since run (gen != _generation) — e.g. a disable landed
      // while this enable was in flight; resurrecting `true` here would reopen
      // the M2 window.
      f.whenComplete(() {
        if (gen == _generation) _captureConfirmed.value = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        // Passthrough so the child lays out exactly as it would unwrapped; the
        // opaque cover is painted over it only while backgrounded.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            // Cover while backgrounded (app-switcher snapshot) OR until the
            // async capture-block is confirmed (first-frame gap). The child
            // stays mounted underneath either way. `IgnorePointer` keeps the
            // cover VISUAL-only: it hides the secret's pixels from a
            // screenshot/recording without stealing taps from the child beneath
            // (the interactive VerifyBackupView must stay usable the instant its
            // words paint, and a capture cover must never intercept input).
            if (_obscured || !_captureConfirmed.value)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      key: PrivacyGuard.coverKey, color: Color(0xFF000000)),
                ),
              ),
          ],
        ),
      );
}
