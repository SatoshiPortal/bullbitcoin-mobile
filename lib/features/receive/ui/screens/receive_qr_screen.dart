import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/invoice_viewer.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/receive_failure_l10n.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_amount_input.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_advanced_settings.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_enlarged_qr.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveQrPage extends StatelessWidget {
  const ReceiveQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              state.isLightning ? 16 : 24,
              16,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.orderSwap case final order?
                    when order.order?.requiresManualReview == true)
                  OrderSwapUnderReviewCard(orderSwap: order),
                const ReceiveQRDetails(),
                const Gap(16),
                const ReceiveInfoDetails(),
              ],
            ),
          ),
        ),
        if (!state.isLightning)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ReceiveAdvancedSettingsLink(),
          ),
      ],
    );
  }
}

class ReceiveQRDetails extends StatelessWidget {
  const ReceiveQRDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final failure = state.failure;
    final qrSize = state.isLightning ? 217.0 : 240.0;
    if (!state.isLightning && state.qrData.isEmpty && failure != null) {
      return Column(
        children: [
          Text(failure.toTranslated(context), style: context.bullType.body),
          BullButton.secondary(
            label: context.loc.retry,
            onPressed: () => context.read<ReceiveBloc>().add(
              state.type == ReceiveType.bitcoin
                  ? ReceiveBitcoinStarted(state.wallet)
                  : const ReceiveLiquidStarted(),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: context.loc.receiveEnlargeQr,
            child: GestureDetector(
              onTap: state.qrData.isEmpty
                  ? null
                  : () => ReceiveEnlargedQr.show(context, state),
              child: state.qrData.isEmpty
                  ? BullShimmerBox(width: qrSize, height: qrSize)
                  : Container(
                      width: qrSize,
                      height: qrSize,
                      color: context.appColors.surfaceFixed,
                      child: BullQrCode(data: state.qrData, size: qrSize),
                    ),
            ),
          ),
        ),
        const Gap(16),
        Text(
          state.isLightning
              ? context.loc.receiveInvoice
              : context.loc.receiveAddress,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(6),
        SizedBox(
          height: 56,
          child: BullBorderedTile(
            backgroundColor: context.appColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => state.isLightning
                ? InvoiceViewer.showDetail(
                    context,
                    data: state.addressOrInvoiceOnly,
                    clipboardText: state.clipboardData,
                  )
                : AddressViewer.showDetail(
                    context,
                    data: state.addressOrInvoiceOnly,
                    clipboardText: state.clipboardData,
                  ),
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: state.clipboardData));
              BullSnackBar.show(
                context,
                message: context.loc.copiedToClipboard,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: state.isLightning
                  ? InvoiceViewer(
                      state.addressOrInvoiceOnly,
                      clipboardText: state.clipboardData,
                      style: context.bullType.body.copyWith(
                        decorationThickness: 1.5,
                      ),
                    )
                  : AddressViewer(
                      state.addressOrInvoiceOnly,
                      clipboardText: state.clipboardData,
                      style: context.bullType.body.copyWith(
                        decorationThickness: 1.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReceiveInfoDetails extends StatefulWidget {
  const ReceiveInfoDetails({super.key});
  @override
  State<ReceiveInfoDetails> createState() => _ReceiveInfoDetailsState();
}

class _ReceiveInfoDetailsState extends State<ReceiveInfoDetails> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    if (state.isLightning) return const ReceiveLnInfoDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.amountLabel,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(6),
        ReceiveAmountInput(focusNode: _focus, live: true, inCard: true),
      ],
    );
  }
}

class ReceiveLnInfoDetails extends StatelessWidget {
  const ReceiveLnInfoDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final net = state.lightningReceivedSat;
    final amount = state.lightningAmountSat ?? state.confirmedAmountSat;
    final fees = state.lightningFeeSat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReceiveSummaryRow(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.loc.amountLabel,
            style: context.bullType.label.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: CurrencyText(
                  amount ?? 0,
                  showFiat: false,
                  textAlign: TextAlign.end,
                ),
              ),
              const Gap(8),
              BullFieldAction(
                label: context.loc.receiveEditAmount,
                onPressed: () => context.pop(),
                icon: BullIcons.edit,
              ),
            ],
          ),
        ),
        _ReceiveSummaryRow(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.loc.receiveFees,
            style: context.bullType.label.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fees != null)
                Flexible(
                  child: CurrencyText(
                    fees,
                    showFiat: false,
                    textAlign: TextAlign.end,
                  ),
                ),
              const Gap(8),
              const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: BullIcon(BullIcons.chevronRight)),
              ),
            ],
          ),
          onTap: () => BullBottomSheet.show<void>(
            context: context,
            style: BullSheetStyle.redesign(context),
            child: BlocProvider.value(
              value: context.read<ReceiveBloc>(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.loc.receiveFees,
                      style: context.bullType.title,
                    ),
                    const ReceiveLnFeesDetails(),
                    const ReceiveLnSwapID(),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ReceiveSummaryRow(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.loc.receiveYouReceive,
            style: context.bullType.label.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          trailing: net == null
              ? const BullShimmerLine(width: 90, height: 16)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CurrencyText(
                      net,
                      showFiat: false,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
        ),
        if (state.confirmedNote.isNotEmpty)
          _ReceiveSummaryRow(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.loc.receiveMessage,
              style: context.bullType.label.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(state.confirmedNote, textAlign: TextAlign.end),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
      ],
    );
  }
}

class ReceiveLnSwapID extends StatelessWidget {
  const ReceiveLnSwapID({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final number = state.orderSwap?.order?.orderNumber;
    final id = number?.toString() ?? state.getSwap?.id;
    return _ReceiveSummaryRow(
      title: Text(context.loc.swapTransferTitle),
      subtitle: Text(id ?? ''),
      trailing: BullInlineIconButton(
        tooltip: context.loc.copyDialogButton,
        onPressed: id == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: id));
                BullSnackBar.show(
                  context,
                  message: context.loc.copiedToClipboard,
                );
              },
        icon: const BullIcon(BullIcons.contentCopy),
      ),
    );
  }
}

class ReceiveLnFeesDetails extends StatelessWidget {
  const ReceiveLnFeesDetails({super.key});

  Widget _row(BuildContext context, String label, int amount) =>
      _ReceiveSummaryRow(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: context.bullType.body),
        trailing: CurrencyText(amount, showFiat: false),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final total = state.lightningFeeSat;
    final swap = state.getSwap;
    final fees = swap?.fees;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (total == null)
          const BullShimmerLine(width: 90, height: 16)
        else
          _row(context, context.loc.receiveTotalFee, total),
        if (fees != null && state.orderSwap == null) ...[
          if (fees.lockupFee case final amount?)
            _row(context, context.loc.receiveSendNetworkFee, amount),
          if (fees.refundFee ?? fees.claimFee case final amount?)
            _row(context, context.loc.receiveNetworkFee, amount),
          if (fees.serverNetworkFees case final amount?)
            _row(context, context.loc.receiveServerNetworkFees, amount),
          _row(
            context,
            context.loc.receiveTransferFee,
            fees.boltzPercent != null
                ? fees.boltzFeeFromPercent(swap?.amountSat ?? 0)
                : fees.boltzFee ?? 0,
          ),
        ],
        Text(
          context.loc.receiveFeeExplanation,
          style: context.bullType.label.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class VerifyAddressOnLedgerButton extends StatelessWidget {
  const VerifyAddressOnLedgerButton({super.key});
  @override
  Widget build(BuildContext context) => _ReceiveSummaryRow(
    leading: const BullIcon(BullIcons.verified),
    title: Text(context.loc.receiveVerifyAddressLedger),
    onTap: () {
      final state = context.read<ReceiveBloc>().state;
      final wallet = state.wallet;
      final address = state.bitcoinAddress;
      if (wallet == null || address == null) {
        BullSnackBar.show(
          context,
          message: context.loc.receiveVerifyAddressError,
        );
        return;
      }
      final chain = address.keyChain == WalletAddressKeyChain.external
          ? '0'
          : '1';
      context.pushNamed(
        LedgerRoute.ledgerVerifyAddress.name,
        extra: LedgerRouteParams(
          address: state.address,
          derivationPath: '${wallet.derivationPath}/$chain/${address.index}',
          requestedDeviceType: wallet.signerDevice,
          scriptType: wallet.scriptType,
        ),
      );
    },
  );
}

class VerifyAddressOnBitBoxButton extends StatelessWidget {
  const VerifyAddressOnBitBoxButton({super.key});
  @override
  Widget build(BuildContext context) => _ReceiveSummaryRow(
    leading: const BullIcon(BullIcons.verified),
    title: Text(context.loc.receiveVerifyBitbox),
    onTap: () {
      final state = context.read<ReceiveBloc>().state;
      final wallet = state.wallet;
      final address = state.bitcoinAddress;
      if (wallet == null || address == null) {
        BullSnackBar.show(
          context,
          message: context.loc.receiveVerifyAddressError,
        );
        return;
      }
      final chain = address.keyChain == WalletAddressKeyChain.external
          ? '0'
          : '1';
      context.pushNamed(
        BitBoxRoute.bitboxVerifyAddress.name,
        extra: BitBoxRouteParams(
          address: state.address,
          derivationPath: '${wallet.derivationPath}/$chain/${address.index}',
          requestedDeviceType: wallet.signerDevice,
          scriptType: wallet.scriptType,
        ),
      );
    },
  );
}

/// Receive summary layout; actions retain their own 48 dp kit targets.
class _ReceiveSummaryRow extends StatelessWidget {
  const _ReceiveSummaryRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.contentPadding,
  });
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appColors.outline)),
        ),
        padding: contentPadding ?? const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (leading case final icon?) ...[icon, const Gap(16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, ?subtitle],
              ),
            ),
            if (trailing case final value?) ...[
              const Gap(8),
              Flexible(
                flex: 2,
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
