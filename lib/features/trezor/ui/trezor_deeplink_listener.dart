import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/trezor/domain/repositories/trezor_callback_dispatcher.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

/// Wraps `MaterialApp.router` and intercepts Trezor Connect callback URIs
/// before they reach GoRouter.
///
/// **Must** stay above any auth gating widget.
class TrezorDeeplinkListener extends StatefulWidget {
  final Widget child;
  const TrezorDeeplinkListener({super.key, required this.child});

  @override
  State<TrezorDeeplinkListener> createState() => _TrezorDeeplinkListenerState();
}

class _TrezorDeeplinkListenerState extends State<TrezorDeeplinkListener> {
  static const _trezorScheme = 'bullbitcoin';
  static const _trezorHost = 'trezor-callback';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) {
        log.warning('Trezor deeplink stream error', error: e);
      },
    );
    _appLinks.getInitialLink().then(
      (uri) {
        if (uri != null) _handle(uri);
      },
      onError: (Object e) {
        log.warning('Trezor deeplink getInitialLink error', error: e);
      },
    );
  }

  void _handle(Uri uri) {
    if (uri.scheme != _trezorScheme || uri.host != _trezorHost) {
      // Non-Trezor URIs fall through; future deeplink consumers can
      // subscribe separately or extend this dispatcher.
      return;
    }
    try {
      locator<TrezorCallbackDispatcher>().handleCallback(uri);
    } catch (e, t) {
      log.severe(message: 'Trezor handleCallback failed', error: e, trace: t);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
