import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result_view.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_source_rows.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullInfoCard, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Which twelve words the screen asks for: the ones the backup itself is keyed
/// by, or the recovery phrase of the Bull wallet that made the vaults.
enum _VaultWordsSource { backupWords, mobileSeed }

/// Recovers vaults from twelve words typed behind the capture block.
///
/// Both remote sources always run: the Data Backup server and the relays hold
/// different things, and a hit on one says nothing about the other. Nothing is
/// applied but the vaults themselves — no metadata, no seed, no default wallet.
/// A seed entered through [VaultWordsRecoveryScreen.mobileKey] is used to work
/// out that wallet's backup words and then dropped; attaching the signing key
/// is the separate, explicitly consented cosigner import the result invites.
class VaultWordsRecoveryScreen extends StatefulWidget {
  final _VaultWordsSource _source;

  const VaultWordsRecoveryScreen.backupWords({super.key})
    : _source = _VaultWordsSource.backupWords;

  const VaultWordsRecoveryScreen.mobileKey({super.key})
    : _source = _VaultWordsSource.mobileSeed;

  @override
  State<VaultWordsRecoveryScreen> createState() =>
      _VaultWordsRecoveryScreenState();
}

class _VaultWordsRecoveryScreenState extends State<VaultWordsRecoveryScreen>
    with PrivacyScreen {
  late final Future<void> _privacy = enableScreenPrivacy();

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget._source) {
        _VaultWordsSource.backupWords =>
          context.loc.vaultRecoveryImportBackupWords,
        _VaultWordsSource.mobileSeed =>
          context.loc.vaultRecoveryImportMobileKey,
      }),
    ),
    body: SafeArea(
      child: PrivacyGate(
        protection: _privacy,
        unprotected: const PrivacyUnavailableNotice(standalone: false),
        builder: (context) =>
            BlocBuilder<VaultRecoveryCubit, VaultRecoveryState>(
              builder: (context, state) => state.searched
                  ? _progress(context, state)
                  : _entry(context, state),
            ),
      ),
    ),
  );

  Widget _notice(BuildContext context) => switch (widget._source) {
    _VaultWordsSource.backupWords => BullInfoCard(
      description: context.loc.vaultRecoveryBackupWordsHelp,
      tagColor: context.appColors.secondary,
      bgColor: context.appColors.secondaryFixedDim,
    ),
    _VaultWordsSource.mobileSeed => BullInfoCard(
      description: context.loc.vaultRecoveryMobileKeyWarning,
      tagColor: context.appColors.warning,
      bgColor: context.appColors.warningContainer,
    ),
  };

  void _submit(BuildContext context, Mnemonic mnemonic) {
    final cubit = context.read<VaultRecoveryCubit>();
    switch (widget._source) {
      case _VaultWordsSource.backupWords:
        cubit.searchWithWords(mnemonic.words.join(' '));
      case _VaultWordsSource.mobileSeed:
        cubit.searchWithMobileSeed(
          mnemonic: mnemonic.words,
          passphrase: mnemonic.passphrase,
        );
    }
  }

  Widget _entry(BuildContext context, VaultRecoveryState state) => Column(
    children: [
      Padding(padding: const EdgeInsets.all(16), child: _notice(context)),
      Expanded(
        child: MnemonicWidget(
          initialLength: bip39.MnemonicLength.words12,
          allowPassphrase: widget._source == _VaultWordsSource.mobileSeed,
          allowLabel: false,
          allowMultipleMnemonicLength:
              widget._source == _VaultWordsSource.mobileSeed,
          submitLabel: context.loc.vaultRecoverySearch,
          externalError: state.failure?.toTranslated(context),
          onSubmit: (mnemonic) => _submit(context, mnemonic),
        ),
      ),
    ],
  );

  Widget _progress(BuildContext context, VaultRecoveryState state) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      VaultRecoverySourceRows(sources: state.sources),
      const Gap(16),
      if (state.failure case final failure?) ...[
        Text(failure.toTranslated(context), style: context.font.bodyMedium),
        const Gap(16),
      ],
      VaultRecoveryResultView(outcomes: state.outcomes),
    ],
  );
}
