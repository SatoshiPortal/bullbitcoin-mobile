import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart' show Icon, Icons, WidgetBuilder;
import 'package:bull_logger/bull_logger.dart';

/// The localized texts of the warning a [ScreenPrivacyGate] shows; the package
/// has no localizations of its own, so the screen passes `context.loc` values.
class ScreenPrivacyGateLabels {
  final String message;
  final String retry;
  final String continueAnyway;

  const ScreenPrivacyGateLabels({
    required this.message,
    required this.retry,
    required this.continueAnyway,
  });
}

/// Draws a secret only once capture blocking is confirmed, without ever
/// blocking the user.
///
/// [protect] is the screen's `enableScreenPrivacy`. A refusal is retried after
/// each of [retryDelays]; if blocking is still refused, a warning replaces the
/// secret and offers to retry or to continue anyway, which shows the secret
/// unprotected on the user's explicit consent.
///
/// Requires a [BullTheme] in the widget tree to render the warning.
class ScreenPrivacyGate extends StatefulWidget {
  final Future<bool> Function() protect;
  final ScreenPrivacyGateLabels labels;
  final WidgetBuilder builder;
  final List<Duration> retryDelays;

  const ScreenPrivacyGate({
    super.key,
    required this.protect,
    required this.labels,
    required this.builder,
    this.retryDelays = const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 750),
    ],
  });

  @override
  State<ScreenPrivacyGate> createState() => _ScreenPrivacyGateState();
}

enum _GateStatus { pending, shown, refused }

class _ScreenPrivacyGateState extends State<ScreenPrivacyGate> {
  _GateStatus _status = _GateStatus.pending;

  /// Identifies the latest attempt, so a slower earlier one cannot overwrite
  /// its verdict.
  int _attempt = 0;
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    unawaited(_protect());
  }

  Future<void> _protect() async {
    final attempt = ++_attempt;
    var calls = 1;
    var protected = await widget.protect();
    for (final delay in widget.retryDelays) {
      if (protected || !mounted || attempt != _attempt) break;
      await Future<void>.delayed(delay);
      if (!mounted || attempt != _attempt) return;
      calls++;
      protected = await widget.protect();
    }
    if (!mounted || attempt != _attempt) return;
    if (protected) {
      log.fine(
        'Privacy gate ready outcome=allowed attempts=$calls recovered=${_refused || calls > 1}',
      );
    } else if (!_refused) {
      log.warning('Privacy gate refused reason=platform attempts=$calls');
    }
    _refused = !protected;
    setState(() {
      _status = protected ? _GateStatus.shown : _GateStatus.refused;
    });
  }

  void _retry() {
    setState(() => _status = _GateStatus.pending);
    unawaited(_protect());
  }

  void _continueAnyway() {
    log.warning('Privacy gate bypass consent=true');
    setState(() => _status = _GateStatus.shown);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _GateStatus.pending => const SizedBox.shrink(),
      _GateStatus.shown => widget.builder(context),
      _GateStatus.refused => _RefusedWarning(
        labels: widget.labels,
        onRetry: _retry,
        onContinueAnyway: _continueAnyway,
      ),
    };
  }
}

class _RefusedWarning extends StatelessWidget {
  final ScreenPrivacyGateLabels labels;
  final VoidCallback onRetry;
  final VoidCallback onContinueAnyway;

  const _RefusedWarning({
    required this.labels,
    required this.onRetry,
    required this.onContinueAnyway,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: .min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: colors.warning,
              ),
              const Gap(16),
              BullText(
                labels.message,
                style: context.bullText.bodyLarge,
                color: colors.text,
                textAlign: .center,
              ),
              const Gap(24),
              BullButton.big(
                label: labels.retry,
                onPressed: onRetry,
                bgColor: colors.secondary,
                textColor: colors.onSecondary,
              ),
              const Gap(12),
              BullButton.big(
                label: labels.continueAnyway,
                onPressed: onContinueAnyway,
                bgColor: colors.transparent,
                textColor: colors.secondary,
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
