import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:mempool/mempool.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullDetailsTable,
        BullDetailsTableItem,
        BullTransactionDetailsPage,
        BullTransactionViewer,
        BullTypographyX,
        Gap;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _directionLabel(BuildContext context, SpPaymentDirection direction) {
  switch (direction) {
    case SpPaymentDirection.receive:
      return context.loc.spReceived;
    case SpPaymentDirection.send:
      return context.loc.spSent;
    case SpPaymentDirection.selfSend:
      return context.loc.spSelfSend;
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
      title: context.loc.spTransactionTitle,
      isLoading: false,
      isIncoming: isIncoming,
      onClose: () => context.pop(),
      status: _SpDetailsStatusLabel(payment: payment),
      amount: Text(
        FormatAmount.sats(payment.amountSat.value.toInt()),
        style: context.bullType.headline.copyWith(
          color: context.appColors.secondary,
          fontWeight: .w500,
        ),
      ),
      details: Column(
        children: [
          BullDetailsTable(
            items: [
              BullDetailsTableItem(
                label: context.loc.spDirectionLabel,
                displayValue: _directionLabel(context, payment.direction),
              ),
              BullDetailsTableItem(
                label: context.loc.amountLabel,
                displayValue: FormatAmount.sats(
                  payment.amountSat.value.toInt(),
                ),
              ),
              if (payment.feeSat != null)
                BullDetailsTableItem(
                  label: context.loc.spFeeLabel,
                  displayValue: FormatAmount.sats(
                    payment.feeSat!.value.toInt(),
                  ),
                ),
              if (payment.height != null)
                BullDetailsTableItem(
                  label: context.loc.spBlockRowLabel,
                  displayValue: '${payment.height}',
                ),
              if (payment.timestamp != null)
                BullDetailsTableItem(
                  label: context.loc.spTransactionDateLabel,
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
              context.loc.spTransactionIdLabel,
              style: context.bullType.body.copyWith(
                color: context.appColors.textMuted,
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
                  title: context.loc.transactionViewerTitle,
                  copiedMessage: context.loc.copiedToClipboard,
                  copyLabel: context.loc.viewerTapToCopy,
                  explorerActions: [
                    (
                      copyLabel: context.loc.viewerCopyLink,
                      openLabel: context.loc.viewerViewInExplorer,
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
              ? context.appColors.error
              : null,
          decoration: clickable ? TextDecoration.underline : null,
        );
    final label = switch (payment.status) {
      SpPaymentStatus.unconfirmed => context.loc.spUnconfirmed,
      SpPaymentStatus.confirmedUnverified => context.loc.spVerifying,
      SpPaymentStatus.verified => context.loc.spConfirmed,
      SpPaymentStatus.verifyFailed => context.loc.spVerificationFailed,
    };
    if (!clickable) return Text(label, style: style);
    return InkWell(
      onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
      child: Text(label, style: style),
    );
  }
}
