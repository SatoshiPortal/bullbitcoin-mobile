import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/widgets.dart';

/// Tells the user, wherever they are, that automatic Tor left a direct
/// connection for Snowflake, and why.
///
/// A fallback is an event, not state, so this subscribes to the stream rather
/// than rebuilding from it: each fallback is announced exactly once, however
/// often the tree above rebuilds.
///
/// The app mounts it in `MaterialApp.builder`, above the root navigator, so
/// its own context has no `Overlay`; like `SettingsFailureListener`, it shows
/// through the root navigator's overlay, which covers every screen, and
/// translates through that overlay's context.
class TorFallbackListener extends StatefulWidget {
  final Stream<TorTransportFallback> fallbacks;
  final Widget child;
  final OverlayState? Function()? resolveOverlay;
  final void Function(OverlayState overlay, String message)? show;

  const TorFallbackListener({
    super.key,
    required this.fallbacks,
    required this.child,
    this.resolveOverlay,
    this.show,
  });

  @override
  State<TorFallbackListener> createState() => _TorFallbackListenerState();
}

class _TorFallbackListenerState extends State<TorFallbackListener> {
  StreamSubscription<TorTransportFallback>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.fallbacks.listen(_announce);
  }

  @override
  void didUpdateWidget(TorFallbackListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fallbacks == widget.fallbacks) return;
    unawaited(_subscription?.cancel());
    _subscription = widget.fallbacks.listen(_announce);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _announce(TorTransportFallback fallback) {
    final overlay =
        (widget.resolveOverlay ??
        () => AppRouter.rootNavigatorKey.currentState?.overlay)();
    // Nothing mounted yet: the fallback is already under way and the status
    // card still explains the transport, so dropping the notice is harmless.
    if (overlay == null) return;

    final loc = overlay.context.loc;
    final message = switch (fallback.reason) {
      TorFallbackReason.censorship => loc.torFallbackCensorship,
      TorFallbackReason.stalled ||
      TorFallbackReason.timeout => loc.torFallbackSlow,
    };
    (widget.show ?? SnackBarUtils.showSnackBarIn)(overlay, message);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
