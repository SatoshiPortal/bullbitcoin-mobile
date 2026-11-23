import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
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
          BullSnackBar.show(
            context,
            message: context.loc.settingsScreenPrivacyDisabledMessage,
          );
        }
      },
    );
  }
}
