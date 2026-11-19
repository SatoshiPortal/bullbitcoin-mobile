import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInfoCard, BullTopBar, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class PinSettingsScreen extends StatelessWidget {
  /// Opens the wallet backup, shown while a backup is required first.
  final VoidCallback onBackUp;

  const PinSettingsScreen({super.key, required this.onBackUp});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PinCodeSettingBloc>();
    final state = context.watch<PinCodeSettingBloc>().state;
    final isPinCodeSet = state.isPinCodeSet;
    final backupRequired = state.status == PinCodeSettingStatus.backupRequired;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          onBack: () => context.pop(),
          title: context.loc.pinCodeSecurityPinTitle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      context.loc.pinCodeManageTitle,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w500)
                          .copyWith(color: context.appColors.onSurface),
                    ),
                    const Gap(16),
                    Text(
                      context.loc.pinCodeCreateDescription,
                      style: context.bullType.body.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    if (backupRequired) ...[
                      const Gap(24),
                      BullInfoCard(
                        description: context.loc.pinCodeBackupRequiredWarning,
                        tagColor: context.appColors.warning,
                        bgColor: context.appColors.warningContainer,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (backupRequired) ...[
                    BullButton.big(
                      label: context.loc.backupSettingsStartBackup,
                      onPressed: onBackUp,
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onSecondary,
                    ),
                    const Gap(16),
                  ],
                  BullButton.big(
                    disabled: backupRequired,
                    label: isPinCodeSet
                        ? context.loc.pinCodeChangeButton
                        : context.loc.pinCodeCreateButton,
                    onPressed: () => bloc.add(const PinCodeCreate()),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  const Gap(16),
                  if (isPinCodeSet)
                    BullButton.big(
                      label: context.loc.pinCodeRemoveButton,
                      onPressed: () => bloc.add(const PinCodeDelete()),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  const Gap(24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
