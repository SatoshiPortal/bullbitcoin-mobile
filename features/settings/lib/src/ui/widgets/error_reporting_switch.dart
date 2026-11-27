import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:settings/src/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
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
          final saved = await context
              .read<SettingsCubit>()
              .toggleErrorReporting(false);
          if (!context.mounted || !saved) return;
          BullSnackBar.show(
            context,
            message: context.loc.errorReportingRestartSnackbar,
          );
        }
      },
    );
  }
}
