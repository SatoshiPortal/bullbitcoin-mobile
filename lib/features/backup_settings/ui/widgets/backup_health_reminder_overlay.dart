import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_health_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
    final title = switch (decision.posture) {
      BackupHealthPosture.recoverbullOnly =>
        context.loc.backupHealthRecoverbullOnlyTitle,
      BackupHealthPosture.physicalOnly =>
        context.loc.backupHealthPhysicalOnlyTitle,
      BackupHealthPosture.both => context.loc.backupHealthBothTitle,
    };
    final intro = switch (decision.trigger) {
      BackupHealthTrigger.scheduled => context.loc.backupHealthScheduledIntro,
      BackupHealthTrigger.balanceMilestone =>
        context.loc.backupHealthBalanceIntro,
    };
    final body = switch (decision.posture) {
      BackupHealthPosture.recoverbullOnly =>
        context.loc.backupHealthRecoverbullOnlyBody,
      BackupHealthPosture.physicalOnly =>
        context.loc.backupHealthPhysicalOnlyBody,
      BackupHealthPosture.both => context.loc.backupHealthBothBody,
    };
    final primaryLabel = switch (decision.posture) {
      BackupHealthPosture.recoverbullOnly =>
        context.loc.backupHealthMakePhysicalBackup,
      BackupHealthPosture.physicalOnly =>
        context.loc.backupHealthTestPhysicalBackup,
      BackupHealthPosture.both => context.loc.backupHealthReviewBackups,
    };
    final secondaryLabel =
        decision.posture == BackupHealthPosture.recoverbullOnly
        ? context.loc.backupHealthUnderstandRisk
        : context.loc.backupHealthRemindThreeMonths;

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
                                title,
                                style: context.font.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                color: context.appColors.onSurface,
                              ),
                              const Gap(16),
                              BBText(
                                intro,
                                style: context.font.bodyMedium,
                                color: context.appColors.onSurface,
                              ),
                              const Gap(8),
                              BBText(
                                body,
                                style: context.font.bodyMedium,
                                color: context.appColors.onSurface,
                              ),
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
                        label: primaryLabel,
                        onPressed: () => _startPrimaryAction(context),
                        bgColor: context.appColors.onSurface,
                        textColor: context.appColors.surface,
                        disabled: state.isSaving,
                      ),
                      const Gap(12),
                      BBButton.big(
                        label: secondaryLabel,
                        onPressed: () => context
                            .read<BackupHealthReminderCubit>()
                            .acknowledge(),
                        bgColor: context.appColors.surface,
                        textColor: context.appColors.onSurface,
                        outlined: true,
                        disabled: state.isSaving,
                      ),
                      if (decision.posture ==
                          BackupHealthPosture.physicalOnly) ...[
                        const Gap(8),
                        TextButton(
                          onPressed: state.isSaving
                              ? null
                              : () => _openOtherBackupOptions(context),
                          child: Text(
                            context.loc.backupHealthOtherBackupOptions,
                          ),
                        ),
                      ],
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

    switch (state.decision.posture) {
      case BackupHealthPosture.recoverbullOnly:
        await context.pushNamed(
          TestWalletBackupRoute.testPhysicalBackupFlow.name,
          extra: TestPhysicalBackupFlow.backup,
        );
        return;
      case BackupHealthPosture.physicalOnly:
        await context.pushNamed(
          TestWalletBackupRoute.testPhysicalBackupFlow.name,
          extra: TestPhysicalBackupFlow.verify,
        );
        return;
      case BackupHealthPosture.both:
        await context.pushNamed(
          BackupSettingsSubroute.backupOptions.name,
          extra: BackupSettingsFlow.test,
        );
        return;
    }
  }

  Future<void> _openOtherBackupOptions(BuildContext context) async {
    final started = await context
        .read<BackupHealthReminderCubit>()
        .startRecommendedAction();
    if (!started || !context.mounted) return;

    await context.pushNamed(
      BackupSettingsSubroute.backupOptions.name,
      extra: BackupSettingsFlow.backup,
    );
  }
}
