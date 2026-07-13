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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// The invoice detail (ISS-C-05 legacy `core/widgets`). It renders the polled
/// status snapshot (status, amount, expiry countdown, payment rails), offers an
/// unpaid-only cancel behind a confirm dialog, and supports pull-to-refresh.
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
          const Divider(),
          _row(
            context,
            context.loc.invoiceAmountLabel,
            context.loc.invoiceAmountSats(snapshot.amountSat),
          ),
          const Divider(),
          _expiry(context, snapshot),
          const Divider(),
          if (snapshot.lightningPr != null)
            _copyBlock(
              context,
              context.loc.invoicePaymentLightningLabel,
              snapshot.lightningPr!,
            ),
          if (snapshot.liquidAddress != null)
            _copyBlock(
              context,
              context.loc.invoicePaymentLiquidLabel,
              snapshot.liquidAddress!,
            ),
          if (snapshot.bitcoinAddress != null)
            _copyBlock(
              context,
              context.loc.invoicePaymentBitcoinLabel,
              snapshot.bitcoinAddress!,
            ),
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
