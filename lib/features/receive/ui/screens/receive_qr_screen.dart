import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/disclosure_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/invoice_viewer.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_payjoin_toggle_button.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';

class ReceiveQrPage extends StatelessWidget {
  const ReceiveQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isLightning = context.select(
      (ReceiveBloc bloc) => bloc.state.type == ReceiveType.lightning,
    );
    final isLedger = context.select(
      (ReceiveBloc bloc) => bloc.state.wallet?.signerDevice?.isLedger ?? false,
    );
    final isBitBox = context.select(
      (ReceiveBloc bloc) => bloc.state.wallet?.signerDevice?.isBitBox ?? false,
    );
    final showAddressVerification = !isLightning && (isLedger || isBitBox);
    final orderSwap = context.select(
      (ReceiveBloc bloc) => bloc.state.orderSwap,
    );

    final gap = Device.screen.height * 0.02;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          // const Gap(10),
          // const ReceiveNetworkSelection(),
          Gap(gap),
          if (orderSwap?.order?.requiresManualReview == true) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OrderSwapUnderReviewCard(orderSwap: orderSwap!),
            ),
            Gap(gap),
          ],
          const ReceiveQRDetails(),
          // Half-gaps below the address block: matches the address→payjoin
          // spacing inside ReceiveQRDetails so the stack reads evenly.
          Gap(gap / 2),
          const ReceiveInfoDetails(),
          Gap(gap / 2),
          if (showAddressVerification) ...[
            if (isLedger)
              const Column(children: [VerifyAddressOnLedgerButton()]),
            if (isBitBox)
              const Column(children: [VerifyAddressOnBitBoxButton()]),
            Gap(gap),
          ],
          if (!isLightning) const ReceiveNewAddressButton(),
          Gap(gap / 2),
        ],
      ),
    );
  }
}

class ReceiveQRDetails extends StatelessWidget {
  const ReceiveQRDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final isBitcoin = context.select(
      (ReceiveBloc bloc) => bloc.state.type == ReceiveType.bitcoin,
    );
    final isLightning = context.select(
      (ReceiveBloc bloc) => bloc.state.type == ReceiveType.lightning,
    );
    final qrData = context.select((ReceiveBloc bloc) => bloc.state.qrData);
    final clipboardData = context.select(
      (ReceiveBloc bloc) => bloc.state.clipboardData,
    );
    final addressOrInvoiceOnly = context.select(
      (ReceiveBloc bloc) => bloc.state.addressOrInvoiceOnly,
    );
    final selectedWallet = context.watch<ReceiveBloc>().state.wallet;
    final wallets = context.select((ReceiveBloc bloc) => bloc.state.wallets);
    final isPayjoinAwaitingFunds = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinAwaitingFunds,
    );
    final isPayjoinSuppressedByAmount = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinSuppressedByAmount,
    );

    final gap = Device.screen.height * 0.02;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (wallets.length > 1 &&
              isBitcoin &&
              selectedWallet != null &&
              selectedWallet.isBitcoin)
            BullBorderedTile(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: DropdownButtonFormField<Wallet>(
                alignment: Alignment.centerLeft,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.secondary,
                ),
                iconSize: 24,
                dropdownColor: context.appColors.onSecondary,
                initialValue: selectedWallet,
                items: wallets.map((w) {
                  return DropdownMenuItem(
                    value: w,
                    child: Text(
                      w.displayLabel(context),
                      style: context.bullText.headlineSmall?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    context.read<ReceiveBloc>().add(
                      ReceiveEvent.receiveBitcoinStarted(value),
                    );
                  }
                },
              ),
            ),
          Gap(gap),
          Center(child: QrDisplayWidget(data: qrData, size: 217)),
          Gap(gap),
          if (isBitcoin && isPayjoinAwaitingFunds) ...[
            BullInfoCard(
              description: context.loc.receivePayjoinAwaitingFunds,
              tagColor: context.appColors.secondary,
              bgColor: context.appColors.onSecondary,
            ),
            Gap(gap),
          ],
          if (isBitcoin && isPayjoinSuppressedByAmount) ...[
            BullInfoCard(
              description: context.loc.receivePayjoinBelowMinimumAmount,
              tagColor: context.appColors.secondary,
              bgColor: context.appColors.onSecondary,
            ),
            Gap(gap),
          ],
          BullBorderedTile(
            backgroundColor: context.appColors.surfaceContainerHighest,
            onTap: () => isLightning
                ? InvoiceViewer.showDetail(
                    context,
                    data: addressOrInvoiceOnly,
                    clipboardText: clipboardData,
                  )
                : AddressViewer.showDetail(
                    context,
                    data: addressOrInvoiceOnly,
                    clipboardText: clipboardData,
                  ),
            onLongPress: () {
              Clipboard.setData(
                ClipboardData(
                  text: clipboardData.isNotEmpty
                      ? clipboardData
                      : addressOrInvoiceOnly,
                ),
              );
              SnackBarUtils.showCopiedSnackBar(context);
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        isLightning
                            ? context.loc.receiveLightningInvoice
                            : context.loc.receiveAddress,
                        style: context.bullText.bodyLarge,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      isLightning
                          ? InvoiceViewer(
                              addressOrInvoiceOnly,
                              clipboardText: clipboardData,
                              style: context.bullText.bodyLarge,
                              color: context.appColors.secondary,
                            )
                          : AddressViewer(
                              addressOrInvoiceOnly,
                              clipboardText: clipboardData,
                              style: context.bullText.bodyLarge,
                              color: context.appColors.secondary,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Payjoin toggle directly under the address (self-gating: renders
          // nothing on Liquid/Lightning or non-payjoin-capable wallets).
          ReceivePayjoinToggleTile(topGap: gap),
        ],
      ),
    );
  }
}

class ReceiveInfoDetails extends StatelessWidget {
  const ReceiveInfoDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final amountSat = context.select(
      (ReceiveBloc bloc) => bloc.state.confirmedAmountSat,
    );
    final note = context.select<ReceiveBloc, String>((bloc) => bloc.state.note);
    final type = context.select<ReceiveBloc, ReceiveType?>(
      (bloc) => bloc.state.type,
    );
    final enteredUnitSuffix = context.select<ReceiveBloc, String>((bloc) {
      final state = bloc.state;
      final sats = state.confirmedAmountSat;
      if (sats == null ||
          state.inputAmountCurrencyCode == BitcoinUnit.btc.code) {
        return '';
      }
      if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        return ' (${FormatAmount.sats(sats)})';
      }
      return ' (~${state.formattedConfirmedAmountFiat})';
    });

    if (type == ReceiveType.lightning) return const ReceiveLnInfoDetails();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          // Amount + note unified behind one element (product decision
          // 2026-07-26): the sheet edits both, this tile just summarises.
          BullBorderedTile(
            // This tile renders for both the bitcoin and the liquid QR page;
            // the two amount routes share the 'amount' path but live under
            // different parents, so push the one matching the current flow.
            onTap: () => context.pushNamed(
              type == ReceiveType.liquid
                  ? ReceiveRoute.liquidAmount.name
                  : ReceiveRoute.bitcoinAmount.name,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        context.loc.receiveAdditionalInformation,
                        style: context.bullText.bodyLarge,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      // Amount row: the BIP21 string always carries BTC, so
                      // always show the BTC value; when the user entered in
                      // another unit (sats or fiat), show that alongside.
                      if (amountSat != null)
                        BullText(
                          '${context.loc.coreScreensAmountLabel}: '
                          '${FormatAmount.btc(ConvertAmount.satsToBtc(amountSat))}'
                          '$enteredUnitSuffix',
                          style: context.bullText.bodyMedium,
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      if (note.isNotEmpty)
                        BullText(
                          '${context.loc.receiveMessageForSender}: $note',
                          style: context.bullText.bodyMedium,
                          maxLines: 2,
                          overflow: .ellipsis,
                        ),
                      if (amountSat == null && note.isEmpty)
                        BullText(
                          context.loc.receiveAdditionalInformationPlaceholder,
                          style: context.bullText.bodyMedium,
                          color: context.appColors.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.edit, size: 20, color: context.appColors.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiveLnInfoDetails extends StatelessWidget {
  const ReceiveLnInfoDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final amountSat = context.select(
      (ReceiveBloc bloc) => bloc.state.confirmedAmountSat,
    );
    final amountEquivalent = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedConfirmedAmountFiat,
    );
    final note = context.select<ReceiveBloc, String>((bloc) => bloc.state.note);
    final swap = context.select((ReceiveBloc bloc) => bloc.state.getSwap);
    final showsLiquidDisclosure = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state.wallet?.isLiquid ?? false,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appColors.cardBackground,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: context.appColors.surface),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            color: context.appColors.surfaceContainer,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Gap(12),
          const ReceiveLnSwapID(),
          const Gap(12),

          Container(color: context.appColors.surface, height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                BullText(
                  context.loc.transactionLabelSendAmount,
                  style: context.bullText.bodySmall,
                  color: context.appColors.onSurfaceVariant,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: .end,
                  children: [
                    CurrencyText(
                      amountSat ?? 0,
                      showFiat: false,
                      style: context.bullText.bodyMedium,
                      color: context.appColors.secondary,
                    ),
                    BullText(
                      '~$amountEquivalent',
                      style: context.bullText.labelSmall,
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(color: context.appColors.surface, height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                BullText(
                  context.loc.receiveReceiveAmount,
                  style: context.bullText.bodySmall,
                  color: context.appColors.onSurfaceVariant,
                ),
                const Spacer(),
                if (swap?.receieveAmount == null)
                  const LoadingLineContent(
                    width: 90,
                    height: 14,
                    padding: EdgeInsets.zero,
                  )
                else
                  CurrencyText(
                    swap!.receieveAmount!,
                    showFiat: false,
                    style: context.bullText.bodyMedium,
                    color: context.appColors.secondary,
                  ),
              ],
            ),
          ),
          if (note.isNotEmpty) ...[
            Container(color: context.appColors.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Row(
                children: [
                  BullText(
                    context.loc.receiveNote,
                    style: context.bullText.labelSmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const Gap(24),
                  Expanded(
                    child: BullText(
                      note.isNotEmpty ? note : '',
                      style: context.bullText.bodyMedium,
                      color: context.appColors.secondary,
                      maxLines: 5,
                      textAlign: .end,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const ReceiveLnFeesDetails(),
          if (showsLiquidDisclosure) ...[
            Container(color: context.appColors.surface, height: 1),
            DisclosureLink(
              label: context.loc.receiveLiquidRiskDisclosureLabel,
              semanticLabel: context.loc.liquidRiskDisclosureSemanticLabel,
              title: context.loc.liquidRiskDisclosureTitle,
              body: context.loc.liquidRiskDisclosureBody,
            ),
          ],
        ],
      ),
    );
  }
}

class ReceiveLnSwapID extends StatelessWidget {
  const ReceiveLnSwapID({super.key});

  @override
  Widget build(BuildContext context) {
    final swap = context.select((ReceiveBloc bloc) => bloc.state.getSwap);
    final orderNumber = context.select(
      (ReceiveBloc bloc) => bloc.state.orderSwap?.order?.orderNumber,
    );
    final identifier = orderNumber?.toString() ?? swap?.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BullText(
            context.loc.swapTransferTitle,
            style: context.bullText.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          if (identifier == null)
            const LoadingLineContent(
              width: 120,
              height: 14,
              padding: EdgeInsets.zero,
            )
          else ...[
            BullText(
              orderNumber?.toString() ??
                  StringFormatting.truncateMiddle(identifier),
              style: context.bullText.bodyLarge,
              color: context.appColors.secondary,
              textAlign: .end,
            ),
            const Gap(4),
            InkWell(
              child: Icon(
                Icons.copy,
                color: context.appColors.primary,
                size: 16,
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: identifier));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class ReceiveLnFeesDetails extends StatefulWidget {
  const ReceiveLnFeesDetails({super.key});

  @override
  State<ReceiveLnFeesDetails> createState() => _ReceiveLnFeesDetailsState();
}

class _ReceiveLnFeesDetailsState extends State<ReceiveLnFeesDetails> {
  bool expanded = false;

  Widget _feeRow(BuildContext context, String label, int amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BullText(
            label,
            style: context.bullText.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.bullText.bodySmall,
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final swap = context.select((ReceiveBloc bloc) => bloc.state.getSwap);

    if (swap == null) {
      return Column(
        children: [
          Container(color: context.appColors.surface, height: 1),
          const Gap(8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                BullText(
                  context.loc.receiveTotalFee,
                  style: context.bullText.bodySmall,
                  color: context.appColors.onSurfaceVariant,
                ),
                const Spacer(),
                const LoadingLineContent(
                  width: 90,
                  height: 14,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(color: context.appColors.surface, height: 1),
        const Gap(8),
        InkWell(
          splashColor: context.appColors.transparent,
          splashFactory: NoSplash.splashFactory,
          highlightColor: context.appColors.transparent,
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Row(
            children: [
              BullText(
                context.loc.receiveTotalFee,
                style: context.font.bodySmall,
                color: context.appColors.onSurfaceVariant,
              ),
              const Spacer(),
              CurrencyText(
                swap.fees?.totalFees(null) ?? 0,
                showFiat: false,
                style: context.bullText.bodyLarge,
                color: context.appColors.secondary,
              ),
              const Gap(4),
              Icon(
                expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: context.appColors.primary,
              ),
            ],
          ),
        ),
        const Gap(12),
        if (expanded && swap.fees != null) ...[
          Container(color: context.appColors.surface, height: 1),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BullText(
              context.loc.receiveFeeExplanation,
              style: context.bullText.labelSmall,
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          if (swap.fees!.lockupFee != null)
            _feeRow(
              context,
              context.loc.receiveSendNetworkFee,
              swap.fees!.lockupFee!,
            ),
          if (swap.fees!.claimFee != null)
            _feeRow(
              context,
              context.loc.receiveNetworkFee,
              swap.fees!.claimFee!,
            ),
          if (swap.fees!.serverNetworkFees != null)
            _feeRow(
              context,
              context.loc.receiveServerNetworkFees,
              swap.fees!.serverNetworkFees!,
            ),
          _feeRow(
            context,
            context.loc.receiveTransferFee,
            swap.fees?.boltzFee ?? 0,
          ),
          const Gap(16),
        ],
      ],
    );
  }
}

class ReceiveNewAddressButton extends StatelessWidget {
  const ReceiveNewAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BullButton.primary(
        label: context.loc.receiveNewAddress,
        onPressed: () {
          context.read<ReceiveBloc>().add(
            const ReceiveEvent.receiveNewAddressGenerated(),
          );
        },
      ),
    );
  }
}

class VerifyAddressOnLedgerButton extends StatelessWidget {
  const VerifyAddressOnLedgerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BullButton.secondary(
        label: context.loc.receiveVerifyAddressLedger,
        onPressed: () {
          final state = context.read<ReceiveBloc>().state;

          if (state.wallet == null || state.bitcoinAddress == null) {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.receiveVerifyAddressError,
            );
            return;
          }

          final keyChainPath =
              state.bitcoinAddress!.keyChain == WalletAddressKeyChain.external
              ? "0"
              : "1";
          final derivationPath =
              "${state.wallet!.derivationPath}/$keyChainPath/${state.bitcoinAddress!.index}";
          context.pushNamed(
            LedgerRoute.ledgerVerifyAddress.name,
            extra: LedgerRouteParams(
              address: state.address,
              derivationPath: derivationPath,
              requestedDeviceType: state.wallet!.signerDevice,
              scriptType: state.wallet!.scriptType,
            ),
          );
        },
      ),
    );
  }
}

class VerifyAddressOnBitBoxButton extends StatelessWidget {
  const VerifyAddressOnBitBoxButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BullButton.secondary(
        label: context.loc.bitboxActionVerifyAddressTitle,
        onPressed: () {
          final state = context.read<ReceiveBloc>().state;

          if (state.wallet == null || state.bitcoinAddress == null) {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.receiveVerifyAddressError,
            );
            return;
          }

          final keyChainPath =
              state.bitcoinAddress!.keyChain == WalletAddressKeyChain.external
              ? "0"
              : "1";
          final derivationPath =
              "${state.wallet!.derivationPath}/$keyChainPath/${state.bitcoinAddress!.index}";
          context.pushNamed(
            BitBoxRoute.bitboxVerifyAddress.name,
            extra: BitBoxRouteParams(
              address: state.address,
              derivationPath: derivationPath,
              requestedDeviceType: state.wallet!.signerDevice,
              scriptType: state.wallet!.scriptType,
            ),
          );
        },
      ),
    );
  }
}
