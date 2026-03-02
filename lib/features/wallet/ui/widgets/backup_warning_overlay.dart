import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BackupWarningOverlay extends StatelessWidget {
  const BackupWarningOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      buildWhen: (previous, current) =>
          previous.showBackupWarning() != current.showBackupWarning(),
      builder: (context, state) {
        return Stack(
          children: [
            child,
            if (state.showBackupWarning())
              const _BackupWarningBlocker(),
          ],
        );
      },
    );
  }
}

class _BackupWarningBlocker extends StatelessWidget {
  const _BackupWarningBlocker();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: context.appColors.surface.withAlpha(100),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BBText(
                    context.loc.backupWarningTitle,
                    style: context.font.headlineMedium,
                    color: context.appColors.onSurface,
                  ),
                  const Gap(16),
                  BBText(
                    context.loc.backupWarningDescription,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                  ),
                  const Gap(24),
                  BBButton.big(
                    label: context.loc.backupWarningBackupNow,
                    onPressed: () {
                      context.pushNamed(
                        BackupSettingsSubroute.backupOptions.name,
                      );
                    },
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                  ),
                  const Gap(12),
                  BBButton.big(
                    label: context.loc.backupWarningBackupLater,
                    onPressed: () {
                      context
                          .read<WalletBloc>()
                          .add(const DismissBackupWarning());
                    },
                    bgColor: context.appColors.surface,
                    textColor: context.appColors.onSurface,
                    outlined: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
