import 'package:access/src/access_l10n.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
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
                          .copyWith(color: context.bull.onSurface),
                    ),
                    const Gap(16),
                    Text(
                      context.loc.pinCodeCreateDescription,
                      style: context.bullType.body.copyWith(
                        color: context.bull.textMuted,
                      ),
                    ),
                    if (backupRequired) ...[
                      const Gap(24),
                      BullInfoCard(
                        description: context.loc.pinCodeBackupRequiredWarning,
                        tagColor: context.bull.warning,
                        bgColor: context.bull.warningContainer,
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
                    BullButton.secondary(
                      label: context.loc.backupSettingsStartBackup,
                      onPressed: onBackUp,
                    ),
                    const Gap(16),
                  ],
                  BullButton.secondary(
                    label: isPinCodeSet
                        ? context.loc.pinCodeChangeButton
                        : context.loc.pinCodeCreateButton,
                    onPressed: (backupRequired)
                        ? null
                        : () => bloc.add(const PinCodeCreate()),
                  ),
                  const Gap(16),
                  if (isPinCodeSet)
                    BullButton.primary(
                      label: context.loc.pinCodeRemoveButton,
                      onPressed: () => bloc.add(const PinCodeDelete()),
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
