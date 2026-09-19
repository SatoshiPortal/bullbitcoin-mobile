import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/data_recovery_words_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_test_status_row.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInfoCard, BullPasteInput, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VaultBackupScreen extends StatefulWidget {
  final String walletId;
  final Future<void> Function() onOpenDataBackup;
  const VaultBackupScreen({
    super.key,
    required this.walletId,
    required this.onOpenDataBackup,
  });
  @override
  State<VaultBackupScreen> createState() => _VaultBackupScreenState();
}

class _VaultBackupScreenState extends State<VaultBackupScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VaultBackupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletId != widget.walletId) _reload();
  }

  void _reload() => context.read<VaultBackupCubit>().load(widget.walletId);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (context.read<VaultBackupCubit>().state case VaultBackupLoaded(
        busy: false,
      )) {
        _reload();
      }
    }
  }

  Future<void> _openDataBackup() async {
    await widget.onOpenDataBackup();
    if (mounted) _reload();
  }

  void _verify() {
    final cubit = context.read<VaultBackupCubit>();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const _VerifyDescriptorScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultBackupRecovery)),
    body: SafeArea(
      child: BlocBuilder<VaultBackupCubit, VaultBackupState>(
        builder: (context, state) => switch (state) {
          VaultBackupLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          VaultBackupFailed(:final failure) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(failure.toTranslated(context)),
                TextButton(onPressed: _reload, child: Text(context.loc.retry)),
              ],
            ),
          ),
          VaultBackupLoaded() => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.loc.vaultBackupActions,
                style: context.font.titleLarge,
              ),
              const Gap(16),
              SettingsEntryItem(
                icon: Icons.qr_code,
                title: context.loc.vaultBackupViewDescriptor,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _VaultDescriptorScreen(
                      descriptor:
                          state.data.record.recoveryPackage.policy.descriptor,
                    ),
                  ),
                ),
              ),
              SettingsEntryItem(
                icon: Icons.file_download_outlined,
                title: context.loc.vaultBackupExportDescriptor,
                onTap: state.busy
                    ? null
                    : () => shareBullVaultRecoveryPackage(
                        context,
                        content: state.data.recoveryPackageSource,
                        policyId: state.data.record.recoveryPackage.policy.id,
                      ),
              ),
              SettingsEntryItem(
                icon: Icons.verified_outlined,
                title: context.loc.bullVaultVerifyDescriptor,
                onTap: state.busy ? null : _verify,
              ),
              if (state.data.canRevealWords)
                SettingsEntryItem(
                  icon: Icons.password_outlined,
                  title: context.loc.dataBackupWordsTitle,
                  onTap: state.busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => DataRecoveryWordsScreen.forVault(
                              expectedFingerprint:
                                  state.data.record.mobileSeedFingerprint,
                            ),
                          ),
                        ),
                ),
              const Gap(32),
              Text(
                context.loc.vaultBackupLastTestedTitle,
                style: context.font.titleLarge,
              ),
              const Gap(24),
              BackupTestStatusRow(
                label: context.loc.vaultBackupDescriptor,
                testedAt: state.data.record.descriptorTestedAt,
              ),
              const Gap(24),
              if (state.data.control.enabled == true) ...[
                BackupTestStatusRow(
                  label: context.loc.dataBackupTitle,
                  testedAt: state.data.record.serverTestedAt,
                ),
                const Gap(24),
                BullButton.big(
                  key: const ValueKey('vault-check-server'),
                  onPressed: context.read<VaultBackupCubit>().checkServer,
                  disabled: state.busy,
                  loading: state.busy,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                  label: state.busy
                      ? context.loc.vaultBackupChecking
                      : context.loc.vaultBackupCheckAgain,
                ),
                const Gap(24),
              ] else ...[
                BullInfoCard(
                  description: context.loc.vaultBackupEnableGuidance,
                  tagColor: context.appColors.warning,
                  bgColor: context.appColors.warningContainer,
                ),
                const Gap(16),
                BullButton.big(
                  key: const ValueKey('vault-open-data-backup'),
                  label: context.loc.vaultBackupEnable,
                  onPressed: _openDataBackup,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
                const Gap(24),
              ],
              if (state.data.control.recoveryIncomplete) ...[
                Text(context.loc.dataBackupRecoveryIncomplete),
                const Gap(16),
              ],
              if (state.failure case final failure?) ...[
                Text(failure.toTranslated(context)),
                const Gap(16),
              ],
              for (final destination in [
                ('nostr', context.loc.vaultBackupNostr),
                ('bitcoin', context.loc.vaultBackupBitcoin),
                ('bip138', context.loc.vaultBackupBip138),
              ]) ...[
                BackupTestStatusRow.comingSoon(
                  key: ValueKey('vault-future-${destination.$1}'),
                  label: destination.$2,
                ),
                const Gap(24),
              ],
            ],
          ),
        },
      ),
    ),
  );
}

class _VaultDescriptorScreen extends StatelessWidget {
  final String descriptor;
  const _VaultDescriptorScreen({required this.descriptor});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.vaultBackupViewDescriptor)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AspectRatio(aspectRatio: 1, child: QrDisplayWidget(data: descriptor)),
          const Gap(24),
          CopyInput(text: descriptor, maxLines: null),
        ],
      ),
    ),
  );
}

class _VerifyDescriptorScreen extends StatefulWidget {
  const _VerifyDescriptorScreen();
  @override
  State<_VerifyDescriptorScreen> createState() =>
      _VerifyDescriptorScreenState();
}

class _VerifyDescriptorScreenState extends State<_VerifyDescriptorScreen> {
  String _text = '';
  Future<void> _verify([String? source]) async {
    await context.read<VaultBackupCubit>().verifyDescriptor(source);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BullVaultScannerScreen(
          purpose: BullVaultScannerPurpose.descriptor,
        ),
      ),
    );
    if (mounted && scanned != null) setState(() => _text = scanned);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultVerifyDescriptor)),
    body: SafeArea(
      child: BlocBuilder<VaultBackupCubit, VaultBackupState>(
        builder: (context, state) {
          final busy = state is! VaultBackupLoaded || state.busy;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(context.loc.bullVaultDescriptorImportHint),
              const Gap(24),
              BullPasteInput(
                text: _text,
                hint: context.loc.bullVaultDescriptorHint,
                minLines: 4,
                maxLines: 10,
                enabled: !busy,
                onChanged: (value) => setState(() => _text = value),
                onScan: _scan,
              ),
              const Gap(16),
              BullButton.big(
                label: context.loc.bullVaultVerifyDescriptor,
                disabled: busy || _text.trim().isEmpty,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
                onPressed: () => _verify(_text),
              ),
              const Gap(16),
              BullButton.big(
                label: context.loc.bullVaultImportFile,
                disabled: busy,
                outlined: true,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
                onPressed: _verify,
              ),
            ],
          );
        },
      ),
    ),
  );
}
