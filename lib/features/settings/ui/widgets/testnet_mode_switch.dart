import 'package:bull_ui/bull_ui.dart' show BullButton, BullButtonSize;

import 'dart:io' show exit;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullDialog, BullPickerChip, BullPickerItem;
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
  return BullDialog.show<void>(
    context: context,
    isDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.loc.networkRestartDialogTitle),
      content: PopScope(
        canPop: false,
        child: Text(dialogContext.loc.networkRestartDialogMessage),
      ),
      actions: [
        BullButton.primary(
          label: dialogContext.loc.networkRestartDialogAction,
          onPressed: onClose ?? () => exit(0),
          size: BullButtonSize.small,
          compact: true,
        ),
      ],
    ),
  );
}
