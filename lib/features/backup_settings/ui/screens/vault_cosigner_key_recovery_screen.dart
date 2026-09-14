import 'dart:typed_data';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/features/backup_settings/presentation/backup_settings_failure_l10n.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/vault_recovery_result.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullPasteInput, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recovers every vault filed under one cosigner's public account key.
///
/// The key alone searches the descriptor server. The same key also opens a
/// saved encrypted descriptor file, in either order: someone may arrive with
/// the file first and find the key later, or the other way round.
class VaultCosignerKeyRecoveryScreen extends StatefulWidget {
  /// A BIP138 file the descriptor entry recognised and handed over.
  final Uint8List? initialArtifact;

  const VaultCosignerKeyRecoveryScreen({super.key, this.initialArtifact});

  @override
  State<VaultCosignerKeyRecoveryScreen> createState() =>
      _VaultCosignerKeyRecoveryScreenState();
}

class _VaultCosignerKeyRecoveryScreenState
    extends State<VaultCosignerKeyRecoveryScreen> {
  late Uint8List? _artifact = widget.initialArtifact;
  String _accountKey = '';

  Future<void> _scan() async {
    var delivered = false;
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.loc.bullVaultScanPublicKey)),
          body: QrScannerWidget(
            onScanned: (value) {
              if (delivered) return;
              delivered = true;
              Navigator.of(context).pop(value);
            },
          ),
        ),
      ),
    );
    if (mounted && scanned != null) setState(() => _accountKey = scanned);
  }

  Future<void> _chooseArtifact() async {
    final bytes = await context.read<VaultRecoveryCubit>().pickArtifact();
    if (mounted && bytes != null) setState(() => _artifact = bytes);
  }

  Future<void> _search() {
    final cubit = context.read<VaultRecoveryCubit>();
    final artifact = _artifact;
    return artifact == null
        ? cubit.recoverFromCosignerKey(_accountKey)
        : cubit.recoverFromArtifact(
            bytes: artifact,
            accountKeyInput: _accountKey,
          );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.vaultRecoveryImportCosignerKey)),
    body: SafeArea(
      child: BlocBuilder<VaultRecoveryCubit, VaultRecoveryState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _artifact == null
                  ? context.loc.vaultRecoveryImportCosignerKeyDescription
                  : context.loc.vaultRecoveryEncryptedFileDetected,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            Text(
              context.loc.bullVaultPublicKeyLabel,
              style: context.font.bodyMedium,
            ),
            const Gap(8),
            BullPasteInput(
              text: _accountKey,
              hint: context.loc.bullVaultPublicKeyHint,
              onChanged: (value) => setState(() => _accountKey = value),
              onScan: _scan,
              enabled: !state.busy,
              minLines: 2,
              maxLines: 4,
            ),
            const Gap(16),
            if (_artifact != null)
              Text(
                context.loc.vaultRecoveryArtifactChosen,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.success,
                ),
              )
            else
              BullButton.big(
                label: context.loc.vaultRecoveryChooseArtifact,
                onPressed: _chooseArtifact,
                disabled: state.busy,
                outlined: true,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
            const Gap(16),
            BullButton.big(
              label: context.loc.vaultRecoverySearch,
              onPressed: _search,
              disabled: state.busy || _accountKey.trim().isEmpty,
              loading: state.busy,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
            if (state.failure case final failure?) ...[
              const Gap(16),
              Text(
                failure.toTranslated(context),
                style: context.font.bodyMedium,
              ),
            ],
            const Gap(24),
            VaultRecoveryResultView(outcomes: state.outcomes),
          ],
        ),
      ),
    ),
  );
}
