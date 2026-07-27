import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_health_reminder.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/view_vault_key_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_routes.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupSettingsCubit>()..checkBackupStatus(),
      child: const _Screen(),
    );
  }
}

/// Answers one question, top to bottom: if this phone vanished right now,
/// could you get your money back?
///
/// The status rows state the facts, the hero names the single most useful
/// action, and the menu holds everything else. Each section is built by its
/// own function so a row can be added to one without disturbing the others.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupSettingsCubit, BackupSettingsState>(
      listenWhen: (p, c) => p.failure != c.failure && c.failure != null,
      listener: (context, state) {
        SnackBarUtils.showSnackBar(
          context,
          state.failure!.toTranslated(context),
        );
      },
      child: BlocBuilder<BackupSettingsCubit, BackupSettingsState>(
        builder: (context, state) {
          final hero = _hero(state);
          return Scaffold(
            appBar: AppBar(
              forceMaterialTransparency: true,
              automaticallyImplyLeading: false,
              flexibleSpace: TopBar(
                title: context.loc.backupSettingsScreenTitle,
                onBack: () => context.pop(),
              ),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: .start,
                          children: _statusRows(context, state),
                        ),
                      ),
                      if (hero != null) ...[const Gap(32), hero],
                      const Gap(24),
                      ..._menuRows(state),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The glanceable facts. Insertion point for the fork's metadata backup
  /// status row: append one [_StatusRow] here.
  List<Widget> _statusRows(BuildContext context, BackupSettingsState state) => [
    _StatusRow(
      label: context.loc.backupSettingsPhysicalBackup,
      isTested: state.isDefaultPhysicalBackupTested,
      lastTestedAt: state.lastPhysicalBackup,
    ),
    const Gap(15),
    _StatusRow(
      label: context.loc.backupSettingsEncryptedVault,
      isTested: state.isDefaultEncryptedBackupTested,
    ),
  ];

  /// The single most important action right now, or nothing at all when the
  /// status rows already say everything worth saying.
  Widget? _hero(BackupSettingsState state) {
    // Every wallet looks unprotected until the first load resolves; an urgent
    // card must never flash on the way in.
    if (state.status != BackupSettingsStatus.success) return null;

    final posture = BackupHealthPosture.of(
      isEncryptedVaultTested: state.isDefaultEncryptedBackupTested,
      isPhysicalBackupTested: state.isDefaultPhysicalBackupTested,
    );
    switch (posture) {
      case null:
        return const _ZeroBackupHero();
      case BackupHealthPosture.recoverbullOnly:
        return const _AddPhysicalBackupHero();
      case BackupHealthPosture.physicalOnly:
      case BackupHealthPosture.both:
        final lastTestedAt = state.lastPhysicalBackup;
        final isDue = isBackupReminderDue(
          anchor: lastTestedAt,
          now: DateTime.now(),
          interval: posture.reminderInterval,
        );
        return isDue ? _TestBackupHero(lastTestedAt: lastTestedAt) : null;
    }
  }

  /// The settings rows. Insertion point for the fork's metadata backup menu
  /// row: add one [SettingsEntryItem] to this list.
  List<Widget> _menuRows(BackupSettingsState state) => [
    if (state.lastEncryptedBackup != null) const _ViewVaultKeyButton(),
    if (state.lastEncryptedBackup != null || state.lastPhysicalBackup != null)
      const _TestBackupButton(),
    const _EncryptedVaultSettingsButton(),
    const _Bip329LabelsButton(),
    const _TransactionHistoryButton(),
  ];
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isTested;
  final DateTime? lastTestedAt;

  const _StatusRow({
    required this.label,
    required this.isTested,
    this.lastTestedAt,
  });

  @override
  Widget build(BuildContext context) {
    final testedAt = lastTestedAt;
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Text(label, style: context.font.bodyMedium),
            const Spacer(),
            Text(
              isTested
                  ? context.loc.backupSettingsTested
                  : context.loc.backupSettingsNotTested,
              style: context.font.bodyMedium?.copyWith(
                color: isTested
                    ? context.appColors.success
                    : context.appColors.error,
              ),
            ),
          ],
        ),
        if (isTested && testedAt != null)
          Text(
            context.loc.backupHealthLastTested(timeago.format(testedAt)),
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
      ],
    );
  }
}

/// One card, one verb. Shared by every hero so the screen can only ever ask
/// for one thing at a time.
class _HeroCard extends StatelessWidget {
  final String title;
  final String body;
  final String? footnote;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isUrgent;

  const _HeroCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.footnote,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isUrgent
        ? context.appColors.error
        : context.appColors.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceContainer,
        border: Border.all(color: accent, width: isUrgent ? 2 : 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          BBText(
            title,
            style: context.font.titleMedium?.copyWith(fontWeight: .bold),
            color: accent,
          ),
          const Gap(8),
          BBText(
            body,
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
          ),
          if (footnote != null) ...[
            const Gap(4),
            BBText(
              footnote!,
              style: context.font.bodySmall,
              color: context.appColors.textMuted,
            ),
          ],
          const Gap(16),
          BBButton.big(
            label: actionLabel,
            onPressed: onAction,
            bgColor: accent,
            textColor: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}

class _ZeroBackupHero extends StatelessWidget {
  const _ZeroBackupHero();

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      isUrgent: true,
      title: context.loc.backupSettingsHeroBackUpTitle,
      body: context.loc.backupSettingsHeroBackUpBody,
      actionLabel: context.loc.backupSettingsStartBackupAction,
      onAction: () => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
        extra: BackupSettingsFlow.backup,
      ),
    );
  }
}

class _AddPhysicalBackupHero extends StatelessWidget {
  const _AddPhysicalBackupHero();

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      title: context.loc.backupHealthReminderTitle,
      body: context.loc.backupHealthRecoverbullOnlyBody,
      actionLabel: context.loc.backupHealthAddPhysicalBackupAction,
      onAction: () => context.pushNamed(
        TestWalletBackupRoute.testPhysicalBackupFlow.name,
        extra: TestPhysicalBackupFlow.backup,
      ),
    );
  }
}

class _TestBackupHero extends StatelessWidget {
  final DateTime? lastTestedAt;

  const _TestBackupHero({required this.lastTestedAt});

  @override
  Widget build(BuildContext context) {
    final testedAt = lastTestedAt;
    return _HeroCard(
      title: context.loc.backupHealthReminderTitle,
      body: context.loc.backupHealthTestBackupBody,
      footnote: testedAt == null
          ? null
          : context.loc.backupHealthLastTested(timeago.format(testedAt)),
      actionLabel: context.loc.backupHealthTestBackupAction,
      onAction: () => context.pushNamed(
        TestWalletBackupRoute.testPhysicalBackupFlow.name,
        extra: TestPhysicalBackupFlow.verify,
      ),
    );
  }
}

class _TestBackupButton extends StatelessWidget {
  const _TestBackupButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.verified,
      title: context.loc.backupSettingsTestBackup,
      onTap: () => context.pushNamed(
        BackupSettingsSubroute.backupOptions.name,
        extra: BackupSettingsFlow.test,
      ),
    );
  }
}

class _ViewVaultKeyButton extends StatelessWidget {
  const _ViewVaultKeyButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.vpn_key,
      title: context.loc.backupSettingsViewVaultKey,
      onTap: () async {
        final confirmed = await ViewVaultKeyWarningBottomSheet.show(context);
        if (confirmed == true) {
          if (!context.mounted) return;
          await context.pushNamed(
            RecoverBullRoute.recoverbullFlows.name,
            extra: RecoverBullFlowsExtra(
              flow: RecoverBullFlow.viewVaultKey,
              vault: null,
            ),
          );
        }
      },
    );
  }
}

class _TransactionHistoryButton extends StatelessWidget {
  const _TransactionHistoryButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.file_download,
      title: context.loc.transactionHistoryTitle,
      onTap: () => context.pushNamed(TransactionsRoute.exportTransactions.name),
    );
  }
}

class _Bip329LabelsButton extends StatelessWidget {
  const _Bip329LabelsButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.sell,
      title: context.loc.backupSettingsLabelsButton,
      onTap: () => context.push(LabelsRouter.route.path),
    );
  }
}

class _EncryptedVaultSettingsButton extends StatelessWidget {
  const _EncryptedVaultSettingsButton();

  @override
  Widget build(BuildContext context) {
    return SettingsEntryItem(
      icon: Icons.cloud_circle,
      iconColor: context.appColors.secondary,
      textColor: context.appColors.secondary,
      title: context.loc.backupSettingsEncryptedVaultSettings,
      onTap: () {
        context.pushNamed(
          RecoverBullRoute.recoverbullFlows.name,
          extra: RecoverBullFlowsExtra(
            flow: RecoverBullFlow.settings,
            vault: null,
          ),
        );
      },
    );
  }
}
