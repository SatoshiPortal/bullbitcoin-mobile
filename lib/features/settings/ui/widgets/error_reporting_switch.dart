import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/error_reporting_confirmation_bottom_sheet.dart';
import 'package:flutter/material.dart';
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
        SnackBarUtils.showSnackBar(
          context,
          context.loc.errorReportingRestartSnackbar,
        );
      },
    );
  }
}
