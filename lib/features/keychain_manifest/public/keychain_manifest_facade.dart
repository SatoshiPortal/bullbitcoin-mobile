import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_keychain_manifest_reservation_wallet_ids_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/merge_keychain_manifest_file_payloads_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_reserved_wallets_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart'
    show
        KeychainManifestImportPlan,
        KeychainManifestNostrKeyKind,
        KeychainManifestEntry,
        KeychainManifestWallet,
        KeychainManifestNostrKey;
export 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart'
    show KeychainManifestWalletBinding;
export 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
export 'package:bb_mobile/features/keychain_manifest/keychain_manifest_locator.dart';
export 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';

final class KeychainManifestFacade {
  final WatchKeychainManifestChangesUsecase _watchChanges;
  final KeychainManifestFileCodec _codec;
  final BuildKeychainManifestFileUsecase _build;
  final ParseKeychainManifestFileUsecase _parse;
  final MergeKeychainManifestFilePayloadsUsecase _merge;
  final RecordReservedWalletsUsecase _recordWallets;
  final RecordKeychainManifestNostrKeyUsecase _recordNostrKey;
  final GetKeychainManifestReservationWalletIdsUsecase _walletIds;

  KeychainManifestFacade(
    this._watchChanges,
    this._codec,
    this._build,
    this._parse,
    this._merge,
    this._recordWallets,
    this._recordNostrKey,
    this._walletIds,
  );

  Stream<void> watchCommittedChanges() => _watchChanges.execute();

  Future<Result<String, KeychainManifestFailure>> buildManifestFilePayload(
    Fingerprint parentFingerprint, {
    bool allowEmpty = false,
  }) async => switch (await _build.execute(parentFingerprint)) {
    Err(:final failure) => Err(failure),
    Ok(:final value) when value.entries.isEmpty && !allowEmpty => const Err(
      KeychainManifestEmptyFailure(),
    ),
    Ok(:final value) => Ok(_codec.encode(value)),
  };

  Result<KeychainManifestImportPlan, KeychainManifestFailure>
  parseManifestFilePayload(
    String payload, {
    required Fingerprint expectedParentFingerprint,
    bool allowEmpty = false,
  }) => _parse.execute(
    payload,
    expectedParentFingerprint: expectedParentFingerprint,
    allowEmpty: allowEmpty,
  );

  Result<String, KeychainManifestFailure> mergeManifestFilePayloads({
    required String localPayload,
    required String remotePayload,
    required Fingerprint expectedParentFingerprint,
    required int generatedAt,
  }) => _merge
      .execute(
        localPayload: localPayload,
        remotePayload: remotePayload,
        expectedParentFingerprint: expectedParentFingerprint,
        generatedAt: generatedAt,
      )
      .map(_codec.encode);

  Result<String, KeychainManifestFailure> canonicalizeManifestFilePayload(
    String payload,
  ) => _codec.decode(payload).map(_codec.encode);

  Future<Result<List<String>, KeychainManifestFailure>> reservationWalletIds({
    required Fingerprint parentFingerprint,
    required String reservationId,
  }) => _walletIds.execute(
    parentFingerprint: parentFingerprint,
    reservationId: reservationId,
  );

  Future<Result<bool, KeychainManifestFailure>> recordReservedDerivation({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required List<KeychainManifestWalletBinding> wallets,
  }) => _recordWallets.execute(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    wallets: wallets,
    origin: KeychainManifestWriteOrigin.local,
  );

  Future<Result<bool, KeychainManifestFailure>> recordRecoveredDerivation({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required List<KeychainManifestWalletBinding> wallets,
  }) => _recordWallets.execute(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    wallets: wallets,
    origin: KeychainManifestWriteOrigin.recovery,
  );

  Future<Result<bool, KeychainManifestFailure>> recordNostrKey({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
  }) => _recordNostrKey.execute(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    publicKeyHex: publicKeyHex,
    keyKind: keyKind,
    purpose: purpose,
    description: description,
    origin: KeychainManifestWriteOrigin.local,
  );

  Future<Result<bool, KeychainManifestFailure>> recordRecoveredNostrKey({
    required String reservationId,
    required Fingerprint parentFingerprint,
    required String derivationPath,
    required String publicKeyHex,
    required KeychainManifestNostrKeyKind keyKind,
    required String purpose,
    String? description,
    DateTime? updatedAt,
  }) => _recordNostrKey.execute(
    reservationId: reservationId,
    parentFingerprint: parentFingerprint,
    derivationPath: derivationPath,
    publicKeyHex: publicKeyHex,
    keyKind: keyKind,
    purpose: purpose,
    description: description,
    updatedAt: updatedAt,
    origin: KeychainManifestWriteOrigin.recovery,
  );
}
