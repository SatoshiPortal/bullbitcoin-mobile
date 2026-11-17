import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullPickerChip, BullPickerItem;
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
        BullPickerItem(
          value: Environment.regtest,
          label: context.loc.electrumRegtest,
        ),
      ],
      onChanged: (environment) =>
          context.read<SettingsCubit>().selectNetwork(environment),
    );
  }
}
