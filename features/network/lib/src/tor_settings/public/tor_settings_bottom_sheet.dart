import '../../network_l10n.dart';
import '../presentation/tor_settings_cubit.dart';
import 'tor_settings_panel.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullBottomSheet, BullTypographyX;

class TorSettingsBottomSheet extends StatelessWidget {
  const TorSettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<TorSettingsCubit>();
    return BullBottomSheet.show<void>(
      context: context,
      child: BlocProvider.value(
        value: cubit,
        child: const TorSettingsBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.loc.torSettingsTitle,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.loc.torCloseTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Expanded(child: TorSettingsPanel()),
        ],
      ),
    ),
  );
}
