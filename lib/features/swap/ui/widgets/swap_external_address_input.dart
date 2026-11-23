import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/swap/presentation/swap_failure_l10n.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapExternalAddressInput extends StatefulWidget {
  const SwapExternalAddressInput({super.key});

  @override
  State<SwapExternalAddressInput> createState() =>
      _SwapExternalAddressInputState();
}

class _SwapExternalAddressInputState extends State<SwapExternalAddressInput> {
  String? _rawInput;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransferBloc>().state;
    return PaymentDestinationField(
      value: _rawInput ?? state.externalAddress,
      label: context.loc.swapToLabel,
      hint: context.loc.swapExternalAddressHint,
      acceptedTypes: {
        state.fromWallet?.isLiquid == true
            ? PaymentDestinationType.bitcoin
            : PaymentDestinationType.liquid,
      },
      error: state.externalAddressError?.toTranslated(context),
      onChanged: (value) {
        setState(() => _rawInput = value);
        context.read<TransferBloc>().add(
          TransferEvent.externalAddressChanged(value),
        );
      },
    );
  }
}
