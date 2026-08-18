import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/warning_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DevModeSwitch extends StatelessWidget {
  const DevModeSwitch({super.key});

  Future<void> _showWarningBottomSheet(BuildContext context) {
    return WarningBottomSheet.show(
      context,
      title: context.loc.settingsDevModeWarningTitle,
      message: context.loc.settingsDevModeWarningMessage,
      confirmLabel: context.loc.settingsDevModeUnderstandButton,
      onConfirm: () => context.read<SettingsCubit>().toggleDevMode(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDevModeEnabled =
        context.watch<SettingsCubit>().state.isDevModeEnabled ?? false;

    return BullSwitch(
      value: isDevModeEnabled,
      onChanged: (value) async {
        if (value) {
          await _showWarningBottomSheet(context);
        } else {
          await context.read<SettingsCubit>().toggleDevMode(false);
        }
      },
    );
  }
}
