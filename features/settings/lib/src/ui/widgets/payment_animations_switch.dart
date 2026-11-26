import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PaymentAnimationsSwitch extends StatelessWidget {
  const PaymentAnimationsSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context
        .watch<SettingsCubit>()
        .state
        .showPaymentAnimations;

    return Switch(
      value: isEnabled,
      onChanged: (value) =>
          context.read<SettingsCubit>().toggleShowPaymentAnimations(value),
    );
  }
}
