import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class PinSettingsScreen extends StatelessWidget {
  const PinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PinCodeSettingBloc>();
    final isPinCodeSet = context.watch<PinCodeSettingBloc>().state.isPinCodeSet;

    return Scaffold(
      appBar: AppBar(title: const Text('Pin Settings')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            BBButton.big(
              label: 'Create',
              onPressed: () => bloc.add(const PinCodeCreate()),
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
            const Gap(16),
            if (isPinCodeSet)
              BBButton.big(
                label: 'Delete',
                onPressed: () => bloc.add(const PinCodeDelete()),
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
