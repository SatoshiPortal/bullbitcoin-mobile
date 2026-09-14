import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

final class VaultBackupInspection {
  final BullVaultRecord record;
  final String descriptorId;
  final Map<VaultBackupSource, DateTime> testedAt;
  final BackupSettingsFailure? historyFailure;
  const VaultBackupInspection(
    this.record,
    this.testedAt, {
    required this.descriptorId,
    this.historyFailure,
  });
}

/// Only source-specific read-back methods can advance the test history.
final class VerifyVaultDescriptorBackupUsecase {
  final BullVaultFacade _vaults;
  final WalletBackupFacade _metadata;
  final BitcoinDescriptorPort _parser;
  final VaultBackupTestRepository _history;
  final WalletBackupFileRepository _files;
  final DateTime Function() _now;
  VerifyVaultDescriptorBackupUsecase(
    this._vaults,
    this._metadata,
    this._parser,
    this._history,
    this._files, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<Result<VaultBackupInspection, BackupSettingsFailure>> load(
    String walletId,
  ) async {
    final records = await _vaults.listRecords();
    if (records case Err()) {
      return const Err(BackupSettingsUnavailableFailure());
    }
    final matching = (records as Ok<List<BullVaultRecord>, BullVaultFailure>)
        .value
        .where((r) => r.walletId == walletId);
    if (matching.length != 1) {
      return const Err(BackupSettingsUnavailableFailure());
    }
    final record = matching.single;
    final policy = record.recoveryPackage.policy;
    final String descriptorId;
    try {
      descriptorId = VaultBackupTest.identity(
        _parser
            .parseBitcoinDescriptor(
              descriptor: policy.descriptor,
              network: policy.network,
            )
            .descriptor,
        policy.network.name,
      );
    } on Exception {
      return const Err(BackupSettingsInvalidFileFailure());
    }
    return switch (await _history.load(descriptorId)) {
      Ok(:final value) => Ok(
        VaultBackupInspection(record, value, descriptorId: descriptorId),
      ),
      // A damaged receipt must not block exporting the actual recovery data.
      Err(:final failure) => Ok(
        VaultBackupInspection(
          record,
          const {},
          descriptorId: descriptorId,
          historyFailure: failure,
        ),
      ),
    };
  }

  String export(VaultBackupInspection inspection) =>
      _vaults.encodeRecoveryPackage(inspection.record.recoveryPackage);

  Future<Result<bool?, BackupSettingsFailure>> importFile(
    String walletId,
  ) async {
    final picked = await _files.pick(maximumBytes: 128 * 1024);
    switch (picked) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok(:final value):
        try {
          return verifyManual(walletId, utf8.decode(value!));
        } on FormatException {
          return const Err(BackupSettingsInvalidFileFailure());
        }
    }
  }

  Future<Result<bool, BackupSettingsFailure>> verifyManual(
    String walletId,
    String source,
  ) async {
    if (source.isEmpty || source.length > 128 * 1024) {
      return const Err(BackupSettingsInvalidFileFailure());
    }
    final loaded = await load(walletId);
    if (loaded case Err(:final failure)) return Err(failure);
    final inspection =
        (loaded as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
    try {
      final policy = inspection.record.recoveryPackage.policy;
      final package = source.trimLeft().startsWith('{')
          ? _vaults.decodeRecoveryPackage(source)
          : null;
      if (source.trimLeft().startsWith('{') && package == null) {
        return const Err(BackupSettingsInvalidFileFailure());
      }
      if (package != null && package.policy.network != policy.network) {
        return const Err(BackupSettingsInvalidFileFailure());
      }
      if (!_matches(
        package?.policy.descriptor ?? source,
        policy.descriptor,
        policy.network,
      )) {
        return const Ok(false);
      }
      return _record(inspection, VaultBackupSource.manual);
    } on Exception {
      return const Err(BackupSettingsInvalidFileFailure());
    }
  }

  Future<Result<bool, BackupSettingsFailure>> verifyMetadata(
    String walletId,
  ) async {
    final loaded = await load(walletId);
    if (loaded case Err(:final failure)) return Err(failure);
    final inspection =
        (loaded as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
    final remote = await _metadata.fetchRemoteContents();
    if (remote case Err(:final failure)) {
      return Err(mapWalletBackupFailure(failure));
    }
    final contents =
        (remote as Ok<WalletBackupContents?, WalletBackupFailure>).value;
    if (contents == null) return const Ok(false);
    final policy = inspection.record.recoveryPackage.policy;
    try {
      final matches = contents.vaults.any(
        (vault) =>
            vault.network == policy.network &&
            _matches(vault.descriptor, policy.descriptor, policy.network),
      );
      if (!matches) return const Ok(false);
      return _record(inspection, VaultBackupSource.metadata);
    } on Exception {
      return const Err(BackupSettingsInvalidFileFailure());
    }
  }

  /// Checks that every eligible cosigner can find and open the descriptor.
  ///
  /// The recipients come from re-sealing the active descriptor: encoding is the
  /// one place that decides which accounts a vault entrusts, and its answer is
  /// deterministic even though the bytes are not. The freshly sealed artifact
  /// itself is discarded; only what the server already holds is checked.
  Future<Result<VaultBackupBip138Check, BackupSettingsFailure>> verifyBip138(
    String walletId,
  ) async {
    final loaded = await load(walletId);
    if (loaded case Err(:final failure)) return Err(failure);
    final inspection =
        (loaded as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
    final policy = inspection.record.recoveryPackage.policy;
    final encoded = await _vaults.encodePrivateDescriptorBackup(walletId);
    if (encoded case Err()) {
      return const Err(BackupSettingsUnavailableFailure());
    }
    final recipients =
        (encoded as Ok<BullVaultDescriptorBackup, BullVaultFailure>)
            .value
            .recipients;
    var found = 0;
    var incomplete = false;
    for (final recipient in recipients) {
      final page = await _metadata.lookupPrivateDescriptors(recipient);
      // A server that refused one cosigner cannot support a partial verdict
      // about the others, so the whole check stops rather than guessing.
      if (page case Err(:final failure)) {
        return Err(mapWalletBackupFailure(failure));
      }
      final lookup =
          (page as Ok<PrivateDescriptorLookup, WalletBackupFailure>).value;
      incomplete = incomplete || lookup.incomplete;
      for (final record in lookup.records) {
        final opened = _vaults.decodePrivateDescriptorBackup(
          bytes: Uint8List.fromList(record.ciphertext),
          accountKeyInput: recipient,
        );
        if (opened is! Ok<BullVaultDescriptorBackup, BullVaultFailure>) {
          continue;
        }
        if (opened.value.network != policy.network) continue;
        try {
          if (!_matches(
            opened.value.descriptor,
            policy.descriptor,
            policy.network,
          )) {
            continue;
          }
        } on Exception {
          continue;
        }
        found++;
        break;
      }
    }
    final check = VaultBackupBip138Check(
      eligibleKeys: recipients.length,
      foundKeys: found,
      incomplete: incomplete,
    );
    if (!check.complete) return Ok(check);
    return switch (await _record(inspection, VaultBackupSource.bip138)) {
      Ok() => Ok(check),
      Err(:final failure) => Err(failure),
    };
  }

  bool _matches(String candidate, String expected, Network network) =>
      _parser
          .parseBitcoinDescriptor(descriptor: candidate, network: network)
          .descriptor ==
      _parser
          .parseBitcoinDescriptor(descriptor: expected, network: network)
          .descriptor;

  Future<Result<bool, BackupSettingsFailure>> _record(
    VaultBackupInspection inspected,
    VaultBackupSource source,
  ) async {
    // A deletion/renewal while fetching must not certify a different descriptor.
    final current = await load(inspected.record.walletId);
    if (current case Err(:final failure)) return Err(failure);
    final value =
        (current as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
    if (value.descriptorId != inspected.descriptorId) {
      return const Err(BackupSettingsUnverifiedFailure());
    }
    return switch (await _history.record(
      VaultBackupTest(
        descriptorId: inspected.descriptorId,
        source: source,
        verifiedAt: _now(),
      ),
    )) {
      Ok() => const Ok(true),
      Err(:final failure) => Err(failure),
    };
  }
}
