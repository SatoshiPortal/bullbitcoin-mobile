import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DevModeSwitch extends StatelessWidget {
  const DevModeSwitch({super.key});

  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      child: const DevModeSwitch(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Gap(16),
            BBText('Dev Mode', style: context.font.headlineMedium),
            const Gap(16),
            BBText(
              'This mode is risky. By enabling it, you acknowledge that you may lose money',
              style: context.font.bodyMedium,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BBButton.small(
                  label: 'Disable',
                  onPressed: () {
                    context.read<SettingsCubit>().toggleDevMode(false);
                    context.pop();
                  },
                  bgColor: context.colour.primary,
                  textColor: context.colour.onPrimary,
                ),
                BBButton.small(
                  label: 'Enable',
                  onPressed: () {
                    context.read<SettingsCubit>().toggleDevMode(true);
                    context.pop();
                  },
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// context.read<SettingsCubit>().toggleDevMode(value);
