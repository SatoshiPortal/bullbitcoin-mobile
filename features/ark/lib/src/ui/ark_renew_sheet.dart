import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_pricer/bull_pricer.dart' show BitcoinPrice;
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';

import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_cubit.dart';
import 'ark_amount.dart';
import 'ark_summary_box.dart';

/// How a renew sheet closed. A dismissed sheet returns null.
enum ArkRenewOutcome { started, uncertain }

/// Renew review as a bottom sheet over the VTXO details: the quoted amount,
/// the renew fee and what stays in Ark, then Cancel or Renew.
class ArkRenewSheet extends StatefulWidget {
  final ArkOperationCubit cubit;
  final BitcoinPrice? price;

  const ArkRenewSheet({super.key, required this.cubit, this.price});

  /// Shows the sheet for [cubit], which must already be loading a renewal
  /// quote. The caller owns [cubit] and closes it after the sheet.
  static Future<ArkRenewOutcome?> show(
    BuildContext context, {
    required ArkOperationCubit cubit,
    BitcoinPrice? price,
  }) => BullBottomSheet.show<ArkRenewOutcome>(
    context: context,
    child: ArkRenewSheet(cubit: cubit, price: price),
  );

  @override
  State<ArkRenewSheet> createState() => _ArkRenewSheetState();
}

class _ArkRenewSheetState extends State<ArkRenewSheet> {
  late StreamSubscription<ArkOperationState> _subscription;

  /// Set by any pop of this sheet: Cancel, the scrim, a drag or an outcome.
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen(
      _changed,
      // The owner closed the cubit (account replaced or page retired): a
      // sheet without a live quote has nothing left to confirm.
      onDone: () => _close(null),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  void _changed(ArkOperationState state) {
    if (!mounted) return;
    switch (state) {
      case ArkOperationSubmitted():
        _close(ArkRenewOutcome.started);
      case ArkOperationUncertain():
        _close(ArkRenewOutcome.uncertain);
      default:
        setState(() {});
    }
  }

  /// Pops this sheet only while it is still the top route. Once it has been
  /// dismissed it keeps rendering through its exit animation, and a second
  /// pop would close the page underneath.
  void _close(ArkRenewOutcome? outcome) {
    if (!mounted || _dismissed) return;
    _dismissed = true;
    Navigator.pop(context, outcome);
  }

  /// Only a renewal quote for exactly the requested VTXOs, on this account,
  /// can be confirmed from this sheet.
  bool _matches(ArkQuote quote) {
    final request = widget.cubit.request;
    return request is ArkRenewalQuoteRequest &&
        quote.account == widget.cubit.account &&
        quote.kind == ArkOperationKind.renewal &&
        quote.selectedIds.toSet().containsAll(request.ids) &&
        request.ids.toSet().containsAll(quote.selectedIds);
  }

  /// The quote kept on screen while it is priced again before confirming.
  ArkQuote? _repricing;

  /// A quote is bound to the block it was priced at, and confirming refuses
  /// an older one. The sheet may have been open for blocks: price the same
  /// VTXOs again now and confirm that fresh quote at once, unless its fee is
  /// higher than the one reviewed; then the new fee is shown to confirm.
  Future<void> _renew(ArkOperationReview rendered) async {
    final cubit = widget.cubit;
    if (!mounted ||
        cubit.isClosed ||
        !identical(cubit.state, rendered) ||
        !_matches(rendered.quote)) {
      return;
    }
    final reviewed = rendered.quote;
    setState(() => _repricing = reviewed);
    await cubit.load();
    if (!mounted) return;
    setState(() => _repricing = null);
    final fresh = cubit.state;
    if (cubit.isClosed ||
        fresh is! ArkOperationReview ||
        !_matches(fresh.quote) ||
        fresh.quote.fee.value > reviewed.fee.value) {
      return; // A refusal or a higher fee is shown; nothing was confirmed.
    }
    unawaited(cubit.confirm());
  }

  void _retry(ArkOperationFailed rendered) {
    if (mounted &&
        !widget.cubit.isClosed &&
        identical(widget.cubit.state, rendered)) {
      unawaited(widget.cubit.load());
    }
  }

  String _withFiat(BuildContext context, Sats amount) {
    final sats = formatArkSats(context, amount);
    final fiat = arkFiatText(context, amount, widget.price);
    return fiat == null ? sats : '$sats ($fiat)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final state = widget.cubit.state;
    final quote = switch (state) {
      ArkOperationReview(:final quote) when _matches(quote) => quote,
      _ => _repricing,
    };
    final busy =
        _repricing != null ||
        state is ArkOperationLoading ||
        state is ArkOperationSubmitting;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _dismissed = true;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BullSpacing.md,
          BullSpacing.sm,
          BullSpacing.md,
          BullSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.bull.border,
                  borderRadius: BorderRadius.circular(context.bullShapes.dot),
                ),
              ),
            ),
            const Gap(BullSpacing.md),
            Semantics(
              header: true,
              child: BullText(
                l10n.renewSheetTitle,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(BullSpacing.xs),
            BullText(
              l10n.renewSheetDescription,
              role: BullTextRole.body,
              color: context.bull.textMuted,
            ),
            const Gap(BullSpacing.md),
            BullFadingLinearProgress(
              height: 3,
              trigger: busy,
              backgroundColor: context.bull.background,
            ),
            const Gap(BullSpacing.md),
            if (state case final ArkOperationFailed failed) ...[
              // Refused: why, in red, as the app shows it.
              BullText(
                failed.failure.toTranslated(context),
                role: BullTextRole.body,
                fontWeight: FontWeight.w500,
                color: context.bull.error,
                textAlign: TextAlign.center,
                maxLines: 5,
              ),
              const Gap(BullSpacing.md),
            ],
            if (state case ArkOperationReview(:final quote)
                when !_matches(quote)) ...[
              BullText(
                l10n.unavailable,
                role: BullTextRole.body,
                fontWeight: FontWeight.w500,
                color: context.bull.error,
                textAlign: TextAlign.center,
                maxLines: 5,
              ),
              const Gap(BullSpacing.md),
            ],
            if (quote != null) ...[
              _Box(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BullText(
                      l10n.renewAmountSelected,
                      role: BullTextRole.label,
                      color: context.bull.textMuted,
                    ),
                    const Gap(BullSpacing.xxs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: BullSpacing.xs,
                      children: [
                        BullText(
                          formatArkSats(context, quote.amount),
                          role: BullTextRole.title,
                          fontWeight: FontWeight.w700,
                        ),
                        if (arkFiatText(context, quote.amount, widget.price)
                            case final fiat?)
                          BullText(
                            '($fiat)',
                            role: BullTextRole.title,
                            color: context.bull.textMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(BullSpacing.sm),
              ArkSummaryBox(
                rows: [
                  (
                    label: l10n.renewVtxosSelected,
                    value: quote.selectedIds.length.toString(),
                  ),
                  (label: l10n.renewFee, value: _withFiat(context, quote.fee)),
                  (
                    label: l10n.renewAmountAfterFee,
                    value: _withFiat(context, quote.net),
                  ),
                ],
              ),
              const Gap(BullSpacing.md),
            ],
            Row(
              children: [
                Expanded(
                  child: BullButton.secondary(
                    label: l10n.cancel,
                    onPressed: () => _close(null),
                  ),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: switch (state) {
                    final ArkOperationFailed failed => BullButton.primary(
                      label: l10n.retry,
                      onPressed: () => _retry(failed),
                    ),
                    final ArkOperationReview reviewed => BullButton.primary(
                      label: l10n.vtxosRenew,
                      onPressed: quote == null
                          ? null
                          : () => unawaited(_renew(reviewed)),
                    ),
                    _ => BullButton.primary(
                      label: l10n.vtxosRenew,
                      onPressed: null,
                    ),
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final Widget child;

  const _Box({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BullSpacing.md),
    decoration: BoxDecoration(
      color: context.bull.surface,
      border: Border.all(color: context.bull.border),
      borderRadius: BorderRadius.circular(context.bullShapes.card),
    ),
    child: child,
  );
}
