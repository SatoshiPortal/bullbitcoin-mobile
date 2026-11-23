import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/presentation/swap_failure_l10n.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:address_view/payment_destination.dart';
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
      label: context.swapCopyForLocale.swapToLabel,
      hint: context.swapCopyForLocale.swapExternalAddressHint,
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
