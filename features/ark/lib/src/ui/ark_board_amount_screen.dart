import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_display_data_port.dart';
import '../domain/ark_failure.dart';
import '../presentation/ark_failure_l10n.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';

/// Input handoff only; no source wallet, fee estimate or funding authority.
class ArkBoardAmountScreen extends StatefulWidget {
  final ArkAccountConfig config;
  final void Function(ArkAccountConfig config, Sats amount)? onReviewRequest;
  final ArkDisplayData? displayData;
  final ArkFailure? failure;

  /// The server's minimum Board amount, when an observation provides it.
  final Sats? minimumBoard;

  /// The review is being prepared: the amount stays, nothing is editable.
  final bool busy;
  const ArkBoardAmountScreen({
    super.key,
    this.displayData,
    this.failure,
    this.minimumBoard,
    this.busy = false,
    required this.config,
    this.onReviewRequest,
  });
  @override
  State<ArkBoardAmountScreen> createState() => _ArkBoardAmountScreenState();
}

class _ArkBoardAmountScreenState extends State<ArkBoardAmountScreen> {
  /// The balance last shown for this account. Preparing a board reserves its
  /// coin, which makes the live balance unknown; until the review opens the
  /// screen keeps what the user saw when they pressed Continue.
  Sats? _shownAvailable;

  String _amount = '';
  int _epoch = 0;
  Object? _inputToken;
  bool _consumed = false;

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
    if (changedConfig ||
        !identical(oldWidget.onReviewRequest, widget.onReviewRequest)) {
      ++_epoch;
      _inputToken = null;
      if (changedConfig) _amount = '';
      // Never clear consumption: replacement is not evidence of no effect.
    }
  }

  @override
  void dispose() {
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
    if (!_current(rendered, epoch) || _amount != raw) return;
    final delegate = rendered.onReviewRequest;
    final amount = _parse(raw);
    if (delegate == null || amount == null) return;
    final display = widget.displayData;
    final available = display?.account == widget.config.id
        ? display?.available
        : null;
    if (available != null && amount.value > available.value) return;
    final minimum = rendered.minimumBoard;
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
    final live = source?.available;
    // While the Board is prepared its coins get reserved, and the live
    // amount drops: keep showing what was available when Continue was
    // pressed, until the Board is ready or refused.
    final available = rendered.busy ? (_shownAvailable ?? live) : live;
    if (!rendered.busy) _shownAvailable = live;
    final amount = _parse(raw);
    final insufficient =
        amount != null && available != null && amount.value > available.value;
    final failure = rendered.failure;
    // Amount refusals read as field help; anything else stays a warning bar.
    final amountFailure = switch (failure) {
      ArkBoardBelowMinimumFailure() ||
      ArkPaymentInsufficientFundsFailure() ||
      ArkInvalidRequestFailure() => failure,
      _ => null,
    };
    final otherFailure = amountFailure == null ? failure : null;
    final minimum = rendered.minimumBoard;
    // Checked while typing; the server re-checks its current minimum anyway.
    final belowMinimum =
        amount != null && minimum != null && amount.value < minimum.value;
    final refusedBelowMinimum = failure is ArkBoardBelowMinimumFailure;
    final String? amountError = raw.isNotEmpty && amount == null
        ? l10n.boardAmountInvalid
        : insufficient
        ? l10n.insufficient
        : belowMinimum || refusedBelowMinimum
        ? null // The minimum line below turns red instead.
        : amountFailure?.toTranslated(context);
    final minimumText = switch ((minimum, failure)) {
      (final minimum?, _) => l10n.boardMinimum(minimum.value.toInt()),
      (null, ArkBoardBelowMinimumFailure(:final minimum)) => l10n.boardMinimum(
        minimum.value.toInt(),
      ),
      _ => null,
    };
    final minimumMissed =
        belowMinimum || (refusedBelowMinimum && amount == null);
    final enabled =
        !rendered.busy &&
        !_consumed &&
        rendered.onReviewRequest != null &&
        amount != null &&
        !insufficient &&
        !belowMinimum;
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
          child: BullButton.primary(
            label: l10n.continueAction,
            height: 56,
            onPressed: enabled ? () => _review(rendered, epoch, raw) : null,
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
            BullFadingLinearProgress(
              height: 3,
              trigger: rendered.busy,
              backgroundColor: context.bull.background,
              foregroundColor: context.bull.primary,
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
                          ),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.md),
                    BullText(
                      l10n.amountToMove,
                      role: BullTextRole.label,
                      fontWeight: FontWeight.w700,
                    ),
                    const Gap(BullSpacing.xs),
                    BullInputText(
                      value: raw,
                      hint: Sats.zero.value.toString(),
                      suffixText: l10n.satsUnit,
                      style: context.bullType.headline,
                      digitsOnly: true,
                      onlyNumbers: true,
                      disabled: _consumed || rendered.busy,
                      rightIcon: Padding(
                        padding: const EdgeInsets.all(BullSpacing.xxs),
                        child: BullButton.small(
                          label: l10n.maxAmount,
                          compact: true,
                          height: 40,
                          width: 64,
                          disabled: true,
                          onPressed: () {},
                          bgColor: context.bull.surfaceContainerHighest,
                          textColor: context.bull.textMuted,
                        ),
                      ),
                      onChanged: (value) => _edit(rendered, token, value),
                    ),
                    const Gap(BullSpacing.xs),
                    if (amount != null)
                      ArkFiatAmount(amount: amount, price: source?.price),
                    for (final (text, isError) in [
                      if (amountError != null) (amountError, true),
                      if (minimumText != null) (minimumText, minimumMissed),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BullSpacing.xxs,
                        ),
                        child: Semantics(
                          liveRegion: isError,
                          child: BullText(
                            text,
                            role: BullTextRole.caption,
                            color: isError
                                ? context.bull.error
                                : context.bull.textMuted,
                          ),
                        ),
                      ),
                    // Like the app's forms: why it was refused, in red, no
                    // frame. The user may simply try again.
                    if (otherFailure != null) ...[
                      const Gap(BullSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: BullText(
                          otherFailure.toTranslated(context),
                          role: BullTextRole.body,
                          fontWeight: FontWeight.w500,
                          color: context.bull.error,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                        ),
                      ),
                    ],
                    if (rendered.onReviewRequest == null) ...[
                      const Gap(BullSpacing.md),
                      BullText(
                        l10n.nativeUnavailable,
                        role: BullTextRole.body,
                        fontWeight: FontWeight.w500,
                        color: context.bull.error,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
