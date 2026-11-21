import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
import 'package:flutter/widgets.dart' show EdgeInsetsDirectional;
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
    final displayQrData = state.displayQrData;
    if (!state.isLightning && state.qrData.isEmpty && failure != null) {
      return Column(
        children: [
          Text(failure.toTranslated(context), style: context.bullType.body),
          BullButton.secondary(
            label: context.loc.retry,
            onPressed: () =>
                context.read<ReceiveBloc>().add(const ReceiveAddressRetried()),
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
              behavior: HitTestBehavior.opaque,
              onTap: state.canOpenEnlargedQr
                  ? () => ReceiveEnlargedQr.show(context)
                  : null,
              child: displayQrData.isEmpty
                  ? BullShimmerBox(width: qrSize, height: qrSize)
                  : SizedBox.square(
                      dimension: qrSize,
                      child: BullQrCode(data: displayQrData, size: qrSize),
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
                ? BullInvoiceViewer.showDetail(
                    context,
                    data: state.addressOrInvoiceOnly,
                    title: context.loc.invoiceViewerTitle,
                    copyLabel: context.loc.viewerTapToCopy,
                    copiedMessage: context.loc.copiedToClipboard,

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
                  ? BullInvoiceViewer(
                      state.addressOrInvoiceOnly,
                      title: context.loc.invoiceViewerTitle,
                      copyLabel: context.loc.viewerTapToCopy,
                      copiedMessage: context.loc.copiedToClipboard,

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

  static void _showFees(BuildContext context) {
    BullBottomSheet.show<void>(
      context: context,
      child: BlocProvider.value(
        value: context.read<ReceiveBloc>(),
        child: const _ReceiveLnFeesSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final net = state.lightningReceivedSat;
    final amount = state.lightningAmountSat ?? state.confirmedAmountSat;
    final fees = state.lightningFeeSat;
    final showsLiquidDisclosure = state.wallet?.isLiquid ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReceiveInvoiceRow(
          label: context.loc.amountLabel,
          value: BullAmount.signedSats(
            amount ?? 0,
            textAlign: TextAlign.end,
            interactive: false,
          ),
          action: BullFieldAction(
            label: context.loc.receiveEditAmount,
            onPressed: () => context.pop(),
            icon: BullIcons.edit,
          ),
        ),
        _ReceiveInvoiceRow(
          label: context.loc.receiveFees,
          value: fees == null
              ? const BullShimmerLine(width: 90, height: 16)
              : BullAmount.signedSats(
                  fees,
                  textAlign: TextAlign.end,
                  interactive: false,
                ),
          action: BullFieldAction(
            label: context.loc.receiveFeeDetails,
            onPressed: () => _showFees(context),
            icon: BullIcons.chevronRight,
          ),
          onTap: () => _showFees(context),
        ),
        _ReceiveInvoiceRow(
          label: context.loc.receiveYouReceive,
          value: net == null
              ? const BullShimmerLine(width: 90, height: 16)
              : BullAmount.signedSats(
                  net,
                  textAlign: TextAlign.end,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  interactive: false,
                ),
        ),
        if (state.confirmedNote.isNotEmpty)
          _ReceiveInvoiceRow(
            label: context.loc.receiveMessage,
            value: Text(state.confirmedNote, textAlign: TextAlign.end),
          ),
        if (showsLiquidDisclosure) ...[
          Container(color: context.appColors.surface, height: 1),
          BullDisclosureLink(
            label: context.loc.receiveLiquidRiskDisclosureLabel,
            semanticLabel: context.loc.liquidRiskDisclosureSemanticLabel,
            title: context.loc.liquidRiskDisclosureTitle,
            body: context.loc.liquidRiskDisclosureBody,
            closeLabel: context.loc.closeDialogButton,
          ),
        ],
      ],
    );
  }
}

class _ReceiveLnFeesSheet extends StatelessWidget {
  const _ReceiveLnFeesSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BullTopBar(
          title: context.loc.receiveFees,
          onAction: () => Navigator.of(context).pop(),
        ),
        const ReceiveLnFeesDetails(),
        const ReceiveLnSwapID(),
      ],
    ),
  );
}

class ReceiveLnSwapID extends StatelessWidget {
  const ReceiveLnSwapID({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final number = state.orderSwap?.order?.orderNumber;
    final id = number?.toString() ?? state.getSwap?.id;
    return _ReceiveInvoiceRow(
      label: context.loc.swapTransferTitle,
      value: Text(
        id ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: context.bullType.body,
      ),
      action: BullFieldAction(
        label: context.loc.copyDialogButton,
        onPressed: id == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: id));
                BullSnackBar.show(
                  context,
                  message: context.loc.copiedToClipboard,
                );
              },
        icon: BullIcons.contentCopy,
      ),
    );
  }
}

class ReceiveLnFeesDetails extends StatelessWidget {
  const ReceiveLnFeesDetails({super.key});

  Widget _row(BuildContext context, String label, int amount) =>
      _ReceiveInvoiceRow(
        label: label,
        value: BullAmount.signedSats(
          amount,
          textAlign: TextAlign.end,
          interactive: false,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    final total = state.lightningFeeSat;
    final swap = state.getSwap;
    final fees = swap?.fees;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const Gap(12),
        Text(
          context.loc.receiveFeeExplanation,
          textAlign: TextAlign.start,
          style: context.bullType.caption.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Invoice values share an edge and reserve the same action slot on every row.
class _ReceiveInvoiceRow extends StatelessWidget {
  const _ReceiveInvoiceRow({
    required this.label,
    required this.value,
    this.action,
    this.onTap,
  });

  final String label;
  final Widget value;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsetsDirectional.only(end: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.appColors.outline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.bullType.label.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ),
                    const Gap(8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 2 / 3,
                      ),
                      child: value,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(8),
            SizedBox(width: 48, height: 48, child: action),
          ],
        ),
      ),
    ),
  );
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
          network: wallet.network.environment,
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
          network: wallet.network.environment,
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
  const _ReceiveSummaryRow({required this.title, this.leading, this.onTap});
  final Widget title;
  final Widget? leading;
  final VoidCallback? onTap;

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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (leading case final icon?) ...[icon, const Gap(16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
