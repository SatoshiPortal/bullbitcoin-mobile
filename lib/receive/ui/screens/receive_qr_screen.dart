import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/inputs/copy_input.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/components/toggle/switch.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isBitcoin = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state is BitcoinReceiveState,
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
          const ReceiveInfoDetails(),
          const Gap(16),
          if (isBitcoin)
            // The switch to only copy/scan the address is only for Bitcoin since
            // the other networks don't have payjoin bip21 uri's
            const Column(
              children: [
                ReceiveCopyAddress(),
                Gap(10),
              ],
            ),
          const ReceiveNewAddressButton(),
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
    final isLightning = context.select<ReceiveBloc, bool>(
      (bloc) => bloc.state is LightningReceiveState,
    );
    final qrData = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.qrData,
    );
    final addressOrInvoiceOnly = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.addressOrInvoiceOnly,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 42),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(data: qrData),
          ),
        ),
        const Gap(14),
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
              CopyInput(
                text: addressOrInvoiceOnly,
                clipboardText: qrData,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceiveInfoDetails extends StatelessWidget {
  const ReceiveInfoDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final bitcoinAmount = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedConfirmedAmountBitcoin,
    );
    final amountEquivalent = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.formattedConfirmedAmountFiat,
    );
    final note = context.select<ReceiveBloc, String>(
      (bloc) => bloc.state.note,
    );

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        'Amount',
                        style: context.font.labelSmall,
                        color: context.colour.outline,
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          BBText(
                            bitcoinAmount,
                            style: context.font.bodyMedium,
                          ),
                          const Gap(12),
                          BBText(
                            '~$amountEquivalent',
                            style: context.font.bodyLarge,
                            color: context.colour.outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      final state = context.read<ReceiveBloc>().state;
                      switch (state) {
                        case LightningReceiveState _:
                          context.push(
                            '${ReceiveRoute.receiveLightning.path}/${ReceiveRoute.amount.path}',
                          );
                        case LiquidReceiveState _:
                          context.push(
                            '${ReceiveRoute.receiveLiquid.path}/${ReceiveRoute.amount.path}',
                          );
                        case BitcoinReceiveState _:
                          context.push(
                            '${ReceiveRoute.receiveBitcoin.path}/${ReceiveRoute.amount.path}',
                          );
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
                  Column(
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
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
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
          BBSwitch(
            value: context.select<ReceiveBloc, bool>(
              (bloc) =>
                  bloc.state is BitcoinReceiveState &&
                  (bloc.state as BitcoinReceiveState).isAddressOnly,
            ),
            onChanged: (addressOnly) => context
                .read<ReceiveBloc>()
                .add(ReceiveEvent.receiveAddressOnlyToggled(addressOnly)),
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
