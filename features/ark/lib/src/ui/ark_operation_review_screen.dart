import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../domain/ark_display_data_port.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_operation_cubit.dart';
import '../presentation/ark_operation_status_l10n.dart';
import 'ark_amount.dart';

/// The parent's explicit Review action starts load before mounting this page.
/// Replace the injected owner on every full configuration/request change.
class ArkOperationReviewScreen extends StatefulWidget {
  final ArkOperationCubit cubit;
  final VoidCallback onReconcile;
  final ArkDisplayData? displayData;
  const ArkOperationReviewScreen({
    super.key,
    required this.cubit,
    required this.onReconcile,
    this.displayData,
  });
  @override
  State<ArkOperationReviewScreen> createState() =>
      _ArkOperationReviewScreenState();
}

class _ArkOperationReviewScreenState extends State<ArkOperationReviewScreen> {
  late StreamSubscription<ArkOperationState> _subscription;
  bool _owns(ArkOperationCubit owner, ArkAccountId account) =>
      mounted &&
      !owner.isClosed &&
      identical(owner, widget.cubit) &&
      account == widget.cubit.account;
  bool _current(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationState rendered,
  ) => _owns(owner, account) && identical(rendered, widget.cubit.state);
  void _listen() {
    final owner = widget.cubit;
    final account = owner.account;
    // A new owner is a new operation: it may leave once of its own.
    _left = false;
    _subscription = owner.stream.listen((next) {
      if (_owns(owner, account)) {
        setState(() {});
        _leaveIfDone(next);
      }
    });
  }

  bool _left = false;

  /// Sent, or not knowable yet: no page of its own. A snackbar says so, Ark
  /// refreshes and checks it, and the screen closes, as the app's flows do.
  void _leaveIfDone(ArkOperationState state) {
    if (_left) return;
    final l10n = arkLocalizationsOf(context);
    final message = switch (state) {
      ArkOperationSubmitted(:final operation) => operation.status.toTranslated(
        context,
      ),
      ArkOperationUncertain() => l10n.uncertainChecking,
      _ => null,
    };
    if (message == null) return;
    _left = true;
    final owner = widget.cubit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only for the owner that left: never a replacement's handlers.
      if (!mounted || !identical(owner, widget.cubit)) return;
      BullSnackBar.show(context, message: message);
      widget.onReconcile();
      unawaited(Navigator.maybePop(context));
    });
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ArkOperationReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  bool _exitProgress(ArkOperationCubit owner, ArkQuote quote) =>
      owner.request is ArkExitProgressQuoteRequest ||
      quote.kind == ArkOperationKind.exitProgress;

  // A payment review reads like the Send flow's own confirmation step.
  bool _payment(ArkOperationCubit owner) =>
      owner.request is ArkPaymentQuoteRequest;

  bool _hasReviewFacts(ArkOperationCubit owner, ArkQuote quote) {
    if (owner.request case ArkEmergencyExitQuoteRequest request) {
      return quote.kind == ArkOperationKind.emergencyExit &&
          quote.destination == request.destination &&
          quote.feeRate == request.feeRate &&
          quote.maxClaimFee == request.maxClaimFee &&
          quote.confirmedReserveExposure != null &&
          quote.selectedIds.toSet().containsAll(request.ids) &&
          request.ids.toSet().containsAll(quote.selectedIds);
    }
    if (owner.request case ArkClaimQuoteRequest request) {
      return quote.kind == ArkOperationKind.claim &&
          quote.destination == request.destination &&
          quote.maxClaimFee == request.maxFee &&
          quote.selectedIds.toSet().containsAll(request.ids) &&
          request.ids.toSet().containsAll(quote.selectedIds);
    }
    return !_exitProgress(owner, quote) ||
        (owner.request is ArkExitProgressQuoteRequest &&
            quote.kind == ArkOperationKind.exitProgress &&
            quote.feeRate != null &&
            quote.confirmedReserveExposure != null);
  }

  void _confirm(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationReview rendered,
  ) {
    if (!_current(owner, account, rendered)) return;
    final current = widget.cubit.state;
    if (current is! ArkOperationReview ||
        !identical(current.quote, rendered.quote) ||
        current.quote.account != account ||
        !_hasReviewFacts(owner, current.quote)) {
      return;
    }
    unawaited(widget.cubit.confirm());
  }

  void _retry(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationFailed rendered,
  ) {
    if (_current(owner, account, rendered)) unawaited(widget.cubit.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    return BullScaffold(
      backgroundColor: context.bull.background,
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
                title: _payment(owner) ? l10n.send : l10n.review,
                titleWidget: BullText(
                  _payment(owner) ? l10n.send : l10n.review,
                  role: BullTextRole.subtitle,
                ),
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              // Loading or submitting: Bull's cubes in the middle.
              child:
                  state is ArkOperationLoading ||
                      state is ArkOperationSubmitting
                  ? const Center(child: BullLoader.large())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BullSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            _button(
                              context,
                              l10n.review,
                              () => _retry(owner, account, failed),
                            ),
                          ],
                          if (state case final ArkOperationReview reviewed) ...[
                            if (reviewed.quote.account != account)
                              BullText(
                                l10n.unavailable,
                                role: BullTextRole.body,
                                fontWeight: FontWeight.w500,
                                color: context.bull.error,
                                textAlign: TextAlign.center,
                              ),
                            if (reviewed.quote.account == account &&
                                _payment(owner) &&
                                reviewed.quote.kind == ArkOperationKind.payment)
                              ..._paymentReview(context, owner, reviewed.quote),
                            if (reviewed.quote.account == account &&
                                !(_payment(owner) &&
                                    reviewed.quote.kind ==
                                        ArkOperationKind.payment)) ...[
                              if (_hasReviewFacts(owner, reviewed.quote))
                                _quoteHero(context, owner, reviewed.quote),
                              BullDetailsTable(
                                items: [
                                  BullDetailsTableItem(
                                    label: l10n.amount,
                                    displayValue: reviewed.quote.amount.value
                                        .toString(),
                                  ),
                                  BullDetailsTableItem(
                                    label: _exitProgress(owner, reviewed.quote)
                                        ? l10n.exitProgressEstimatedFee
                                        : l10n.feeInSats,
                                    displayValue: reviewed.quote.fee.value
                                        .toString(),
                                  ),
                                  if (_exitProgress(owner, reviewed.quote) ||
                                      owner.request
                                          is ArkEmergencyExitQuoteRequest) ...[
                                    BullDetailsTableItem(
                                      label: l10n.exitProgressFeeRate,
                                      displayValue:
                                          reviewed.quote.feeRate?.satsPerVbyte
                                              .toString() ??
                                          l10n.unknown,
                                    ),
                                    BullDetailsTableItem(
                                      label: l10n.exitProgressReserveExposure,
                                      displayValue:
                                          reviewed
                                              .quote
                                              .confirmedReserveExposure
                                              ?.value
                                              .toString() ??
                                          l10n.unknown,
                                    ),
                                  ],
                                  if (reviewed.quote.maxClaimFee
                                      case final maximum?)
                                    BullDetailsTableItem(
                                      label: l10n.exitMaximumClaimFee,
                                      displayValue: maximum.value.toString(),
                                    ),
                                  BullDetailsTableItem(
                                    label: l10n.netInSats,
                                    displayValue: reviewed.quote.net.value
                                        .toString(),
                                  ),
                                  if (reviewed.quote.destination
                                      case final destination?)
                                    BullDetailsTableItem(
                                      label: l10n.destination,
                                      displayValue: destination,
                                    ),
                                  for (final id in reviewed.quote.selectedIds)
                                    BullDetailsTableItem(
                                      label: l10n.id,
                                      displayValue: id,
                                    ),
                                ],
                              ),
                            ],
                          ],
                          // Sent or unclear: the screen is closing.
                          const Gap(BullSpacing.md),
                        ],
                      ),
                    ),
            ),
            if (state case final ArkOperationReview reviewed)
              if (reviewed.quote.account == account)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BullSpacing.md,
                    BullSpacing.sm,
                    BullSpacing.md,
                    BullSpacing.lg,
                  ),
                  child: _button(
                    context,
                    l10n.confirm,
                    () => _confirm(owner, account, reviewed),
                    primary: true,
                    disabled: !_hasReviewFacts(owner, reviewed.quote),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _quoteHero(
    BuildContext context,
    ArkOperationCubit owner,
    ArkQuote quote,
  ) {
    final l10n = arkLocalizationsOf(context);
    final observation = widget.displayData;
    final matched = observation?.account == owner.account ? observation : null;
    final estimated =
        quote.kind == ArkOperationKind.emergencyExit ||
        quote.kind == ArkOperationKind.exitProgress;
    return Container(
      padding: const EdgeInsets.all(BullSpacing.lg),
      margin: const EdgeInsets.only(bottom: BullSpacing.md),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
      ),
      child: Column(
        children: [
          BullText(
            estimated ? l10n.operationEstimatedNet : l10n.netInSats,
            role: BullTextRole.label,
            color: context.bull.textMuted,
          ),
          const Gap(BullSpacing.sm),
          BullText(
            formatArkSats(context, quote.net),
            role: BullTextRole.headline,
            textAlign: TextAlign.center,
          ),
          ArkFiatAmount(amount: quote.net, price: matched?.price),
        ],
      ),
    );
  }

  List<Widget> _paymentReview(
    BuildContext context,
    ArkOperationCubit owner,
    ArkQuote quote,
  ) {
    final l10n = arkLocalizationsOf(context);
    final observation = widget.displayData;
    final price = observation?.account == owner.account
        ? observation?.price
        : null;
    return [
      const Gap(BullSpacing.md),
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.bull.surfaceContainerHighest,
          ),
          child: ExcludeSemantics(
            child: BullIcon(
              BullIcons.arrowUpward,
              size: 28,
              color: context.bull.text,
            ),
          ),
        ),
      ),
      const Gap(BullSpacing.md),
      Semantics(
        header: true,
        child: BullText(
          l10n.confirmSend,
          role: BullTextRole.body,
          textAlign: TextAlign.center,
        ),
      ),
      const Gap(BullSpacing.xs),
      BullText(
        formatArkSats(context, quote.net),
        role: BullTextRole.headline,
        fontWeight: FontWeight.w700,
        textAlign: TextAlign.center,
      ),
      const Gap(BullSpacing.lg),
      BullDetailsTable(
        items: [
          BullDetailsTableItem(label: l10n.fromLabel, displayValue: l10n.title),
          BullDetailsTableItem(
            label: l10n.toLabel,
            displayValue: quote.destination ?? l10n.unknown,
            copyValue: quote.destination,
            copiedMessage: l10n.copied,
            displayWidget: BullText(
              quote.destination ?? l10n.unknown,
              role: BullTextRole.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BullDetailsTableItem(
            label: l10n.amountLabel,
            displayValue: formatArkSats(context, quote.net),
            displayWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BullText(
                  formatArkSats(context, quote.net),
                  role: BullTextRole.body,
                  fontWeight: FontWeight.w500,
                ),
                ArkFiatAmount(
                  amount: quote.net,
                  price: price,
                  approximate: true,
                ),
              ],
            ),
          ),
          BullDetailsTableItem(
            label: l10n.networkFees,
            displayValue: formatArkSats(context, quote.fee),
          ),
          if (quote.amount != quote.net)
            BullDetailsTableItem(
              label: l10n.totalLabel,
              displayValue: formatArkSats(context, quote.amount),
            ),
        ],
      ),
    ];
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback action, {
    bool primary = false,
    bool disabled = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.md),
    child: BullButton.big(
      label: label,
      onPressed: action,
      disabled: disabled,
      bgColor: primary ? context.bull.inverseSurface : context.bull.surface,
      textColor: primary ? context.bull.surface : context.bull.text,
    ),
  );
}
