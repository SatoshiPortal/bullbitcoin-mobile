import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AdvancedOptionsPopUp extends StatelessWidget {
  const AdvancedOptionsPopUp({super.key});

  static Future openPopup(BuildContext context) {
    final send = context.read<SendCubit>();
    final wallet = context.read<WalletBloc>();
    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: send),
          BlocProvider.value(value: wallet),
        ],
        child: const AdvancedOptionsPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final sendAll = context.select((SendCubit x) => x.state.sendAllCoin);
    final isLn = context.select((SendCubit x) => x.state.isLnInvoice());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // const Gap(32),
          const BBHeader.popUpCenteredText(
            text: 'ADVANCED OPTIONS',
            isLeft: true,
          ),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     const BBText.body(
          //       'Advanced Options',
          //       // style: TextStyle(
          //       //   fontSize: 20,
          //       //   fontWeight: FontWeight.bold,
          //       // ),
          //     ),
          //     const Spacer(),
          //     IconButton(
          //       onPressed: () {
          //         context.pop();
          //       },
          //       icon: const Icon(Icons.close),
          //     ),
          //   ],
          // ),
          const Gap(16),

          if (!isLn) ...[
            const SendAllOption(),
            const Gap(8),
            const EnableRBFOption(),
            const Gap(8),
          ],
          // if (!sendAll)
          //   CenterLeft(
          //     child: BBButton.text(
          //       // style: TextButton.styleFrom(padding: EdgeInsets.zero),
          //       onPressed: () {
          //         AddressSelectionPopUp.openPopup(context);
          //       },
          //       label: 'Select coins manually',
          //       // child: const BBText.body('Manual coin selection'),
          //     ),
          //   ),
          // const EnableRBFOption(),

          const Gap(40),
          Center(
            child: SizedBox(
              width: 250,
              child: BBButton.big(
                // style: Buttons.outlinedButtonBorderRed,
                onPressed: () {
                  context.pop();
                },
                label: 'Confirm',
                // child: const BBText.body('Done'),
              ),
            ),
          ),
          const Gap(80),
        ],
      ),
    );
  }
}

class SendAllOption extends StatelessWidget {
  const SendAllOption({super.key});

  @override
  Widget build(BuildContext context) {
    final sendAll = context.select((SendCubit x) => x.state.sendAllCoin);
    return Row(
      children: [
        const BBText.body('Send entire wallet balance'),
        const Spacer(),
        BBSwitch(
          value: sendAll,
          onChanged: (e) {
            context.read<SendCubit>().sendAllCoin(e);
          },
        ),
      ],
    );
  }
}

class EnableRBFOption extends StatelessWidget {
  const EnableRBFOption({super.key});

  @override
  Widget build(BuildContext context) {
    final disableRBF = context.select((SendCubit x) => x.state.disableRBF);
    return Row(
      children: [
        const BBText.body('Turn off RBF'),
        const Spacer(),
        BBSwitch(
          value: disableRBF,
          onChanged: (e) {
            context.read<SendCubit>().disableRBF(e);
          },
        ),
      ],
    );
  }
}

class AddressSelectionPopUp extends StatelessWidget {
  const AddressSelectionPopUp();

  static Future openPopup(
    BuildContext context,
  ) {
    final send = context.read<SendCubit>();
    final wallet = context.read<WalletBloc>();
    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: send),
          BlocProvider.value(value: wallet),
        ],
        child: const AddressSelectionPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final utxos = context.select((WalletBloc _) => _.state.wallet!.utxos);
    final amount = context.select((CurrencyCubit _) => _.state.amount);

    final amt = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(amount),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // const Gap(32),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     const BBText.body(
          //       'Select Addresses',
          //       // style: TextStyle(
          //       //   fontSize: 20,
          //       //   fontWeight: FontWeight.bold,
          //       // ),
          //     ),
          //     const Spacer(),
          //     IconButton(
          //       onPressed: () {
          //         context.pop();
          //       },
          //       icon: const Icon(Icons.close),
          //     ),
          //   ],
          // ),
          const Gap(32),
          const _SelectedAddressesTotal(),
          if (amount > 0) ...[
            const Gap(8),
            BBText.body(
              'Amount requested: $amt',
              // style: const TextStyle(fontSize: 12),
            ),
          ],
          const Gap(24),
          if (utxos.isEmpty) const BBText.body('No utxos available'),
          for (final utxo in utxos) ...[
            AdvancedOptionAdress(utxo: utxo),
            const Gap(16),
          ],
          const Gap(40),
          Center(
            child: SizedBox(
              width: 200,
              child: BBButton.big(
                // style: Buttons.outlinedButtonBorderRed,
                onPressed: () {
                  context.pop();
                },
                label: 'Done',
                // child: const BBText.body('Done'),
              ),
            ),
          ),
          const Gap(80),
        ],
      ),
    );
  }
}

class AdvancedOptionAdress extends StatelessWidget {
  const AdvancedOptionAdress({super.key, required this.utxo});

  final UTXO utxo;

  @override
  Widget build(BuildContext context) {
    final isFrozen = utxo.spendable == false;

    final isSelected = context.select(
      (SendCubit x) => x.state.utxoIsSelected(utxo),
    );

    final balance = utxo.value;

    final addressType = utxo.address.getKindString();

    final amt = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(balance),
    );

    final label = utxo.label;

    final addessStr = utxo.address.toShortString() +
        (utxo.address.label != null ? utxo.address.label! : '');

    return AnimatedOpacity(
      opacity: isFrozen ? 0.5 : 1,
      duration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () {
          if (!isFrozen) context.read<SendCubit>().utxoSelected(utxo);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? context.colour.primary
                  : context.colour.onBackground,
              width: isSelected ? 3 : 3,
            ),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText.titleLarge(amt, isBold: true, textAlign: TextAlign.center),
              Row(
                children: [
                  const BBText.body('Address: '),
                  BBText.body(
                    addessStr,
                    isBold: true,
                  ),
                ],
              ),
              const Gap(4),
              Row(
                children: [
                  const BBText.body('Type: '),
                  BBText.body(addressType, isBold: true),
                ],
              ),
              if (label.isNotEmpty) ...[
                const Gap(4),
                Row(
                  children: [
                    const BBText.body(
                      'Label: ',
                      // style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    BBText.body(label, isBold: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedAddressesTotal extends StatelessWidget {
  const _SelectedAddressesTotal();

  @override
  Widget build(BuildContext context) {
    final total =
        context.select((SendCubit x) => x.state.calculateTotalSelected());
    final amt = context.select(
      (CurrencyCubit x) => x.state.getAmountInUnits(total),
    );

    return BBText.body(
      'Amount Selected\n$amt',
      textAlign: TextAlign.center,
      isBold: true,
    );
  }
}
