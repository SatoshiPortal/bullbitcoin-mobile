import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_state.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_failure_l10n.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/invoice_list_item.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/private_invoice_link_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// The invoice detail (ISS-C-05 legacy `core/widgets`). It renders the polled
/// status snapshot, the locally retained private link, and unpaid-only cancel.
class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceDetailCubit, InvoiceDetailState>(
      listenWhen: (previous, current) =>
          previous.cancelFailure != current.cancelFailure &&
          current.cancelFailure != null,
      listener: (context, state) {
        final failure = state.cancelFailure;
        if (failure != null) {
          SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(context.loc.invoiceDetailTitle)),
          body: SafeArea(
            child: switch (state.status) {
              InvoiceDetailStatus.loading => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingBoxContent(height: 72),
                    LoadingLineContent(),
                    LoadingLineContent(width: 220),
                  ],
                ),
              ),
              InvoiceDetailStatus.error => _error(context, state),
              InvoiceDetailStatus.loaded => _loaded(context, state),
            },
          ),
        );
      },
    );
  }

  Widget _error(BuildContext context, InvoiceDetailState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          state.failure?.toTranslated(context) ??
              context.loc.invoiceErrorUnexpected,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _loaded(BuildContext context, InvoiceDetailState state) {
    final cubit = context.read<InvoiceDetailCubit>();
    final snapshot = state.snapshot!;
    final status = state.effectiveStatus ?? snapshot.status;
    final unsupported = status.isUnsupported;
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(
            context,
            context.loc.invoiceStatusLabel,
            invoiceStatusText(context, status),
          ),
          if (invoiceSettlementSupportingText(context, snapshot.settlementState)
              case final settlementText?)
            _supportingStatus(context, settlementText),
          if (snapshot.hasLatePayment)
            _supportingStatus(context, context.loc.invoiceLatePayment),
          const Divider(),
          _row(
            context,
            context.loc.invoiceAmountLabel,
            context.loc.invoiceAmountSats(snapshot.amountSat),
          ),
          if (snapshot.paidAmountSat case final paidAmountSat?)
            _row(
              context,
              context.loc.invoicePaymentReceivedLabel,
              context.loc.invoiceAmountSats(paidAmountSat),
            ),
          if (snapshot.hasPaymentEvidence && snapshot.remainingAmountSat > 0)
            _row(
              context,
              context.loc.invoicePaymentRemainingLabel,
              context.loc.invoiceAmountSats(snapshot.remainingAmountSat),
            ),
          if (snapshot.paidAmountSat case final paidAmountSat?
              when paidAmountSat > snapshot.amountSat)
            _row(
              context,
              context.loc.invoicePaymentOverpaidByLabel,
              context.loc.invoiceAmountSats(paidAmountSat - snapshot.amountSat),
            ),
          const Divider(),
          _expiry(context, snapshot),
          const Divider(),
          if (unsupported) _unsupportedStatus(context),
          if (state.fallbackSupervisionFailure != null)
            _notice(context, context.loc.invoiceFallbackUnavailable),
          if (state.fallbackSupervisionOverflow)
            _notice(context, context.loc.invoiceFallbackOverflow),
          if (snapshot.paymentEvents.isNotEmpty ||
              state.fallbackSupervisions.isNotEmpty) ...[
            Text(
              context.loc.invoicePaymentHistoryTitle,
              style: context.font.titleMedium,
            ),
            const Gap(8),
            for (final payment in snapshot.paymentEvents)
              _paymentEventBlock(context, payment),
            for (final fallback in state.fallbackSupervisions)
              _fallbackBlock(context, fallback),
          ],
          if (!unsupported) ...[
            const Gap(20),
            Text(
              context.loc.invoicePrivateLinkSection,
              style: context.font.titleMedium,
            ),
            const Gap(8),
            if (!state.privateLinkLookupComplete)
              const Center(child: CircularProgressIndicator())
            else if (state.privateLink case final link?)
              PrivateInvoiceLinkActions(link: link.value)
            else
              Text(
                context.loc.invoicePrivateLinkUnavailable,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
          ],
          const Gap(24),
          if (state.canCancel)
            BBButton.big(
              label: context.loc.invoiceCancelButton,
              onPressed: () => _confirmCancel(context, cubit),
              disabled: state.cancelling,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
        ],
      ),
    );
  }

  Widget _unsupportedStatus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        context.loc.invoiceUnsupportedStatusMessage,
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
    );
  }

  Widget _notice(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.appColors.textMuted,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              text,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportingStatus(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _paymentEventBlock(BuildContext context, InvoicePaymentEvent payment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_paymentRailTitle(context, payment.rail)),
          const Gap(4),
          Text(
            _paymentEventStateText(context, payment),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          if (payment.isLate)
            Text(
              context.loc.invoiceLatePayment,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          _row(
            context,
            context.loc.invoicePaymentReceivedLabel,
            context.loc.invoiceAmountSats(payment.amountSat),
          ),
          if (payment.transactionId case final transactionId?)
            _copyBlock(
              context,
              context.loc.invoicePaymentTransactionLabel,
              transactionId,
            ),
          const Divider(),
        ],
      ),
    );
  }

  String _paymentRailTitle(BuildContext context, PaymentMethod rail) {
    return switch (rail) {
      PaymentMethod.btc => context.loc.invoicePaymentEventBitcoinTitle,
      PaymentMethod.lightning => context.loc.invoicePaymentEventLightningTitle,
      PaymentMethod.liquid => context.loc.invoicePaymentEventLiquidTitle,
    };
  }

  String _paymentEventStateText(
    BuildContext context,
    InvoicePaymentEvent payment,
  ) {
    if (payment.state == InvoicePaymentEventState.problem) {
      return switch (payment.problem) {
        InvoicePaymentProblem.evicted =>
          context.loc.invoicePaymentProblemEvicted,
        InvoicePaymentProblem.reorged =>
          context.loc.invoicePaymentProblemReorged,
        InvoicePaymentProblem.conflicted =>
          context.loc.invoicePaymentProblemConflicted,
        InvoicePaymentProblem.replaced =>
          context.loc.invoicePaymentProblemReplaced,
        InvoicePaymentProblem.unknown ||
        null => context.loc.invoicePaymentProblemUnknown,
      };
    }
    return switch (payment.state) {
      InvoicePaymentEventState.pending =>
        payment.rail == PaymentMethod.btc
            ? context.loc.invoicePaymentSeenMempool
            : context.loc.invoiceSettlementPending,
      InvoicePaymentEventState.confirming =>
        context.loc.invoicePaymentConfirmations(payment.confirmations),
      InvoicePaymentEventState.settled => context.loc.invoiceSettlementComplete,
      InvoicePaymentEventState.problem =>
        context.loc.invoicePaymentProblemUnknown,
    };
  }

  Widget _fallbackBlock(
    BuildContext context,
    InvoiceFallbackSupervision fallback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.invoicePaymentEventFallbackTitle,
            style: context.font.bodyLarge,
          ),
          const Gap(4),
          Text(
            invoiceFallbackStateText(context, fallback.state),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(8),
          _row(
            context,
            context.loc.invoiceFallbackPayerAmountLabel,
            context.loc.invoiceAmountSats(fallback.payerAmountSat),
          ),
          _row(
            context,
            context.loc.invoiceFallbackInvoiceAmountLabel,
            context.loc.invoiceAmountSats(fallback.invoiceSwapAmountSat),
          ),
          if (fallback.fallbackAddress case final address?)
            _copyBlock(
              context,
              context.loc.invoiceFallbackDestinationLabel,
              address,
            ),
          if (fallback.transactionId case final transactionId?)
            _copyBlock(
              context,
              context.loc.invoiceFallbackTransactionLabel,
              transactionId,
            ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _expiry(BuildContext context, InvoiceStatusSnapshot snapshot) {
    final expired =
        snapshot.timeUntilExpiry(DateTime.now().toUtc()) == Duration.zero;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.loc.invoiceExpiresLabel,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        expired
            ? Text(context.loc.invoiceExpiredLabel)
            : Countdown(
                until: snapshot.expiresAt,
                format: CountdownFormat.dhm,
                onTimeout: () {},
              ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          Text(value, style: context.font.bodyLarge),
        ],
      ),
    );
  }

  Widget _copyBlock(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(12),
        Text(
          label,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        CopyInput(text: value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    InvoiceDetailCubit cubit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.invoiceCancelConfirmTitle),
        content: Text(dialogContext.loc.invoiceCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.loc.invoiceCancelConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.loc.invoiceCancelConfirmConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.cancel();
  }
}
