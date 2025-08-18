import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 42),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                qrData.isNotEmpty
                    ? QrImageView(data: qrData)
                    : const LoadingBoxContent(height: 200),
          ),
        ),
        if (isPayjoinAvailable) ...[
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BBText(
              'Payjoin activated',
              style: context.font.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const Gap(20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText(
                isLightning ? 'Lightning invoice' : 'Address',
                style: context.font.bodyMedium,
              ),
              const Gap(6),
              // TODO: We should probably just make a specific widget for the
              //  address and invoice instead of using CopyInput.
              CopyInput(
                text: addressOrInvoiceOnly,
                clipboardText: clipboardData,
                overflow: TextOverflow.ellipsis,
                canShowValueModal: true,
                modalTitle: isLightning ? 'Lightning invoice' : 'Address',
                modalContent:
                    isLightning
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
        ),
      ],
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
          border: Border.all(color: context.colour.surface),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          'Amount',
                          style: context.font.labelSmall,
                          color: context.colour.outline,
                        ),
                        const Gap(4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          color: context.colour.outline,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final receiveType =
                          context.read<ReceiveBloc>().state.type;
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
            Container(color: context.colour.surface, height: 1),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          'Note',
                          style: context.font.labelSmall,
                          color: context.colour.outline,
                        ),
                        const Gap(4),
                        BBText(
                          note.isNotEmpty ? note : 'Enter here...',
                          style: context.font.bodyMedium,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
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

    return AnimatedContainer(
      duration: 300.ms,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: context.colour.surface),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            color: context.colour.surfaceContainer,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(12),
          const ReceiveLnSwapID(),
          const Gap(12),

          Container(color: context.colour.surface, height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  'Amount',
                  style: context.font.bodySmall,
                  color: context.colour.surfaceContainer,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      amountSat ?? 0,
                      showFiat: false,
                      style: context.font.bodyMedium,
                    ),
                    BBText(
                      '~$amountEquivalent',
                      style: context.font.labelSmall,
                      color: context.colour.surfaceContainer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (note.isNotEmpty) ...[
            Container(color: context.colour.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Row(
                children: [
                  BBText(
                    'Note',
                    style: context.font.labelSmall,
                    color: context.colour.outline,
                  ),
                  const Gap(24),
                  Expanded(
                    child: BBText(
                      note.isNotEmpty ? note : '',
                      style: context.font.bodyMedium,
                      maxLines: 5,
                      textAlign: TextAlign.end,
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
            'Swap ID',
            style: context.font.bodySmall,
            color: context.colour.surfaceContainer,
          ),
          const Spacer(),
          BBText(
            swap.id,
            style: context.font.bodyLarge,
            textAlign: TextAlign.end,
          ),
          const Gap(4),
          InkWell(
            child: Icon(Icons.copy, color: context.colour.primary, size: 16),
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
            color: context.colour.surfaceContainer,
          ),
          const Spacer(),
          CurrencyText(
            amt,
            showFiat: false,
            style: context.font.bodySmall,
            color: context.colour.surfaceContainer,
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
        Container(color: context.colour.surface, height: 1),
        const Gap(8),
        InkWell(
          splashColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          onTap: () {
            setState(() {
              expanded = !expanded;
            });
          },
          child: Row(
            children: [
              BBText(
                'Total Fee',
                style: context.font.bodySmall,
                color: context.colour.surfaceContainer,
              ),
              const Spacer(),
              CurrencyText(
                swap.fees?.totalFees(null) ?? 0,
                showFiat: false,
                style: context.font.bodyLarge,
                color: context.colour.outlineVariant,
              ),
              const Gap(4),
              Icon(
                expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: context.colour.primary,
              ),
            ],
          ),
        ),
        const Gap(12),
        if (expanded) ...[
          Container(color: context.colour.surface, height: 1),
          _feeRow(
            context,
            'Network Fee',
            swap.fees!.lockupFee! + swap.fees!.claimFee!,
          ),
          _feeRow(context, 'Boltz Swap Fee', swap.fees?.boltzFee ?? 0),
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
            'Copy or scan address only',
            style: context.font.headlineSmall,
          ),
          const Spacer(),
          Switch(
            value: context.select<ReceiveBloc, bool>(
              (bloc) =>
                  bloc.state.type == ReceiveType.bitcoin &&
                  bloc.state.isAddressOnly,
            ),
            onChanged:
                (addressOnly) => context.read<ReceiveBloc>().add(
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
        label: 'New address',
        onPressed: () {
          context.read<ReceiveBloc>().add(
            const ReceiveEvent.receiveNewAddressGenerated(),
          );
        },
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
