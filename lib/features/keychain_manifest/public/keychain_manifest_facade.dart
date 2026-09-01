import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/remove_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/replace_seed_wallet_inventory_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/restore_manifest_snapshot_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_passphrase_label_hint_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart'
    show
        KeychainManifest,
        KeychainManifestDerivationKind,
        KeychainManifestNostrKeyKind,
        KeychainManifestEntry,
        KeychainManifestWallet,
        KeychainManifestNostrKey;
export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart'
    show KeychainManifestEdit, KeychainManifestWalletInventoryBinding;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
export 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart'
    show KeychainManifestRestorePolicy, KeychainManifestRestoreReport;
export 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';

final class KeychainManifestFacade {
  final WatchKeychainManifestChangesUsecase _watchChanges;
  final String Function(KeychainManifest manifest) _encode;
  final BuildKeychainManifestFileUsecase _build;
  final ParseKeychainManifestFileUsecase _parse;
  final ReplaceSeedWalletInventoryUsecase _replaceSeedInventory;
  final RecordPassphraseWalletUsecase _recordWallet;
  final RestoreManifestSnapshotUsecase _restoreSnapshot;
  final RecordKeychainManifestNostrKeyUsecase _recordNostrKey;
  final RestoreKeychainManifestNostrKeyUsecase _restoreNostrKey;
  final UpdatePassphraseLabelHintUsecase _updateLabelHint;
  final RemovePassphraseWalletUsecase _removeWallet;

  KeychainManifestFacade(
    this._watchChanges,
    this._encode,
    this._build,
    this._parse,
    this._replaceSeedInventory,
    this._recordWallet,
    this._restoreSnapshot,
    this._recordNostrKey,
    this._restoreNostrKey,
    this._updateLabelHint,
    this._removeWallet,
  );

  Stream<void> watchCommittedChanges() => _watchChanges.execute();

  @useResult
  Future<Result<KeychainManifest, KeychainManifestFailure>> readManifest(
    Fingerprint parentFingerprint,
  ) => _build.execute(parentFingerprint);

  @useResult
  Future<Result<KeychainManifest, KeychainManifestFailure>> buildManifest(
    Fingerprint parentFingerprint, {
    bool allowEmpty = false,
  }) async => switch (await _build.execute(parentFingerprint)) {
    Err(:final failure) => Err(failure),
    Ok(:final value) when value.entries.isEmpty && !allowEmpty => const Err(
      KeychainManifestEmptyFailure(),
    ),
    Ok(:final value) => Ok(value),
  };

  String encodeManifestFilePayload(KeychainManifest manifest) =>
      _encode(manifest);

  @useResult
  Result<KeychainManifest, KeychainManifestFailure> parseManifestFilePayload(
    String payload, {
    required Fingerprint expectedParentFingerprint,
    bool allowEmpty = false,
  }) => _parse.execute(
    payload,
    expectedParentFingerprint: expectedParentFingerprint,
    allowEmpty: allowEmpty,
  );

  @useResult
  Future<Result<bool, KeychainManifestFailure>> replaceSeedWalletInventory({
    required Fingerprint parentFingerprint,
    required List<KeychainManifestWalletInventoryBinding> wallets,
  }) => _replaceSeedInventory.execute(
    parentFingerprint: parentFingerprint,
    wallets: wallets,
  );

  @useResult
  Future<Result<bool, KeychainManifestFailure>> recordWallet({
    required Fingerprint parentFingerprint,
    required KeychainManifestWalletInventoryBinding wallet,
  }) => _recordWallet.execute(
    parentFingerprint: parentFingerprint,
    wallet: wallet,
  );

  @useResult
  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  restoreSnapshot(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy =
        KeychainManifestRestorePolicy.keepNewest,
  }) => _restoreSnapshot.execute(manifest, policy: policy);

  @useResult
  Future<Result<void, KeychainManifestFailure>> updatePassphraseLabelHint({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
  }) => _updateLabelHint.execute(
    parentFingerprint: parentFingerprint,
    walletId: walletId,
    label: label,
    hint: hint,
  );

  @useResult
  Future<Result<void, KeychainManifestFailure>> deleteWallet({
    required Fingerprint parentFingerprint,
    required String walletId,
  }) => _removeWallet.execute(
    parentFingerprint: parentFingerprint,
    walletId: walletId,
  );

  @useResult
  Future<Result<bool, KeychainManifestFailure>> recordWalletBackupNostrKey({
    required Fingerprint parentFingerprint,
    required String publicKeyHex,
    required DateTime now,
  }) => _recordNostrKey.execute(
    reservationId: Bip85Reservations.nostrWalletBackupKey.id,
    parentFingerprint: parentFingerprint,
    derivationPath: Bip85Reservations.nostrWalletBackupKey.path,
    publicKeyHex: publicKeyHex,
    keyKind: KeychainManifestNostrKeyKind.reserved,
    purpose: 'Wallet backup',
    now: now,
  );

  @useResult
  Future<Result<bool, KeychainManifestFailure>> restoreNostrKey({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => _restoreNostrKey.execute(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    publicKeyHex: publicKeyHex,
    keyKind: keyKind,
    purpose: purpose,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
