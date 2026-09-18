import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:meta/meta.dart';

export '../domain/entities/nostr_key_record.dart';
export '../domain/entities/backup_identity_record.dart';
export '../domain/keychain_manifest_failure.dart';
export '../ui/keychain_manifest_router.dart' show KeychainManifestRouter;

class KeychainManifestFacade {
  static const nostrKeysRouteName = 'nostrKeys';

  final GetNostrKeysUsecase _getNostrKeys;
  final RestoreNostrKeyUsecase _restoreNostrKey;
  final WatchNostrKeysUsecase _watchNostrKeys;

  const KeychainManifestFacade(
    this._getNostrKeys,
    this._restoreNostrKey,
    this._watchNostrKeys,
  );

  @useResult
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>>
  getNostrKeys() => _getNostrKeys.execute();

  @useResult
  Future<Result<void, KeychainManifestFailure>> restoreNostrKey(
    NostrKeyRecord record,
  ) => _restoreNostrKey.execute(record);

  Stream<void> watchNostrKeys() => _watchNostrKeys.execute();
}
