import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShapesX, BullText, Gap, BullTypographyX;

import '../../backups_feature.dart';
import '../../backups_l10n.dart';

class BackupWarningOverlay extends StatelessWidget {
  final bool showWarning;
  final VoidCallback onWarningShown;
  final VoidCallback onDismiss;
  final Widget child;

  const BackupWarningOverlay({
    super.key,
    required this.showWarning,
    required this.onWarningShown,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ExcludeSemantics(excluding: showWarning, child: child),
      if (showWarning)
        Positioned.fill(
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: _BackupWarningBlocker(
              onShown: onWarningShown,
              onDismiss: onDismiss,
            ),
          ),
        ),
    ],
  );
}

class _BackupWarningBlocker extends StatefulWidget {
  final VoidCallback onShown;
  final VoidCallback onDismiss;

  const _BackupWarningBlocker({required this.onShown, required this.onDismiss});

  @override
  State<_BackupWarningBlocker> createState() => _BackupWarningBlockerState();
}

class _BackupWarningBlockerState extends State<_BackupWarningBlocker> {
  @override
  void initState() {
    super.initState();
    widget.onShown();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
                          Semantics(
                            header: true,
                            namesRoute: true,
                            child: BullText(
                              context.loc.backupWarningTitle,
                              style: context.bullType.subtitle
                                  .copyWith(fontWeight: FontWeight.w500)
                                  .copyWith(fontWeight: FontWeight.bold),
                              color: context.appColors.onSurface,
                            ),
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
                    onPressed: widget.onDismiss,
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
