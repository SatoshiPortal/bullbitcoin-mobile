import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_health_reminder_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class BackupHealthReminderOverlay extends StatefulWidget {
  final Widget child;
  final bool canShow;
  final List<Wallet> wallets;
  final int arkBalanceSat;

  const BackupHealthReminderOverlay({
    super.key,
    required this.child,
    required this.canShow,
    required this.wallets,
    required this.arkBalanceSat,
  });

  @override
  State<BackupHealthReminderOverlay> createState() =>
      _BackupHealthReminderOverlayState();
}

class _BackupHealthReminderOverlayState
    extends State<BackupHealthReminderOverlay> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => context.read<BackupHealthReminderCubit>().reevaluate(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void didUpdateWidget(covariant BackupHealthReminderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallets != widget.wallets ||
        oldWidget.arkBalanceSat != widget.arkBalanceSat) {
      _evaluate();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackupHealthReminderCubit, BackupHealthReminderState>(
      builder: (context, state) {
        final visible = state is BackupHealthReminderVisible && widget.canShow;
        return Stack(
          children: [
            widget.child,
            if (visible) _BackupHealthReminderBlocker(state: state),
          ],
        );
      },
    );
  }

  void _evaluate() {
    if (!mounted) return;
    context.read<BackupHealthReminderCubit>().evaluate(
      wallets: widget.wallets,
      arkBalanceSat: widget.arkBalanceSat,
    );
  }
}

class _BackupHealthReminderBlocker extends StatelessWidget {
  final BackupHealthReminderVisible state;

  const _BackupHealthReminderBlocker({required this.state});

  @override
  Widget build(BuildContext context) {
    final decision = state.decision;
    final isMilestone =
        decision.trigger == BackupHealthTrigger.balanceMilestone;
    final urgesPhysicalBackup = decision.posture.urgesPhysicalBackup;
    final lastTestedAt = decision.physicalBackupTestedAt;

    return Positioned.fill(
      child: PopScope(
        canPop: false,
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BBText(
                                isMilestone
                                    ? context.loc.backupHealthMilestoneTitle
                                    : context.loc.backupHealthReminderTitle,
                                style: context.font.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                color: context.appColors.onSurface,
                              ),
                              const Gap(16),
                              if (isMilestone) ...[
                                BBText(
                                  context.loc.backupHealthMilestoneBody,
                                  style: context.font.bodyMedium,
                                  color: context.appColors.onSurface,
                                ),
                                const Gap(8),
                              ],
                              BBText(
                                urgesPhysicalBackup
                                    ? context
                                          .loc
                                          .backupHealthRecoverbullOnlyBody
                                    : context.loc.backupHealthTestBackupBody,
                                style: context.font.bodyMedium,
                                color: context.appColors.onSurface,
                              ),
                              if (!urgesPhysicalBackup &&
                                  lastTestedAt != null) ...[
                                const Gap(8),
                                BBText(
                                  context.loc.backupHealthLastTested(
                                    timeago.format(lastTestedAt),
                                  ),
                                  style: context.font.bodySmall,
                                  color: context.appColors.textMuted,
                                ),
                              ],
                              if (state.failure != null) ...[
                                const Gap(12),
                                BBText(
                                  state.failure!.toTranslated(context),
                                  style: context.font.bodyMedium,
                                  color: context.appColors.error,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Gap(24),
                      BBButton.big(
                        label: urgesPhysicalBackup
                            ? context.loc.backupHealthAddPhysicalBackupAction
                            : context.loc.backupHealthTestBackupAction,
                        onPressed: () => _startPrimaryAction(context),
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                        disabled: state.isSaving,
                      ),
                      const Gap(8),
                      TextButton(
                        onPressed: state.isSaving
                            ? null
                            : () => context
                                  .read<BackupHealthReminderCubit>()
                                  .acknowledge(),
                        child: Text(context.loc.backupHealthNotNow),
                      ),
                      if (state.failure != null)
                        TextButton(
                          onPressed: state.isSaving
                              ? null
                              : () => context
                                    .read<BackupHealthReminderCubit>()
                                    .dismissFailureForSession(),
                          child: Text(context.loc.backupHealthCloseForNow),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startPrimaryAction(BuildContext context) async {
    final started = await context
        .read<BackupHealthReminderCubit>()
        .startRecommendedAction();
    if (!started || !context.mounted) return;

    await context.pushNamed(
      TestWalletBackupRoute.testPhysicalBackupFlow.name,
      extra: state.decision.posture.urgesPhysicalBackup
          ? TestPhysicalBackupFlow.backup
          : TestPhysicalBackupFlow.verify,
    );
  }
}
