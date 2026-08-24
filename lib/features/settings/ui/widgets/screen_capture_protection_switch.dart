import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScreenCaptureProtectionSwitch extends StatelessWidget {
  const ScreenCaptureProtectionSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context
        .watch<SettingsCubit>()
        .state
        .screenCaptureProtectionEnabled;

    return Switch(
      value: isEnabled,
      onChanged: (value) async {
        // Await the toggle so the message follows the actual state change: for
        // a security toggle we must not claim protection is off before it is.
        await context.read<SettingsCubit>().toggleScreenCaptureProtection(
          value,
        );
        if (!value && context.mounted) {
          SnackBarUtils.showSnackBar(
            context,
            context.loc.settingsScreenPrivacyDisabledMessage,
          );
        }
      },
    );
  }
}
