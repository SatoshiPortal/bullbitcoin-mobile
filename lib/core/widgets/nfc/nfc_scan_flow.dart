import 'dart:async';

import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:bb_mobile/core/nfc/presentation/nfc_failure_l10n.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/nfc/nfc_scan_view.dart';
import 'package:flutter/widgets.dart';

class NfcScanFlow extends StatefulWidget {
  const NfcScanFlow({
    super.key,
    required this.session,
    required this.run,
    required this.onPayload,
    this.onCancelled,
  });

  final NfcSession session;
  final Future<Result<String, NfcFailure>> Function(NfcSession session) run;
  final void Function(String payload) onPayload;
  final VoidCallback? onCancelled;

  @override
  State<NfcScanFlow> createState() => _NfcScanFlowState();
}

class _NfcScanFlowState extends State<NfcScanFlow> {
  late final AppLifecycleListener _lifecycleListener;
  bool _isScanning = false;
  NfcFailure? _failure;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );
    unawaited(_scan());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    unawaited(widget.session.cancel());
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _failure = null;
    });

    final result = await widget.run(widget.session);
    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        setState(() => _isScanning = false);
        widget.onPayload(value);
      case Err(:final failure):
        setState(() {
          _isScanning = false;
          _failure = failure;
        });
        if (failure is NfcCancelledFailure) widget.onCancelled?.call();
    }
  }

  void _onLifecycleChange(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || !_isScanning) return;
    unawaited(widget.session.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;

    return NfcScanView(
      isScanning: _isScanning,
      errorMessage: failure?.toTranslated(context),
      onRetry: _isScanning ? null : _scan,
    );
  }
}
