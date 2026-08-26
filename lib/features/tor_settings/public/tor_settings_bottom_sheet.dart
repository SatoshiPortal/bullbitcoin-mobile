import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TorSettingsBottomSheet extends StatelessWidget {
  const TorSettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<TorSettingsCubit>();
    return BlurredBottomSheet.show<void>(
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
                    style: context.font.headlineMedium,
                  ),
                ),
                IconButton(
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
