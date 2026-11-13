import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Development switch: show the App Store vocabulary on any platform.
class ForceAppStoreWordingSwitch extends StatelessWidget {
  const ForceAppStoreWordingSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final forced = context.select(
      (SettingsCubit cubit) => cubit.state.forceAppStoreWording,
    );

    return Switch(
      value: forced,
      onChanged: (value) =>
          context.read<SettingsCubit>().setForceAppStoreWording(value),
    );
  }
}
