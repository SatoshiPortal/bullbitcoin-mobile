import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dropdown/bb_dropdown.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result_view.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _RecoveryMethod { descriptor, words }

class VaultRecoveryScreen extends StatefulWidget {
  final Widget Function(ValueChanged<bool> onRestoringChanged)
  descriptorBuilder;
  final void Function(VaultBackupRecovery) onRecovered;
  const VaultRecoveryScreen({
    super.key,
    required this.descriptorBuilder,
    required this.onRecovered,
  });

  @override
  State<VaultRecoveryScreen> createState() => _VaultRecoveryScreenState();
}

class _VaultRecoveryScreenState extends State<VaultRecoveryScreen> {
  _RecoveryMethod? _method;
  bool _nativeRestoring = false;

  void _chooseMethod(_RecoveryMethod? method) {
    if (method == null || method == _method) return;
    FocusScope.of(context).unfocus();
    context.read<VaultRecoveryCubit>().reset();
    setState(() => _method = method);
  }

  void _setNativeRestoring(bool restoring) {
    if (mounted && restoring != _nativeRestoring) {
      setState(() => _nativeRestoring = restoring);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.bullVaultRecoverEntry)),
    body: SafeArea(
      child: BlocConsumer<VaultRecoveryCubit, VaultRecoveryState>(
        listener: (_, state) {
          if (_method != null) return;
          if (state.result case final result?
              when result.complete &&
                  result.wallets.walletReferences.isNotEmpty) {
            widget.onRecovered(result);
          }
        },
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: BBDropdown<_RecoveryMethod>(
                value: _method,
                hint: Text(context.loc.vaultRecoveryManualTitle),
                onChanged:
                    _nativeRestoring ||
                        (_method == _RecoveryMethod.words && state.busy)
                    ? null
                    : _chooseMethod,
                items: [
                  DropdownMenuItem(
                    value: _RecoveryMethod.descriptor,
                    child: Text(
                      context.loc.vaultRecoveryDescriptorEntry,
                      maxLines: 2,
                    ),
                  ),
                  DropdownMenuItem(
                    value: _RecoveryMethod.words,
                    child: Text(context.loc.dataBackupWordsTitle, maxLines: 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_method) {
                null => _discovery(context, state),
                _RecoveryMethod.descriptor => widget.descriptorBuilder(
                  _setNativeRestoring,
                ),
                _RecoveryMethod.words => VaultWordsRecoveryScreen(
                  onRecovered: widget.onRecovered,
                ),
              },
            ),
          ],
        ),
      ),
    ),
  );

  Widget _discovery(BuildContext context, VaultRecoveryState state) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(context.loc.vaultRecoveryDescription),
      const SizedBox(height: 16),
      if (state.busy) ...[
        const LinearProgressIndicator(),
        Text(context.loc.vaultBackupChecking),
      ],
      if (state.failure case final failure?)
        Text(
          failure is BackupSettingsWordsUnavailableFailure
              ? context.loc.vaultRecoveryNoCredential
              : failure.toTranslated(context),
        ),
      if (state.result case final result?)
        VaultRecoveryResultView(result: result),
      if (!state.busy)
        TextButton(
          onPressed: () => context.read<VaultRecoveryCubit>().search(),
          child: Text(context.loc.retry),
        ),
    ],
  );
}
