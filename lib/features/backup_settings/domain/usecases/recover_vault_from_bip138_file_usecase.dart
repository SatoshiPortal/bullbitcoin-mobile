import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';

/// Opens one private descriptor backup with a cosigner's account key and
/// imports the vault it carries.
///
/// Offline by design: a file on a memory stick and the public key of one
/// cosigner are the whole recovery, with no server and no seed. The same step
/// is what [RecoverVaultsFromCosignerKeyUsecase] applies to each candidate a
/// lookup returns.
final class RecoverVaultFromBip138FileUsecase {
  /// The app's BIP138 bound; a larger file was written by something else.
  static const maximumFileBytes = BullVaultDescriptorBackup.maxBytes;

  /// Recovered vaults arrive without a name, as they do through the metadata
  /// backup. The vault settings screen renames them.
  static const fallbackLabel = 'BullVault';

  final BullVaultFacade _vaults;
  final BitcoinDescriptorPort _parser;

  const RecoverVaultFromBip138FileUsecase(this._vaults, this._parser);

  Future<VaultRecoveryOutcome> execute({
    required Uint8List fileBytes,
    required String accountKeyInput,
  }) async {
    if (fileBytes.isEmpty || fileBytes.length > maximumFileBytes) {
      return const VaultRecoveryOutcome(VaultRecoveryStatus.undecryptable);
    }
    final opened = _vaults.decodePrivateDescriptorBackup(
      bytes: fileBytes,
      accountKeyInput: accountKeyInput,
    );
    if (opened case Err()) {
      return const VaultRecoveryOutcome(VaultRecoveryStatus.undecryptable);
    }
    final content =
        (opened as Ok<BullVaultDescriptorBackup, BullVaultFailure>).value;
    final existing = await _existingWalletFor(content);
    if (existing != null) {
      return VaultRecoveryOutcome(
        VaultRecoveryStatus.alreadyPresent,
        walletId: existing,
      );
    }
    // One importer for every route into the app: the vault feature applies the
    // same network, structure, lineage and duplicate rules it always does.
    final restored = await _vaults.restoreFromDescriptor(
      source: content.descriptor,
      label: fallbackLabel,
    );
    return switch (restored) {
      Err() => const VaultRecoveryOutcome(VaultRecoveryStatus.unsupported),
      Ok(:final value) => VaultRecoveryOutcome(
        VaultRecoveryStatus.imported,
        walletId: value.wallet.id,
      ),
    };
  }

  /// The wallet already holding this exact descriptor, or null.
  ///
  /// Restoration accepts a vault that is already here, so this is only about
  /// telling the person that nothing changed.
  Future<String?> _existingWalletFor(BullVaultDescriptorBackup content) async {
    final records = await _vaults.listRecords();
    if (records case Err()) return null;
    for (final record
        in (records as Ok<List<BullVaultRecord>, BullVaultFailure>).value) {
      final policy = record.recoveryPackage.policy;
      if (policy.network != content.network) continue;
      try {
        if (_canonical(policy.descriptor, policy.network) ==
            _canonical(content.descriptor, content.network)) {
          return record.walletId;
        }
      } on Exception {
        continue;
      }
    }
    return null;
  }

  String _canonical(String descriptor, Network network) => _parser
      .parseBitcoinDescriptor(descriptor: descriptor, network: network)
      .descriptor;
}
