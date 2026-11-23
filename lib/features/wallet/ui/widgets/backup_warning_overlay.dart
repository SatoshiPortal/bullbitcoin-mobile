import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:backups/backups.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShapesX, BullText, Gap, BullTypographyX;

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
            if (state.showBackupWarning()) const _BackupWarningBlocker(),
          ],
        );
      },
    );
  }
}

class _BackupWarningBlocker extends StatefulWidget {
  const _BackupWarningBlocker();

  @override
  State<_BackupWarningBlocker> createState() => _BackupWarningBlockerState();
}

class _BackupWarningBlockerState extends State<_BackupWarningBlocker> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const VerifyBackupStatus());
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: context.appColors.surface.withAlpha(100),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(context.bullShapes.sheet),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BullText(
                              context.loc.backupWarningTitle,
                              style: context.bullType.subtitle
                                  .copyWith(fontWeight: FontWeight.w500)
                                  .copyWith(fontWeight: FontWeight.bold),
                              color: context.appColors.onSurface,
                            ),
                            const Gap(16),
                            BullText(
                              context.loc.backupWarningDescription,
                              style: context.bullType.body,
                              color: context.appColors.onSurface,
                            ),
                            const Gap(8),
                            for (final reason in [
                              context.loc.backupWarningLoseReasonLostPhone,
                              context.loc.backupWarningLoseReasonDeletedApp,
                              context.loc.backupWarningLoseReasonCriticalIssue,
                              context.loc.backupWarningLoseReasonKeystore,
                              context.loc.backupWarningLoseReasonCloudRestore,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BullText(
                                      '•  ',
                                      style: context.bullType.body,
                                      color: context.appColors.onSurface,
                                    ),
                                    Expanded(
                                      child: BullText(
                                        reason,
                                        style: context.bullType.body,
                                        color: context.appColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Gap(8),
                            BullText(
                              context.loc.backupWarningNoRecovery,
                              style: context.bullType.body.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              color: context.appColors.onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(24),
                    BullButton.primary(
                      label: context.loc.backupWarningBackupNow,
                      onPressed: () => BackupsNavigation.start(context),
                    ),
                    const Gap(12),
                    BullButton.secondary(
                      label: context.loc.backupWarningBackupLater,
                      onPressed: () {
                        context.read<WalletBloc>().add(
                          const DismissBackupWarning(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
