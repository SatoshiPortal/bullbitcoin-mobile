import 'dart:async';

import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Identities extends Mock implements NostrIdentityFacade {}

class _Keys extends Fake implements NostrKeyRepository {
  final updates = StreamController<void>.broadcast();
  KeychainManifestFailure? failure;
  List<NostrKeyRecord> records = const [];
  @override
  Stream<void> get changes => updates.stream;
  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>> getAll() async {
    return failure == null ? Ok(records) : Err(failure!);
  }
}

void main() {
  late _Keys keys;
  late _Identities identities;
  late NostrKeysCubit cubit;
  setUp(() {
    keys = _Keys();
    identities = _Identities();
    cubit = NostrKeysCubit(
      getKeys: GetNostrKeysUsecase(keys),
      watchKeys: WatchNostrKeysUsecase(keys),
      createKey: CreateNostrKeyUsecase(identities, keys),
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
    keys.records = [
      NostrKeyRecord(
        parentFingerprint: 'aabbccdd',
        identity: 1,
        publicKey: '11' * 32,
        purpose: 'Personal identity',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    keys.updates.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.keys, keys.records);
  });
}
