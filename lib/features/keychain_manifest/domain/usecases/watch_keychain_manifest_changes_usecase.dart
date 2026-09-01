import 'dart:async';

import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';

final class WatchKeychainManifestChangesUsecase {
  final KeychainManifestRepository _repository;

  const WatchKeychainManifestChangesUsecase(this._repository);

  Stream<void> execute() => _repository.watchLocalChanges();
}
