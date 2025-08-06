import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class BuyDestinationInputFields extends StatefulWidget {
  const BuyDestinationInputFields({super.key});

  @override
  State<BuyDestinationInputFields> createState() =>
      _BuyDestinationInputFieldsState();
}

class _BuyDestinationInputFieldsState extends State<BuyDestinationInputFields> {
  late TextEditingController _bitcoinAddressInputController;

  @override
  void initState() {
    final bitcoinAddressInput =
        context.read<BuyBloc>().state.bitcoinAddressInput;
    _bitcoinAddressInputController = TextEditingController(
      text: bitcoinAddressInput,
    );
    _bitcoinAddressInputController.addListener(() {
      context.read<BuyBloc>().add(
        BuyEvent.bitcoinAddressInputChanged(
          _bitcoinAddressInputController.text,
        ),
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    _bitcoinAddressInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = context.select((BuyBloc bloc) => bloc.state.isStarted);
    final wallets = context.select((BuyBloc bloc) => bloc.state.wallets);
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    // TODO: Use labels from translations for these
    const externalBitcoinWalletLabel = 'External Bitcoin wallet';
    const secureBitcoinWalletLabel = 'Secure Bitcoin Wallet';
    const instantPaymentWalletLabel = 'Instant payment wallet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select wallet', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                alignment: Alignment.centerLeft,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                value: selectedWallet?.id,
                items: [
                  ...wallets.map((w) {
                    final label =
                        w.label ??
                        (w.isLiquid
                            ? instantPaymentWalletLabel
                            : secureBitcoinWalletLabel);
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(label, style: context.font.headlineSmall),
                    );
                  }),
                  DropdownMenuItem(
                    child: Text(
                      // To not show the external wallet label before the wallets
                      //  are loaded return an empty string if not started up.
                      !isStarted ? '' : externalBitcoinWalletLabel,
                      style: context.font.headlineSmall,
                    ),
                  ),
                ],
                onChanged: (value) {
                  final selectedWallet =
                      wallets.where((w) => w.id == value).firstOrNull;
                  context.read<BuyBloc>().add(
                    BuyEvent.selectedWalletChanged(selectedWallet),
                  );
                },
              ),
            ),
          ),
        ),
        // If no wallet is selected and all data has been loaded, no wallet may
        // have been available for some reason, so let the user enter a
        // bitcoin address manually.
        if (isStarted && selectedWallet == null) ...[
          const Gap(16.0),
          Text('Enter bitcoin address', style: context.font.bodyMedium),
          const Gap(4.0),
          SizedBox(
            height: 56,
            child: Material(
              elevation: 2,
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(2.0),
              child: Center(
                child: TextFormField(
                  controller: _bitcoinAddressInputController,
                  textAlignVertical: TextAlignVertical.center,
                  style: context.font.headlineSmall,
                  decoration: InputDecoration(
                    hintText: 'BC1QYL7J673H...6Y6ALV70M0',
                    hintStyle: context.font.headlineSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.paste, color: context.colour.secondary),
                      onPressed: () {
                        Clipboard.getData(Clipboard.kTextPlain).then((value) {
                          if (value?.text != null) {
                            _bitcoinAddressInputController.text = value!.text!;
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
