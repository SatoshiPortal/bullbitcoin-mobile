import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_display_data_port.dart';
import '../domain/ark_failure.dart';
import '../domain/ark_board_minimum.dart';
import '../presentation/ark_failure_l10n.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';

/// Input handoff only; no source wallet, fee estimate or funding authority.
class ArkBoardAmountScreen extends StatefulWidget {
  final ArkAccountConfig config;
  final void Function(ArkAccountConfig config, Sats amount)? onReviewRequest;
  final ArkDisplayData? displayData;
  final ArkFailure? failure;
  final ArkBoardMinimum? minimum;
  final bool Function()? sourceReady;
  final VoidCallback? onRefreshSource;
  const ArkBoardAmountScreen({
    super.key,
    this.displayData,
    this.failure,
    this.minimum,
    this.sourceReady,
    this.onRefreshSource,
    required this.config,
    this.onReviewRequest,
  });
  @override
  State<ArkBoardAmountScreen> createState() => _ArkBoardAmountScreenState();
}

class _ArkBoardAmountScreenState extends State<ArkBoardAmountScreen> {
  String _amount = '';
  int _epoch = 0;
  Object? _inputToken;
  bool _consumed = false;
  ArkBoardMinimum? _refusedMinimum;
  Timer? _minimumExpiry;
  DateTime? _scheduledMinimumExpiry;
  DateTime? _retiredMinimumThrough;

  @override
  void initState() {
    super.initState();
    _rememberRefusal();
    _scheduleMinimumExpiry();
  }

  void _rememberRefusal() {
    _refusedMinimum = switch (widget.failure) {
      ArkBoardBelowMinimumFailure(:final minimum) => ArkBoardMinimum(
        config: widget.config,
        minimum: minimum,
        observedAt: DateTime.now().toUtc(),
      ),
      _ => null,
    };
  }

  Sats? get _minimum {
    final cached = widget.minimum;
    final refused = _refusedMinimum;
    final cachedValue = _minimumValue(cached);
    final refusedValue = _minimumValue(refused);
    if (refused != null &&
        refusedValue != null &&
        (cached == null ||
            cachedValue == null ||
            refused.observedAt.isAfter(cached.observedAt))) {
      return refusedValue;
    }
    return cachedValue;
  }

  Sats? _minimumValue(ArkBoardMinimum? observation) {
    if (observation == null) return null;
    final retired = _retiredMinimumThrough;
    if (retired != null && !observation.expiresAt.isAfter(retired)) return null;
    return observation.forConfig(widget.config);
  }

  void _scheduleMinimumExpiry() {
    DateTime? next;
    for (final observation in [widget.minimum, _refusedMinimum]) {
      if (observation == null || _minimumValue(observation) == null) continue;
      if (next == null || observation.expiresAt.isBefore(next)) {
        next = observation.expiresAt;
      }
    }
    if (next == _scheduledMinimumExpiry) return;
    _minimumExpiry?.cancel();
    _minimumExpiry = null;
    _scheduledMinimumExpiry = next;
    if (next == null) return;
    final deadline = next;
    _minimumExpiry = Timer(deadline.difference(DateTime.now()), () {
      if (!mounted) return;
      _minimumExpiry = null;
      _scheduledMinimumExpiry = null;
      // Once elapsed locally, a wall-clock rollback cannot revive this cache.
      final retired = _retiredMinimumThrough;
      if (retired == null || deadline.isAfter(retired)) {
        _retiredMinimumThrough = deadline;
      }
      setState(() {
        ++_epoch;
        _inputToken = null;
      });
      _scheduleMinimumExpiry();
    });
  }

  Object _binding(ArkAccountConfig c) => (
    c.id,
    c.arkUrl,
    c.primaryEsploraUrl,
    c.fallbackEsploraUrl,
    c.renewalThresholdBlocks,
  );
  bool _current(ArkBoardAmountScreen rendered, int epoch) =>
      mounted &&
      !_consumed &&
      epoch == _epoch &&
      _binding(rendered.config) == _binding(widget.config) &&
      identical(rendered.onReviewRequest, widget.onReviewRequest);

  Sats? _parse(String raw) {
    if (raw.isEmpty || raw.codeUnits.any((unit) => unit < 48 || unit > 57)) {
      return null;
    }
    final value = BigInt.tryParse(raw);
    if (value == null ||
        value <= BigInt.zero ||
        value > BigInt.from(2100000000000000)) {
      return null;
    }
    return Sats(value);
  }

  @override
  void didUpdateWidget(ArkBoardAmountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedConfig = _binding(oldWidget.config) != _binding(widget.config);
    if (changedConfig) {
      _refusedMinimum = null;
      _retiredMinimumThrough = null;
    }
    if (!identical(oldWidget.failure, widget.failure)) _rememberRefusal();
    if (changedConfig ||
        !identical(oldWidget.onReviewRequest, widget.onReviewRequest)) {
      ++_epoch;
      _inputToken = null;
      if (changedConfig) _amount = '';
      // Never clear consumption: replacement is not evidence of no effect.
    }
    _scheduleMinimumExpiry();
  }

  @override
  void dispose() {
    _minimumExpiry?.cancel();
    _inputToken = null;
    super.dispose();
  }

  void _edit(ArkBoardAmountScreen rendered, Object token, String value) {
    if (!identical(token, _inputToken) || !_current(rendered, _epoch)) return;
    setState(() {
      ++_epoch;
      _amount = value;
    });
  }

  void _review(ArkBoardAmountScreen rendered, int epoch, String raw) {
    if (!_current(rendered, epoch) ||
        _amount != raw ||
        !(widget.sourceReady?.call() ?? true)) {
      return;
    }
    final delegate = rendered.onReviewRequest;
    final amount = _parse(raw);
    if (delegate == null || amount == null) return;
    final display = widget.displayData;
    final available = display?.account == widget.config.id
        ? display?.available
        : null;
    if (available != null && amount.value > available.value) return;
    final minimum = _minimum;
    if (minimum != null && amount.value < minimum.value) return;
    setState(() => _consumed = true);
    _inputToken = null;
    delegate(rendered.config, amount); // A throw is not permission to retry.
  }

  @override
  Widget build(BuildContext context) {
    final token = Object();
    _inputToken = token;
    final rendered = widget;
    final epoch = _epoch;
    final raw = _amount;
    final l10n = context.loc;
    final id = rendered.config.id;
    final display = rendered.displayData;
    final source = display?.account == id ? display : null;
    final available = source?.available;
    final amount = _parse(raw);
    final minimum = _minimum;
    final belowMinimum =
        amount != null && minimum != null && amount.value < minimum.value;
    final insufficient =
        amount != null && available != null && amount.value > available.value;
    return BullScaffold(
      backgroundColor: context.bull.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.lg,
            BullSpacing.sm,
            BullSpacing.lg,
            BullSpacing.lg,
          ),
          child: BullButton.big(
            label: l10n.boardAction,
            height: 56,
            disabled:
                _consumed ||
                !(rendered.sourceReady?.call() ?? true) ||
                rendered.onReviewRequest == null ||
                amount == null ||
                insufficient ||
                belowMinimum,
            onPressed: () => _review(rendered, epoch, raw),
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.sm,
              ),
              child: BullTopBar(
                title: l10n.boardToArk,
                titleWidget: BullText(
                  l10n.boardToArk,
                  role: BullTextRole.subtitle,
                ),
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  BullSpacing.md,
                  BullSpacing.xxs,
                  BullSpacing.md,
                  BullSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BullText(
                      l10n.boardIntro,
                      role: BullTextRole.body,
                      color: context.bull.textMuted,
                    ),
                    const Gap(BullSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BullSpacing.md,
                        vertical: BullSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: context.bull.surface,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.card,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: BullText(
                              l10n.availableOnchain,
                              role: BullTextRole.label,
                              color: context.bull.textMuted,
                            ),
                          ),
                          const Gap(BullSpacing.sm),
                          BullText(
                            formatArkObservedSats(context, available),
                            role: BullTextRole.subtitle,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                    if (rendered.onRefreshSource case final refresh?)
                      BullButton.small(
                        label: l10n.refresh,
                        onPressed: refresh,
                        bgColor: context.bull.secondary,
                        textColor: context.bull.onSecondary,
                      ),
                    const Gap(BullSpacing.md),
                    BullText(
                      l10n.amountToMove,
                      role: BullTextRole.label,
                      fontWeight: FontWeight.w700,
                    ),
                    const Gap(BullSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: context.bull.surface,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.input,
                        ),
                        border: Border.all(
                          color: belowMinimum || insufficient
                              ? context.bull.primary
                              : context.bull.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: l10n.amountToMove,
                              textField: true,
                              enabled: !_consumed,
                              child: BullInputText(
                                hideBorder: true,
                                value: raw,
                                hint: Sats.zero.value.toString(),
                                style: context.bullType.headline,
                                digitsOnly: true,
                                onlyNumbers: true,
                                disabled: _consumed,
                                onChanged: (value) =>
                                    _edit(rendered, token, value),
                              ),
                            ),
                          ),
                          BullText(l10n.satsUnit, role: BullTextRole.body),
                          Padding(
                            padding: const EdgeInsets.all(BullSpacing.xxs),
                            child: BullButton.small(
                              label: l10n.maxAmount,
                              compact: true,
                              height: 48,
                              width: 64,
                              disabled: true,
                              onPressed: () {},
                              bgColor: context.bull.secondary,
                              textColor: context.bull.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                    if (raw.isNotEmpty && amount == null)
                      BullInfoBar(message: l10n.boardAmountInvalid),
                    BullText(
                      belowMinimum
                          ? l10n.boardAmountBelowMinimum(
                              formatArkSats(context, minimum),
                            )
                          : minimum == null
                          ? l10n.boardMinimumUnavailable
                          : l10n.boardMinimumWithNetworkFees(
                              formatArkSats(context, minimum),
                            ),
                      role: BullTextRole.caption,
                      color: belowMinimum
                          ? context.bull.primary
                          : context.bull.textMuted,
                    ),
                    if (insufficient)
                      BullInfoBar(
                        message: l10n.insufficient,
                        tone: BullInfoTone.warning,
                      ),
                    if (rendered.failure case final failure?)
                      BullInfoBar(
                        message: failure.toTranslated(context),
                        tone: BullInfoTone.warning,
                      ),
                    if (amount != null)
                      ArkFiatAmount(amount: amount, price: source?.price),
                    BullText(
                      l10n.maxUnavailable,
                      role: BullTextRole.caption,
                      color: context.bull.textMuted,
                    ),
                    const Gap(BullSpacing.md),
                    BullText(l10n.boardFeeEstimate, role: BullTextRole.label),
                    const Gap(BullSpacing.xs),
                    BullText(
                      l10n.boardEstimateUnavailable,
                      role: BullTextRole.caption,
                      color: context.bull.textMuted,
                    ),
                    if (rendered.onReviewRequest == null)
                      BullInfoBar(message: l10n.nativeUnavailable),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
