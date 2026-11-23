import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
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
      onChanged: (value) {
        if (value) {
          ErrorReportingConfirmationBottomSheet.show(context);
        } else {
          context.read<SettingsCubit>().toggleErrorReporting(false);
        }
        BullSnackBar.show(
          context,
          message: context.loc.errorReportingRestartSnackbar,
        );
      },
    );
  }
}
