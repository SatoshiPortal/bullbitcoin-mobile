import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DevModeSwitch extends StatelessWidget {
  const DevModeSwitch({super.key});

  Future<void> _showWarningBottomSheet(BuildContext context) {
    final loc = context.loc;
    return BullBottomSheet.show<void>(
      context: context,
      child: _DevModeWarningSheet(
        title: loc.settingsDevModeWarningTitle,
        message: loc.settingsDevModeWarningMessage,
        confirmLabel: loc.settingsDevModeUnderstandButton,
        onConfirm: () => context.read<SettingsCubit>().toggleDevMode(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDevModeEnabled =
        context.watch<SettingsCubit>().state.isDevModeEnabled ?? false;

    return Switch(
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

class _DevModeWarningSheet extends StatelessWidget {
  const _DevModeWarningSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: BullText(
                title,
                role: BullTextRole.subtitle,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
            const Gap(BullSpacing.md),
            BullText(
              message,
              role: BullTextRole.body,
              color: colors.onSurface,
              textAlign: TextAlign.center,
            ),
            const Gap(BullSpacing.md),
            BullButton.primary(
              label: confirmLabel,
              onPressed: () {
                onConfirm();
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
