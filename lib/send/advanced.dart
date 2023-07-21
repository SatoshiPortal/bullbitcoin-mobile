import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class AdvancedOptionsPopUp extends StatelessWidget {
  const AdvancedOptionsPopUp({super.key});

  static Future openPopup(BuildContext context) {
    final send = context.read<SendCubit>();
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: send,
        child: const AdvancedOptionsPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopUpBorder(
      child: Padding(
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
            const Gap(32),
            CenterLeft(
              child: BBButton.text(
                // style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () {
                  AddressSelectionPopUp.openPopup(context);
                },
                label: 'Manual coin selection',
                // child: const BBText.body('Manual coin selection'),
              ),
            ),
            // const EnableRBFOption(),
            const Gap(8),
            const SendAllOption(),
            const Gap(40),
            Center(
              child: SizedBox(
                width: 250,
                child: BBButton.bigRed(
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
        const BBText.body('Send full wallet balance'),
        const Spacer(),
        Switch(
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
    final enableRBF = context.select((SendCubit x) => x.state.enableRBF);
    return Row(
      children: [
        const BBText.body('Replace-by-fee (RBF)'),
        const Spacer(),
        Switch(
          value: enableRBF,
          onChanged: (e) {
            context.read<SendCubit>().enableRBF(e);
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
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: send,
        child: const AddressSelectionPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addresses =
        context.select((SendCubit x) => x.walletBloc.state.wallet!.addressesWithBalance());
    final amount = context.select((SendCubit x) => x.state.amount);

    final amt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(amount),
    );

    return PopUpBorder(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BBText.body(
                  'Select Addresses',
                  // style: TextStyle(
                  //   fontSize: 20,
                  //   fontWeight: FontWeight.bold,
                  // ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    context.pop();
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Gap(4),
            BBText.body(
              'Amount required: $amt',
              // style: const TextStyle(fontSize: 12),
            ),
            const Gap(32),
            if (addresses.isEmpty) const BBText.body('No addresses available'),
            for (final address in addresses) ...[
              AdvancedOptionAdress(address: address),
              const Gap(16),
            ],
            const Gap(24),
            const _SelectedAddressesTotal(),
            const Gap(40),
            Center(
              child: SizedBox(
                width: 200,
                child: BBButton.bigRed(
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
      ),
    );
  }
}

class AdvancedOptionAdress extends StatelessWidget {
  const AdvancedOptionAdress({super.key, required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final isFrozen = address.unspendable;

    final isSelected = context.select(
      (SendCubit x) => x.state.addressIsSelected(address),
    );

    final balance = address.calculateBalance();

    final amt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(balance),
    );

    final label = address.label;

    final addessStr = address.address.substring(0, 5) +
        '...' +
        address.address.substring(address.address.length - 5);

    return AnimatedOpacity(
      opacity: isFrozen ? 0.5 : 1,
      duration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () {
          if (!isFrozen) context.read<SendCubit>().utxoAddressSelected(address);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? context.colour.primary : context.colour.onBackground,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText.body(addessStr),
              const Gap(4),
              Row(
                children: [
                  const BBText.body(
                    'Amount: ',
                    // style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  BBText.body(amt),
                ],
              ),
              if (label != null && label.isNotEmpty) ...[
                const Gap(4),
                Row(
                  children: [
                    const BBText.body(
                      'Label: ',
                      // style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    BBText.body(label),
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
    final total = context.select((SendCubit x) => x.state.calculateTotalSelected());
    final amt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(total),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: BBText.body('Total amount selected :\n$amt'),
    );
  }
}
