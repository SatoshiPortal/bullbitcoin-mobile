import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/ledger/ui/screens/ledger_action_screen.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_enter_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiveQrPage extends StatelessWidget {
  const ReceiveQrPage({super.key, this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final isBitcoin = context.select(
      (ReceiveBloc bloc) => bloc.state.type == ReceiveType.bitcoin,
    );
    final isLightning = context.select(
      (ReceiveBloc bloc) => bloc.state.type == ReceiveType.lightning,
    );
    final isLedger = context.select(
      (ReceiveBloc bloc) => bloc.state.wallet?.signerDevice?.isLedger ?? false,
    );
    final isBitBox = context.select(
      (ReceiveBloc bloc) => bloc.state.wallet?.signerDevice?.isBitBox ?? false,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          // const Gap(10),
          // const ReceiveNetworkSelection(),
          const Gap(16),
          const ReceiveQRDetails(),
          const Gap(10),
          ReceiveInfoDetails(wallet: wallet),
          const Gap(16),
          if (isBitcoin)
            // The switch to only copy/scan the address is only for Bitcoin since
            // the other networks don't have payjoin bip21 uri's
            const Column(children: [ReceiveCopyAddress(), Gap(10)]),
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
    final isPayjoinAvailable = context.select(
      (ReceiveBloc bloc) => bloc.state.isPayjoinAvailable,
    );
    final selectedWallet = context.watch<ReceiveBloc>().state.wallet;
    final wallets = context.select((ReceiveBloc bloc) => bloc.state.wallets);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (wallets.length > 1 &&
              isBitcoin &&
              selectedWallet != null &&
              selectedWallet.isBitcoin)
            ColoredBox(
              color: context.appColors.onSecondary,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
            ),
          const Gap(20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
              decoration: BoxDecoration(
                color: context.appColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: qrData.isNotEmpty
                  ? QrImageView(
                      data: qrData,
                      // ignore: deprecated_member_use
                      foregroundColor: context.appColors.secondary,
                    )
                  : const LoadingBoxContent(height: 200),
            ),
          ),
          if (isPayjoinAvailable) ...[
            const Gap(16),
            BBText(
              context.loc.receivePayjoinActivated,
              style: context.font.bodyLarge,
              textAlign: .center,
            ),
          ],
          const Gap(20),
          Column(
            crossAxisAlignment: .stretch,
            children: [
              BBText(
                isLightning
                    ? context.loc.receiveLightningInvoice
                    : context.loc.receiveAddress,
                style: context.font.bodyMedium,
                color: context.appColors.secondary,
              ),
              const Gap(6),
              // TODO: We should probably just make a specific widget for the
              //  address and invoice instead of using CopyInput.
              CopyInput(
                text: addressOrInvoiceOnly,
                clipboardText: clipboardData,
                overflow: .ellipsis,
                canShowValueModal: true,
                modalTitle: isLightning
                    ? context.loc.receiveLightningInvoice
                    : context.loc.receiveAddress,
                modalContent: isLightning
                    ? addressOrInvoiceOnly
                    : addressOrInvoiceOnly
                          .replaceAllMapped(
                            RegExp('.{1,4}'),
                            (match) => '${match.group(0)} ',
                          )
                          .trim(),
              ),
            ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: context.appColors.surface),
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 12,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BBText(
                          context.loc.receiveAmount,
                          style: context.font.labelSmall,
                          color: context.appColors.onSurfaceVariant,
                        ),
                        const Gap(4),
                        Row(
                          mainAxisAlignment: .spaceBetween,
                          children: [
                            Expanded(
                              child: CurrencyText(
                                amountSat ?? 0,
                                showFiat: false,
                                style: context.font.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        BBText(
                          '~$amountEquivalent',
                          style: context.font.bodyLarge,
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final receiveType = context
                          .read<ReceiveBloc>()
                          .state
                          .type;
                      switch (receiveType) {
                        case ReceiveType.lightning:
                          context.pushNamed(
                            ReceiveRoute.lightningAmount.name,
                            extra: wallet,
                          );
                        case ReceiveType.liquid:
                          context.pushNamed(
                            ReceiveRoute.liquidAmount.name,
                            extra: wallet,
                          );
                        case ReceiveType.bitcoin:
                          context.pushNamed(
                            ReceiveRoute.bitcoinAmount.name,
                            extra: wallet,
                          );
                        case _:
                          return;
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
            Container(color: context.appColors.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 10,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BBText(
                          context.loc.receiveNote,
                          style: context.font.labelSmall,
                          color: context.appColors.onSurfaceVariant,
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
                  if (!isLn)
                    IconButton(
                      onPressed: () async {
                        await ReceiveEnterNote.showBottomSheet(context);
                      },
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      icon: const Icon(Icons.edit),
                    ),
                ],
              ),
            ),
          ],
        ),
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

class ReceiveCopyAddress extends StatelessWidget {
  const ReceiveCopyAddress({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16 + 12),
      child: Row(
        children: [
          BBText(
            context.loc.receiveCopyAddressOnly,
            style: context.font.headlineSmall,
          ),
          const Spacer(),
          Switch(
            value: context.select<ReceiveBloc, bool>(
              (bloc) =>
                  bloc.state.type == ReceiveType.bitcoin &&
                  bloc.state.isAddressOnly,
            ),
            onChanged: (addressOnly) => context.read<ReceiveBloc>().add(
              ReceiveEvent.receiveAddressOnlyToggled(addressOnly),
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiveNewAddressButton extends StatelessWidget {
  const ReceiveNewAddressButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
      padding: const EdgeInsets.all(16.0),
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
      padding: const EdgeInsets.all(16.0),
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
