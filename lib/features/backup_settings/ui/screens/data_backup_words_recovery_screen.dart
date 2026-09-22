import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_contents.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/data_backup_recovery_result.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

class DataBackupWordsRecoveryScreen extends StatefulWidget {
  final void Function(WalletBackupInspection, WalletBackupRecovery) onRecovered;
  const DataBackupWordsRecoveryScreen({super.key, required this.onRecovered});
  @override
  State<DataBackupWordsRecoveryScreen> createState() =>
      _DataBackupWordsRecoveryScreenState();
}

class _DataBackupWordsRecoveryScreenState
    extends State<DataBackupWordsRecoveryScreen>
    with PrivacyScreen {
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  Future<void> _inspectAndConfirm(Mnemonic mnemonic) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    final cubit = context.read<DataBackupRecoveryCubit>();
    // Input remains in this short-lived UI action, never in a route or Cubit.
    final words = mnemonic.words.join(' ');
    try {
      await cubit.inspect(words: words);
      if (!mounted) return;
      final preview = cubit.state;
      if (preview is! DataBackupRecoveryPreview ||
          preview.inspection.snapshot == null) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.loc.dataBackupRecover),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.loc.dataBackupWordsApplyWarning),
                DataBackupContents(
                  snapshot: preview.inspection.snapshot!,
                  source: DataBackupContentsSource.server,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.loc.cancelButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.loc.dataBackupRecover),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed == true) {
        await cubit.recover(words: words);
      } else {
        cubit.reset();
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupRecoverWithWords)),
    body: SafeArea(
      child: BlocConsumer<DataBackupRecoveryCubit, DataBackupRecoveryState>(
        listener: (_, state) {
          if (state case DataBackupRecoveryPreview(
            :final inspection,
            result: final result?,
          ) when result.complete) {
            widget.onRecovered(inspection, result);
          }
        },
        builder: (context, state) {
          final failure = switch (state) {
            DataBackupRecoveryInitial(:final failure) ||
            DataBackupRecoveryPreview(:final failure) => failure,
          };
          if (state case DataBackupRecoveryPreview(result: final result?)) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DataBackupRecoveryResult(result: result),
                if (failure != null) Text(failure.toTranslated(context)),
                TextButton(
                  onPressed: context.read<DataBackupRecoveryCubit>().reset,
                  child: Text(context.loc.dataBackupChangeWords),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(context.loc.dataBackupWordsRecoveryHelp),
                if (state.busy) const LinearProgressIndicator(),
                if (state is DataBackupRecoveryPreview &&
                    state.inspection.snapshot == null)
                  Text(context.loc.dataBackupMissing),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _confirming || state.busy,
                    child: ExcludeSemantics(
                      child: MnemonicWidget(
                        initialLength: bip39.MnemonicLength.words12,
                        allowPassphrase: false,
                        allowLabel: false,
                        allowMultipleMnemonicLength: false,
                        allowAutoFillWords: false,
                        submitLabel: context.loc.dataBackupInspect,
                        externalError: failure?.toTranslated(context),
                        onSubmit: _inspectAndConfirm,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
