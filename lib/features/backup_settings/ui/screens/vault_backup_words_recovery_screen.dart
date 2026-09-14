import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_source_rows.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_ui/bull_ui.dart' show BullInfoCard, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// Recovers vaults from the twelve magic backup words of another wallet.
///
/// Both remote sources always run: the Data Backup server and the relays hold
/// different things, and a hit on one says nothing about the other. Nothing is
/// applied but the vaults themselves — no metadata, no seed, no default wallet.
class VaultBackupWordsRecoveryScreen extends StatefulWidget {
  const VaultBackupWordsRecoveryScreen({super.key});

  @override
  State<VaultBackupWordsRecoveryScreen> createState() =>
      _VaultBackupWordsRecoveryScreenState();
}

class _VaultBackupWordsRecoveryScreenState
    extends State<VaultBackupWordsRecoveryScreen>
    with PrivacyScreen {
  late final Future<void> _privacy = enableScreenPrivacy();

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.vaultRecoveryImportBackupWords)),
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

  Widget _entry(BuildContext context, VaultRecoveryState state) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: BullInfoCard(
          description: context.loc.vaultRecoveryBackupWordsHelp,
          tagColor: context.appColors.secondary,
          bgColor: context.appColors.secondaryFixedDim,
        ),
      ),
      Expanded(
        child: MnemonicWidget(
          initialLength: bip39.MnemonicLength.words12,
          allowPassphrase: false,
          allowLabel: false,
          allowMultipleMnemonicLength: false,
          submitLabel: context.loc.vaultRecoverySearch,
          externalError: state.failure?.toTranslated(context),
          onSubmit: (mnemonic) => context
              .read<VaultRecoveryCubit>()
              .searchWithWords(mnemonic.words.join(' ')),
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
