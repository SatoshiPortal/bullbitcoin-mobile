import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/widgets/invoice_viewer.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/labels/ui/label_entry_bottom_sheet.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_enter_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';

class ReceiveQrPage extends StatelessWidget {
  const ReceiveQrPage({super.key, this.wallet});

  final Wallet? wallet;

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

    final gap = Device.screen.height * 0.02;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          // const Gap(10),
          // const ReceiveNetworkSelection(),
          Gap(gap),
          const ReceiveQRDetails(),
          Gap(gap),
          ReceiveInfoDetails(wallet: wallet),
          Gap(gap),
          if (isLedger) const Column(children: [VerifyAddressOnLedgerButton()]),
          if (isBitBox) const Column(children: [VerifyAddressOnBitBoxButton()]),
          if (!isLightning) const ReceiveNewAddressButton(),
          const Gap(40),
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
            BorderedTappableTile(
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
                      style: context.font.headlineSmall?.copyWith(
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
          Center(child: QrDisplayWidget(data: qrData)),
          const _PayjoinSwitch(),
          Gap(gap),
          BorderedTappableTile(
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
                      BBText(
                        isLightning
                            ? context.loc.receiveLightningInvoice
                            : context.loc.receiveAddress,
                        style: context.font.bodyLarge,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      isLightning
                          ? InvoiceViewer(
                              addressOrInvoiceOnly,
                              clipboardText: clipboardData,
                              style: context.font.bodyLarge,
                              color: context.appColors.secondary,
                            )
                          : AddressViewer(
                              addressOrInvoiceOnly,
                              clipboardText: clipboardData,
                              style: context.font.bodyLarge,
                              color: context.appColors.secondary,
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiveInfoDetails extends StatelessWidget {
  const ReceiveInfoDetails({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final amountSat = context.select(
      (ReceiveBloc bloc) => bloc.state.confirmedAmountSat,
    );
    final amountEquivalent = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedConfirmedAmountFiat,
    );
    final note = context.select<ReceiveBloc, String>((bloc) => bloc.state.note);

    final isLn = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state.type == ReceiveType.lightning,
    );

    if (isLn) return const ReceiveLnInfoDetails();

    final gap = Device.screen.height * 0.02;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BorderedTappableTile(
            onTap: () => ReceiveEnterAmount.showBottomSheet(context),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BBText(
                        context.loc.receiveAmount,
                        style: context.font.bodyLarge,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      CurrencyText(
                        amountSat ?? 0,
                        showFiat: false,
                        style: context.font.bodyMedium,
                      ),
                      BBText(
                        '~$amountEquivalent',
                        style: context.font.bodyLarge,
                        color: context.appColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap(gap),
          BorderedTappableTile(
            onTap: () async {
              final bloc = context.read<ReceiveBloc>();
              final saved = await LabelEntryBottomSheet.note(
                context,
                title: context.loc.receiveNote,
                initialValue: bloc.state.note,
                hint: context.loc.receiveNotePlaceholder,
                suggestionsFuture: bloc.fetchDistinctLabels(),
              );
              if (saved == null) return;
              bloc.add(ReceiveNoteChanged(saved));
              bloc.add(const ReceiveNoteSaved());
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BBText(
                        '${context.loc.receiveNote} (optional)',
                        style: context.font.bodyLarge,
                        color: context.appColors.secondary,
                      ),
                      const Gap(4),
                      BBText(
                        note.isNotEmpty ? note : context.loc.receiveEnterHere,
                        style: context.font.bodyMedium,
                        maxLines: 4,
                        overflow: .ellipsis,
                      ),
                    ],
                  ),
                ),
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

    return AnimatedContainer(
      duration: 300.ms,
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
                BBText(
                  context.loc.receiveAmount,
                  style: context.font.bodySmall,
                  color: context.appColors.onSurfaceVariant,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: .end,
                  children: [
                    CurrencyText(
                      amountSat ?? 0,
                      showFiat: false,
                      style: context.font.bodyMedium,
                      color: context.appColors.secondary,
                    ),
                    BBText(
                      '~$amountEquivalent',
                      style: context.font.labelSmall,
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (swap?.receieveAmount != null) ...[
            Container(color: context.appColors.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  BBText(
                    context.loc.receiveReceiveAmount,
                    style: context.font.bodySmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const Spacer(),
                  CurrencyText(
                    swap!.receieveAmount!,
                    showFiat: false,
                    style: context.font.bodyMedium,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          ],
          if (note.isNotEmpty) ...[
            Container(color: context.appColors.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Row(
                children: [
                  BBText(
                    context.loc.receiveNote,
                    style: context.font.labelSmall,
                    color: context.appColors.onSurfaceVariant,
                  ),
                  const Gap(24),
                  Expanded(
                    child: BBText(
                      note.isNotEmpty ? note : '',
                      style: context.font.bodyMedium,
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
    if (swap == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BBText(
            context.loc.receiveSwapId,
            style: context.font.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          BBText(
            swap.id,
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: .end,
          ),
          const Gap(4),
          InkWell(
            child: Icon(Icons.copy, color: context.appColors.primary, size: 16),
            onTap: () {
              Clipboard.setData(ClipboardData(text: swap.id));
            },
          ),
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
          BBText(
            label,
            style: context.font.bodySmall,
            color: context.appColors.onSurfaceVariant,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final swap = context.select((ReceiveBloc bloc) => bloc.state.getSwap);
    if (swap == null) return const SizedBox.shrink();

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
              BBText(
                context.loc.receiveTotalFee,
                style: context.font.bodySmall,
                color: context.appColors.onSurfaceVariant,
              ),
              const Spacer(),
              CurrencyText(
                swap.fees?.totalFees(null) ?? 0,
                showFiat: false,
                style: context.font.bodyLarge,
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
            child: BBText(
              context.loc.receiveFeeExplanation,
              style: context.font.labelSmall,
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

class _PayjoinSwitch extends StatelessWidget {
  const _PayjoinSwitch();

  @override
  Widget build(BuildContext context) {
    final canUsePayjoin = context.select<ReceiveBloc, bool>(
      (bloc) =>
          bloc.state.type == ReceiveType.bitcoin &&
          (bloc.state.wallet?.signsLocally ?? false),
    );
    if (!canUsePayjoin) return const SizedBox.shrink();

    final hasUtxos = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state.hasUtxos,
    );
    final isAddressOnly = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state.isAddressOnly,
    );
    final isOn = !isAddressOnly && hasUtxos;

    void toggle() {
      final turnOn = !isOn;
      if (turnOn && !hasUtxos) {
        SnackBarUtils.showSnackBar(
          context,
          context.loc.receivePayjoinNoUtxos,
        );
        return;
      }
      context.read<ReceiveBloc>().add(
        ReceiveEvent.receiveAddressOnlyToggled(!turnOn),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: toggle,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: context.appColors.onSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.secondaryFixedDim),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: BBText(
                      context.loc.receivePayjoinActivated,
                      style: context.font.bodyLarge,
                      color: context.appColors.secondary,
                    ),
                  ),
                  AbsorbPointer(
                    child: Switch(value: isOn, onChanged: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiveNewAddressButton extends StatelessWidget {
  const ReceiveNewAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBButton.big(
        label: context.loc.receiveNewAddress,
        onPressed: () {
          context.read<ReceiveBloc>().add(
            const ReceiveEvent.receiveNewAddressGenerated(),
          );
        },
        bgColor: context.appColors.secondary,
        textColor: context.appColors.onSecondary,
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
      child: BBButton.big(
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
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        outlined: true,
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
      child: BBButton.big(
        label: 'Verify Address on BitBox',
        onPressed: () {
          final state = context.read<ReceiveBloc>().state;

          if (state.wallet == null || state.bitcoinAddress == null) {
            SnackBarUtils.showSnackBar(
              context,
              'Unable to verify address: Missing wallet or address information',
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
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        outlined: true,
      ),
    );
  }
}
