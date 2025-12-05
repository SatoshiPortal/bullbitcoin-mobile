import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HideExchangeFeaturesSwitch extends StatelessWidget {
  const HideExchangeFeaturesSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final hideExchangeFeatures =
        context.watch<SettingsCubit>().state.hideExchangeFeatures ?? false;

    return Switch(
      value: hideExchangeFeatures,
      onChanged: (value) {
        context.read<SettingsCubit>().toggleHideExchangeFeatures(value);
      },
    );
  }
}
