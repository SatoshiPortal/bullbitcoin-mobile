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
    _subscription = owner.stream.listen((_) {
      if (_owns(owner, account)) setState(() {});
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

  void _reconcile(
    ArkOperationCubit owner,
    ArkAccountId account,
    ArkOperationState rendered,
  ) {
    if (!_current(owner, account, rendered) ||
        (rendered is! ArkOperationSubmitted &&
            rendered is! ArkOperationUncertain)) {
      return;
    }
    widget.onReconcile();
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
                title: l10n.review,
                titleWidget: BullText(l10n.review, role: BullTextRole.subtitle),
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state is ArkOperationLoading ||
                        state is ArkOperationSubmitting)
                      BullText(l10n.loading, style: null),
                    if (state case final ArkOperationFailed failed) ...[
                      BullInfoBar(
                        message: failed.failure.toTranslated(context),
                        tone: BullInfoTone.warning,
                      ),
                      _button(
                        context,
                        l10n.review,
                        () => _retry(owner, account, failed),
                      ),
                    ],
                    if (state case final ArkOperationReview reviewed) ...[
                      if (reviewed.quote.account != account)
                        BullInfoBar(message: l10n.unavailable),
                      if (reviewed.quote.account == account) ...[
                        if (_exitProgress(owner, reviewed.quote) ||
                            owner.request is ArkEmergencyExitQuoteRequest)
                          BullInfoBar(
                            message: l10n.exitProgressReviewWarning,
                            tone: BullInfoTone.warning,
                          ),
                        if (!_hasReviewFacts(owner, reviewed.quote))
                          BullInfoBar(
                            message: l10n.exitProgressReviewIncomplete,
                          ),
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
                              displayValue: reviewed.quote.fee.value.toString(),
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
                            if (reviewed.quote.maxClaimFee case final maximum?)
                              BullDetailsTableItem(
                                label: l10n.exitMaximumClaimFee,
                                displayValue: maximum.value.toString(),
                              ),
                            BullDetailsTableItem(
                              label: l10n.netInSats,
                              displayValue: reviewed.quote.net.value.toString(),
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
                    if (state case ArkOperationSubmitted(:final operation)) ...[
                      _submittedHero(context, owner, operation),
                      BullDetailsTable(
                        items: [
                          BullDetailsTableItem(
                            label: l10n.id,
                            displayValue: operation.id,
                          ),
                          BullDetailsTableItem(
                            label: l10n.state,
                            displayValue: operation.status.toTranslated(
                              context,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (state case ArkOperationUncertain(
                      :final operationId,
                    )) ...[
                      BullInfoBar(
                        message: l10n.uncertain,
                        tone: BullInfoTone.warning,
                      ),
                      BullDetailsTable(
                        items: [
                          BullDetailsTableItem(
                            label: l10n.id,
                            displayValue: operationId,
                          ),
                        ],
                      ),
                    ],
                    if (state is ArkOperationSubmitted ||
                        state is ArkOperationUncertain)
                      _button(
                        context,
                        l10n.refresh,
                        () => _reconcile(owner, account, state),
                      ),
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

  Widget _submittedHero(
    BuildContext context,
    ArkOperationCubit owner,
    ArkOperation operation,
  ) {
    final l10n = arkLocalizationsOf(context);
    // A backend success describes this operation, never chain finality.
    final title = operation.status == ArkOperationStatus.succeeded
        ? switch ((owner.request, operation.kind)) {
            (ArkRenewalQuoteRequest(), ArkOperationKind.renewal) =>
              l10n.operationRenewalStarted,
            (ArkEmergencyExitQuoteRequest(), ArkOperationKind.emergencyExit) =>
              l10n.emergencyExitStarted,
            (ArkPaymentQuoteRequest(), ArkOperationKind.payment) =>
              l10n.paymentSent,
            _ => null,
          }
        : null;
    final payment = title != null && operation.kind == ArkOperationKind.payment;
    final color = payment ? context.bull.success : context.bull.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BullSpacing.lg),
      child: Column(
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.all(BullSpacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: BullIcon(
                payment ? BullIcons.check : BullIcons.schedule,
                size: 32,
                color: color,
              ),
            ),
            const Gap(BullSpacing.md),
          ],
          BullText(
            title ?? operation.status.toTranslated(context),
            role: BullTextRole.headline,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
