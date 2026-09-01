import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef ReadWalletMetadataSnapshot =
    Future<Result<WalletMetadataSnapshot, WalletMetadataBackupFailure>>
    Function();

DateTime _systemNowUtc() => DateTime.now().toUtc();

/// One read-only capture of the manifest, the external wallet definitions and
/// the protected-data section (spec 16).
///
/// Building a snapshot writes nothing: the invariant recovery material a
/// published document must carry is registered when the feature starts or is
/// enabled, by [RegisterWalletBackupRecoveryMaterialUsecase] (spec F5). Each
/// owner is read exactly once per call, so the result is a snapshot that
/// actually existed (spec F6).
final class BuildWalletBackupSnapshotUsecase {
  final KeychainManifestFacade _keychainManifest;
  final WalletDefinitionsBackup _definitions;
  final ReadWalletMetadataSnapshot _readMetadata;
  final DateTime Function() _nowUtc;

  const BuildWalletBackupSnapshotUsecase(
    this._keychainManifest,
    this._definitions,
    this._readMetadata, {
    this._nowUtc = _systemNowUtc,
  });

  @useResult
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> execute({
    required String parentFingerprint,
    bool allowEmpty = false,
  }) async {
    final fingerprint = Fingerprint.tryParse(parentFingerprint);
    if (fingerprint == null) {
      return const Err(WalletBackupParentFingerprintMismatchFailure());
    }
    final now = _nowUtc();

    final KeychainManifest manifest;
    switch (await _keychainManifest.buildManifest(
      fingerprint,
      allowEmpty: allowEmpty,
    )) {
      case Ok(:final value):
        manifest = value;
      case Err(:final failure):
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }

    final List<WalletDefinition> definitions;
    switch (await _definitions.read()) {
      case Ok(:final value):
        definitions = value;
      case Err(:final failure):
        return Err(failure);
    }

    final WalletMetadataSnapshot metadata;
    switch (await _readMetadata()) {
      case Ok(:final value):
        metadata = value;
      case Err(:final failure):
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }

    return Ok(
      WalletBackupSnapshot(
        parentFingerprint: fingerprint,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        recoveryManifest: manifest,
        externalWalletDefinitions: definitions,
        metadata: metadata,
      ),
    );
  }
}
