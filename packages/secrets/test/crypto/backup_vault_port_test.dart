import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/backup_vault_port_impl.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/seed_repository_impl.dart';
import 'package:secrets/src/domain/seed_index.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

class _FakeSeedIndex implements SeedIndex {
  final Map<String, SeedInfo> _m = {};
  @override
  Future<List<SeedInfo>> all() async => _m.values.toList();
  @override
  Future<SeedInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SeedInfo info) async => _m[info.fingerprint.hex] = info;
}

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

void main() {
  late FssSecretStore store;
  late SeedRepositoryImpl repo;
  late BackupVaultPortImpl vaultPort;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    store = FssSecretStore(kv, initialRetryDelay: Duration.zero);
    repo = SeedRepositoryImpl(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    vaultPort = BackupVaultPortImpl(store: store, repository: repo);
  });

  test('encrypt → restore round-trips to the same fingerprint', () async {
    final enc = _unwrap(await vaultPort.encryptVault(seed: zooFp));
    expect(enc.vaultKey.bytes.length, greaterThanOrEqualTo(32));

    // Wipe the seed so restore must re-import it from the vault.
    await repo.delete(zooFp);
    expect(_unwrap(await repo.exists(zooFp)), isFalse);

    final fps = _unwrap(await vaultPort.restoreVault(
      vault: enc.vault,
      vaultKey: enc.vaultKey,
    ));
    expect(fps, [zooFp]);
    expect(_unwrap(await repo.exists(zooFp)), isTrue);
  });

  test('restore with a wrong key → VaultFailure (no crash)', () async {
    final enc = _unwrap(await vaultPort.encryptVault(seed: zooFp));
    final res = await vaultPort.restoreVault(
      vault: enc.vault,
      vaultKey: BackupKey(Uint8List.fromList(List.filled(32, 0))),
    );
    expect((res as Err).failure, isA<VaultFailure>());
  });

  test('encrypt of a missing seed → SeedNotFoundFailure', () async {
    final res = await vaultPort.encryptVault(seed: Fingerprint('00000000'));
    expect((res as Err).failure, isA<SeedNotFoundFailure>());
  });
}
