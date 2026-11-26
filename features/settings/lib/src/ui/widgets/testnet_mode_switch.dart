import 'package:settings/src/l10n.dart';
import 'package:settings/src/ui/widgets/settings_restart_dialog.dart';
import 'package:preferences/preferences.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullPickerChip, BullPickerItem;
import 'package:primitives/primitives.dart' show RegtestHostProfile;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TestnetModeSwitch extends StatelessWidget {
  const TestnetModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state.storedSettings;
    if (settings == null ||
        settings.isSuperuser != true ||
        settings.isDevModeEnabled != true) {
      return const SizedBox.shrink();
    }
    return BullPickerChip<Environment>(
      value: settings.environment,
      items: [
        BullPickerItem(
          value: Environment.mainnet,
          label: context.loc.electrumMainnet,
        ),
        BullPickerItem(
          value: Environment.testnet,
          label: context.loc.electrumTestnet,
        ),
        if (RegtestHostProfile.isConfigured)
          BullPickerItem(
            value: Environment.regtest,
            label: context.loc.electrumRegtest,
          ),
      ],
      onChanged: (environment) async {
        final cubit = context.read<SettingsCubit>();
        final restartRequired = await cubit.selectNetwork(environment);
        if (restartRequired && context.mounted) {
          await showNetworkRestartDialog(context);
        }
      },
    );
  }
}

/// Blocks the app after a switch that changes a runtime captured at launch:
/// nothing may run on the old network, so the only action closes the process.
Future<void> showNetworkRestartDialog(
  BuildContext context, {
  VoidCallback? onClose,
}) {
  return showSettingsRestartDialog(
    context,
    message: context.loc.networkRestartDialogMessage,
    onClose: onClose,
  );
}
