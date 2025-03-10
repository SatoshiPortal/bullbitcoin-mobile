import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LabelInputField extends StatelessWidget {
  const LabelInputField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: WidgetStyles.inputDecoration(
        context,
        'Label your wallet',
      ),
      onChanged: (value) {
        context.read<RecoverWalletBloc>().add(
              RecoverWalletLabelChanged(value),
            );
      },
    );
  }
}
