import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/buy_payout_method_label.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDropdown, BullPickerItem, Gap, BullTypographyX;

class BuyDestinationInputFields extends StatefulWidget {
  const BuyDestinationInputFields({super.key});

  @override
  State<BuyDestinationInputFields> createState() =>
      _BuyDestinationInputFieldsState();
}

class _BuyDestinationInputFieldsState extends State<BuyDestinationInputFields> {
  String _addressInput = '';

  @override
  void initState() {
    super.initState();
    _addressInput = context.read<BuyBloc>().state.bitcoinAddressInput;
  }

  @override
  Widget build(BuildContext context) {
    final isStarted = context.select((BuyBloc bloc) => bloc.state.isStarted);
    final wallets = context.select((BuyBloc bloc) => bloc.state.wallets);
    final selectedWallet = context.select(
      (BuyBloc bloc) => bloc.state.selectedWallet,
    );
    final externalBitcoinWalletLabel = context.loc.buyConfirmExternalWallet;
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(context.loc.buySelectWallet, style: context.bullType.body),
        const Gap(4.0),
        BullDropdown<String?>(
          value: selectedWallet?.id,
          items: [
            // Default wallets carry a network suffix here so the user can tell
            // the two apart; externally added wallets keep their custom name
            // untouched.
            for (final w in wallets)
              BullPickerItem<String?>(
                value: w.id,
                label: w.isDefault
                    ? '${w.displayLabel(context)} '
                          '(${buyPayoutMethodLabel(context, isLiquid: w.network.isLiquid)})'
                    : w.displayLabel(context),
              ),
            BullPickerItem<String?>(
              value: null,
              label: !isStarted ? '' : externalBitcoinWalletLabel,
            ),
          ],
          onChanged: (value) {
            final selectedWallet = wallets
                .where((w) => w.id == value)
                .firstOrNull;
            context.read<BuyBloc>().add(
              BuyEvent.selectedWalletChanged(selectedWallet),
            );
          },
        ),
        // If no wallet is selected and all data has been loaded, no wallet may
        // have been available for some reason, so let the user enter a
        // bitcoin address manually.
        if (isStarted && selectedWallet == null) ...[
          const Gap(16.0),
          PaymentDestinationField(
            value: _addressInput,
            label: context.loc.buyEnterBitcoinAddress,
            hint: context.loc.buyBitcoinAddressHint,
            acceptedTypes: const {PaymentDestinationType.bitcoin},
            onChanged: (value) {
              setState(() => _addressInput = value);
              context.read<BuyBloc>().add(
                const BuyEvent.bitcoinAddressInputChanged(''),
              );
            },
            onValidated: (destination) => context.read<BuyBloc>().add(
              BuyEvent.bitcoinAddressInputChanged(destination?.address ?? ''),
            ),
          ),
        ],
      ],
    );
  }
}
