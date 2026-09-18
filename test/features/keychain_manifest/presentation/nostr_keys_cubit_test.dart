import 'dart:async';

import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Defaults extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Identities extends Mock implements NostrIdentityFacade {}

class _Keys extends Fake implements NostrKeyRepository {
  final updates = StreamController<void>.broadcast();
  KeychainManifestFailure? failure;
  int reads = 0;
  @override
  Stream<void> get changes => updates.stream;
  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>> getAll() async {
    reads++;
    return failure == null ? const Ok([]) : Err(failure!);
  }
}

void main() {
  late _Keys keys;
  late _Defaults defaults;
  late _Identities identities;
  late NostrKeysCubit cubit;
  setUp(() {
    keys = _Keys();
    defaults = _Defaults();
    identities = _Identities();
    cubit = NostrKeysCubit(
      getKeys: GetNostrKeysUsecase(keys),
      watchKeys: WatchNostrKeysUsecase(keys),
      createKey: CreateNostrKeyUsecase(defaults, _Settings(), keys),
      getBackupIdentities: GetBackupIdentitiesUsecase(identities),
    );
  });
  tearDown(() async {
    await cubit.close();
    await keys.updates.close();
  });
  test(
    'normal listing reads public inventory and reports storage failures',
    () async {
      await cubit.load();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.failure, isNull);
      verifyZeroInteractions(defaults);
      verifyZeroInteractions(identities);
      keys.failure = const KeychainManifestStorageFailure();
      await cubit.load();
      expect(cubit.state.failure, isA<KeychainManifestStorageFailure>());
    },
  );
  test('hiding system keys ignores a late identity lookup', () async {
    final pending = Completer<Result<BackupCredential, NostrIdentityFailure>>();
    when(() => identities.resolve()).thenAnswer((_) => pending.future);
    final show = cubit.showSystemKeys();
    cubit.hideSystemKeys();
    pending.complete(const Err(BackupCredentialUnavailable()));
    await show;
    expect(cubit.state.systemKeys, isNull);
    expect(cubit.state.loadingSystem, isFalse);
    expect(cubit.state.failure, isNull);
  });
  test('inventory updates refresh a mounted list', () async {
    await cubit.load();
    keys.updates.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(keys.reads, 2);
  });
}
