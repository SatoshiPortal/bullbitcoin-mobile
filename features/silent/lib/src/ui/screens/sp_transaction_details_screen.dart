import 'package:bull_ui/bull_ui.dart'
    show
        BullDetailsTable,
        BullDetailsTableItem,
        BullThemeX,
        BullTransactionDetailsPage,
        BullTransactionViewer,
        BullTypographyX,
        Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:mempool/mempool.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/ui/sp_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _directionLabel(BuildContext context, SpPaymentDirection direction) {
  switch (direction) {
    case SpPaymentDirection.receive:
      return context.silentLoc.silentReceived;
    case SpPaymentDirection.send:
      return context.silentLoc.silentSent;
    case SpPaymentDirection.selfSend:
      return context.silentLoc.silentSelfSend;
  }
}

class SpTransactionDetailsScreen extends StatelessWidget {
  const SpTransactionDetailsScreen({super.key, required this.payment});

  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.direction == SpPaymentDirection.receive;
    final network = payment.network;

    return BullTransactionDetailsPage(
      title: context.silentLoc.silentTransactionTitle,
      isLoading: false,
      isIncoming: isIncoming,
      onClose: () => context.pop(),
      status: _SpDetailsStatusLabel(payment: payment),
      amount: Text(
        FormatAmount.sats(payment.amountSat.value.toInt()),
        style: context.bullType.headline.copyWith(
          color: context.bull.secondary,
          fontWeight: .w500,
        ),
      ),
      details: Column(
        children: [
          BullDetailsTable(
            items: [
              BullDetailsTableItem(
                label: context.silentLoc.silentDirectionLabel,
                displayValue: _directionLabel(context, payment.direction),
              ),
              BullDetailsTableItem(
                label: context.silentLoc.amountLabel,
                displayValue: FormatAmount.sats(
                  payment.amountSat.value.toInt(),
                ),
              ),
              if (payment.feeSat != null)
                BullDetailsTableItem(
                  label: context.silentLoc.silentFeeLabel,
                  displayValue: FormatAmount.sats(
                    payment.feeSat!.value.toInt(),
                  ),
                ),
              if (payment.height != null)
                BullDetailsTableItem(
                  label: context.silentLoc.silentBlockRowLabel,
                  displayValue: '${payment.height}',
                ),
              if (payment.timestamp != null)
                BullDetailsTableItem(
                  label: context.silentLoc.silentTransactionDateLabel,
                  displayValue: DateFormat('MMM d, y, h:mm a').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      payment.timestamp!.toInt() * 1000,
                    ),
                  ),
                ),
            ],
          ),
          const Gap(16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.silentLoc.silentTransactionIdLabel,
              style: context.bullType.body.copyWith(
                color: context.bull.textMuted,
              ),
            ),
          ),
          const Gap(4),
          Align(
            alignment: Alignment.centerLeft,
            child: switch (network) {
              final BitcoinNetwork explorerNetwork
                  when explorerNetwork == BitcoinNetwork.mainnet ||
                      explorerNetwork == BitcoinNetwork.testnet =>
                BullTransactionViewer(
                  payment.txid,
                  title: context.silentLoc.transactionViewerTitle,
                  copiedMessage: context.silentLoc.copiedToClipboard,
                  copyLabel: context.silentLoc.viewerTapToCopy,
                  explorerActions: [
                    (
                      copyLabel: context.silentLoc.viewerCopyLink,
                      openLabel: context.silentLoc.viewerViewInExplorer,
                      resolveUrl: () async {
                        final link = await context
                            .read<MempoolLinks>()
                            .transaction(
                              payment.txid,
                              network: explorerNetwork,
                            );
                        return link.fold((uri) => uri.toString(), (_) => null);
                      },
                    ),
                  ],
                  openUrl: (url) async {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                ),
              _ => SelectableText(payment.txid),
            },
          ),
        ],
      ),
    );
  }
}

class _SpDetailsStatusLabel extends StatelessWidget {
  const _SpDetailsStatusLabel({required this.payment});
  final SpPayment payment;

  @override
  Widget build(BuildContext context) {
    final clickable =
        payment.status == SpPaymentStatus.confirmedUnverified ||
        payment.status == SpPaymentStatus.verifyFailed;
    final style = context.bullType.body
        .copyWith(fontWeight: FontWeight.w500)
        .copyWith(
          color: payment.status == SpPaymentStatus.verifyFailed
              ? context.bull.error
              : null,
          decoration: clickable ? TextDecoration.underline : null,
        );
    final label = switch (payment.status) {
      SpPaymentStatus.unconfirmed => context.silentLoc.silentUnconfirmed,
      SpPaymentStatus.confirmedUnverified => context.silentLoc.silentVerifying,
      SpPaymentStatus.verified => context.silentLoc.silentConfirmed,
      SpPaymentStatus.verifyFailed =>
        context.silentLoc.silentVerificationFailed,
    };
    if (!clickable) return Text(label, style: style);
    return InkWell(
      onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
      child: Text(label, style: style),
    );
  }
}
