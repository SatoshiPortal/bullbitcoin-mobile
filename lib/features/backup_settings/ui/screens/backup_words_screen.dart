import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/secret_reveal_gate.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_words_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the twelve magic backup words behind the PIN and the capture block.
///
/// Both gates are the shared [SecretRevealGate], which also drops this screen
/// when the app goes to the background: the derived words go with it and
/// coming back asks for the PIN again. Nothing secret is built, held or handed
/// to another widget before it lets the reveal through. No quiz follows the
/// words: writing them down is what the person came here to do, and a recorded
/// answer would not make them any safer.
class BackupWordsScreen extends StatelessWidget {
  final AppUnlockFacade appUnlock;

  /// The wallet a selected vault records as its own, and whether a vault is
  /// what asked at all.
  ///
  /// The Data Backup entry asks for this device's own words; a vault asks for
  /// the words that open its backups, which another phone may hold, and a
  /// vault that records no origin names no wallet this device can answer for.
  final String? originFingerprint;
  final bool forVault;

  /// This device's own magic backup words.
  const BackupWordsScreen({super.key, this.appUnlock = const AppUnlockFacade()})
    : originFingerprint = null,
      forVault = false;

  /// The words that open one vault's backups, whoever holds them.
  const BackupWordsScreen.forVault({
    super.key,
    required this.originFingerprint,
    this.appUnlock = const AppUnlockFacade(),
  }) : forVault = true;

  @override
  Widget build(BuildContext context) => SecretRevealGate(
    appUnlock: appUnlock,
    builder: (_) => _RevealedBackupWords(
      originFingerprint: originFingerprint,
      forVault: forVault,
    ),
  );
}

/// The reveal itself. It lives below the gate so that locking the gate
/// unmounts it, which is what releases the words it derived.
class _RevealedBackupWords extends StatefulWidget {
  final String? originFingerprint;
  final bool forVault;

  const _RevealedBackupWords({
    required this.originFingerprint,
    required this.forVault,
  });

  @override
  State<_RevealedBackupWords> createState() => _RevealedBackupWordsState();
}

class _RevealedBackupWordsState extends State<_RevealedBackupWords> {
  late final Future<List<String>?> _words = context
      .read<BackupWordsCubit>()
      .reveal(
        originFingerprint: widget.originFingerprint,
        forVault: widget.forVault,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>?>(
    future: _words,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _BackupWordsMessage();
      }
      final words = snapshot.data;
      if (words == null) return const _BackupWordsMessage();
      return ShowMnemonicScreen.forMnemonic(
        mnemonic: words,
        title: context.loc.backupWordsTitle,
        notice: context.loc.backupWordsExplanation,
        onContinue: () => Navigator.of(context).pop(),
      );
    },
  );
}

/// The screen while the words are being derived, and when they cannot be.
class _BackupWordsMessage extends StatelessWidget {
  const _BackupWordsMessage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.backupWordsTitle)),
    body: SafeArea(
      child: BlocBuilder<BackupWordsCubit, BackupWordsState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.loc.backupWordsExplanation,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            if (state.failure case final failure?)
              Text(failure.toTranslated(context), style: context.font.bodyLarge)
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    ),
  );
}
