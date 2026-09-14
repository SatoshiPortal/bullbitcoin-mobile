import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// Finds and imports the vaults one backup credential published.
///
/// The two remote sources are asked separately and neither can stop the other:
/// a vault may be on the Data Backup server, on the relays, or on both, and a
/// source that cannot be reached says nothing about the one that can.
///
/// Without [words] every search runs on this device's own credential; with them
/// it runs on someone else's, which is what an heir has and what the manual
/// entries supply. Nothing here writes a seed or touches the default wallet.
final class RecoverVaultsFromBackupWordsUsecase {
  final WalletBackupFacade _metadata;
  final BullVaultFacade _vaults;
  final NostrIdentityFacade _identity;
  final RecoverVaultFromBip138FileUsecase _import;

  const RecoverVaultsFromBackupWordsUsecase(
    this._metadata,
    this._vaults,
    this._identity,
    this._import,
  );

  /// Whether this device can derive its own backup credential at all.
  ///
  /// False on a phone with no default seed, where the automatic search has
  /// nothing to search with and every manual entry still works.
  Future<bool> hasLocalCredential() async {
    final key = await _identity.walletBackupPublicKey();
    return key is Ok<String, NostrIdentityFailure>;
  }

  /// The vaults the Data Backup server holds for this credential.
  Future<Result<VaultRecoveryResult, BackupSettingsFailure>> fromDataBackup({
    String? words,
  }) async {
    final List<WalletBackupVaultSummary> vaults;
    if (words == null) {
      switch (await _metadata.fetchRemoteContents()) {
        case Err(:final failure):
          return Err(mapWalletBackupFailure(failure));
        case Ok(:final value):
          vaults = value?.vaults ?? const [];
      }
    } else {
      switch (await _metadata.fetchVaultsWithBackupWords(words)) {
        case Err(:final failure):
          return Err(mapWalletBackupFailure(failure));
        case Ok(:final value):
          vaults = value?.vaults ?? const [];
      }
    }
    final outcomes = <VaultRecoveryOutcome>[];
    for (final vault in vaults) {
      outcomes.add(
        await _import.importDescriptor(
          descriptor: vault.descriptor,
          network: vault.network,
          recoveryPackage: vault.recoveryPackage,
        ),
      );
    }
    return Ok(VaultRecoveryResult(outcomes: outcomes, incomplete: false));
  }

  /// The vault descriptors this credential published on the relays.
  Future<Result<VaultRecoveryResult, BackupSettingsFailure>> fromNostr({
    String? words,
    NostrSession? session,
  }) async {
    final NostrDescriptorSearch search;
    switch (await _vaults.discoverDescriptorsOnNostr(
      words: words,
      session: session,
    )) {
      case Err(:final failure):
        return Err(_mapVaultFailure(failure));
      case Ok(:final value):
        search = value;
    }
    final outcomes = <VaultRecoveryOutcome>[];
    for (final record in search.descriptors) {
      outcomes.add(
        await _import.importDescriptor(
          descriptor: record.descriptor,
          network: record.network,
        ),
      );
    }
    return Ok(
      VaultRecoveryResult(outcomes: outcomes, incomplete: search.incomplete),
    );
  }

  /// The backup words a mobile wallet's own seed derives.
  ///
  /// A vault passphrase is deliberately not taken here. Creation derives the
  /// backup credential from the canonical seed and uses the passphrase only
  /// for the vault's signing key, so applying it to discovery would search a
  /// namespace nothing was ever published under, and a vault that exists would
  /// read as absent. Attaching the passphrase-derived signing key is the
  /// separate, explicitly consented cosigner import.
  ///
  /// The seed is built here and dropped here: it is never stored, never becomes
  /// the default wallet, and its bytes are wiped before this returns.
  Result<String, BackupSettingsFailure> mobileSeedWords({
    required List<String> mnemonic,
  }) {
    Uint8List? bytes;
    try {
      bytes = Uint8List.fromList(
        bip39.Mnemonic.fromWords(words: mnemonic).seed,
      );
      return Ok(
        BackupCredential.deriveWords(
          Seed.mnemonic(
            mnemonicWords: mnemonic,
            bytes: bytes,
            masterFingerprint: bip32.Bip32Keys.fromSeed(bytes).fingerprintHex,
          ),
        ),
      );
    } on Exception {
      return const Err(BackupSettingsInvalidBackupWordsFailure());
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
    }
  }

  BackupSettingsFailure _mapVaultFailure(BullVaultFailure failure) =>
      switch (failure) {
        BullVaultBackupWordsFailure() =>
          const BackupSettingsInvalidBackupWordsFailure(),
        BullVaultBackupCredentialFailure() =>
          const BackupSettingsBackupWordsUnavailableFailure(),
        _ => const BackupSettingsUnavailableFailure(),
      };
}
