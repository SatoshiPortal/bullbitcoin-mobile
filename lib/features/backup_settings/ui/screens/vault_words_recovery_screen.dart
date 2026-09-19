import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result_view.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

class VaultWordsRecoveryScreen extends StatefulWidget {
  final void Function(VaultBackupRecovery) onRecovered;
  const VaultWordsRecoveryScreen({super.key, required this.onRecovered});
  @override
  State<VaultWordsRecoveryScreen> createState() =>
      _VaultWordsRecoveryScreenState();
}

class _VaultWordsRecoveryScreenState extends State<VaultWordsRecoveryScreen>
    with PrivacyScreen {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.dataBackupRecoverWithWords)),
    body: SafeArea(
      child: BlocConsumer<VaultRecoveryCubit, VaultRecoveryState>(
        listener: (_, state) {
          if (state.result case final result?
              when result.complete &&
                  result.wallets.walletReferences.isNotEmpty) {
            widget.onRecovered(result);
          }
        },
        builder: (context, state) => state.result == null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(context.loc.vaultRecoveryWordsHelp),
                    if (state.busy) const LinearProgressIndicator(),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: state.busy,
                        child: ExcludeSemantics(
                          child: MnemonicWidget(
                            initialLength: bip39.MnemonicLength.words12,
                            allowPassphrase: false,
                            allowLabel: false,
                            allowMultipleMnemonicLength: false,
                            allowAutoFillWords: false,
                            submitLabel: context.loc.vaultRecoverySearch,
                            externalError: state.failure?.toTranslated(context),
                            onSubmit: (mnemonic) => context
                                .read<VaultRecoveryCubit>()
                                .search(words: mnemonic.words.join(' ')),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  VaultRecoveryResultView(result: state.result!),
                  if (state.failure case final failure?)
                    Text(failure.toTranslated(context)),
                  TextButton(
                    onPressed: context.read<VaultRecoveryCubit>().reset,
                    child: Text(context.loc.dataBackupChangeWords),
                  ),
                ],
              ),
      ),
    ),
  );
}
