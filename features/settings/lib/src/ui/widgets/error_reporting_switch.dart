import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:settings/src/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
import 'package:settings/src/ui/widgets/settings_restart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ErrorReportingSwitch extends StatelessWidget {
  const ErrorReportingSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context
        .watch<SettingsCubit>()
        .state
        .isErrorReportingEnabled;

    return Switch(
      value: isEnabled,
      onChanged: (value) async {
        if (value) {
          await ErrorReportingConfirmationBottomSheet.show(context);
        } else {
          final navigator = Navigator.of(context, rootNavigator: true);
          final message = context.loc.errorReportingRestartSnackbar;
          final saved = await context
              .read<SettingsCubit>()
              .toggleErrorReporting(false);
          if (!saved || !navigator.mounted) return;
          await showSettingsRestartDialog(navigator.context, message: message);
        }
      },
    );
  }
}
