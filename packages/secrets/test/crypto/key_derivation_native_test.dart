@Tags(['native'])
library;
// Native (bdk) integration test — the bdk FFI lib loads under `flutter test` on
// this host, so the previously-untested public-key/descriptor derivation path
// is exercised for real here (not just the pure logic).
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/key_derivation_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/seed_adapter.dart';
import 'package:secrets/src/domain/ports/seed_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

class _FakeSeedIndex implements SeedIndexPort {
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
  late KeyDerivationAdapter kd;
  late SeedAdapter repo;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    repo = SeedAdapter(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    kd = KeyDerivationAdapter(store);
  });

  test('masterFingerprint round-trips to the stored handle', () async {
    final fp = _unwrap(await kd.masterFingerprint(zooFp));
    expect(fp, zooFp);
  });

  test('accountXpub (testnet bip84) derives a deterministic vpub', () async {
    final xpub = _unwrap(await kd.accountXpub(
      seed: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    ));
    expect(xpub.type, XpubType.vpub);
    expect(xpub.value, startsWith('vpub'));
    // Determinism.
    final again = _unwrap(await kd.accountXpub(
      seed: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    ));
    expect(again.value, xpub.value);
  });

  test('bitcoinDescriptor returns distinct external/internal wpkh descriptors',
      () async {
    final d = _unwrap(await kd.bitcoinDescriptor(
      seed: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
    ));
    expect(d.external, contains('wpkh'));
    expect(d.internal, contains('wpkh'));
    expect(d.external, isNot(d.internal)); // external (0/*) != change (1/*)
  });

  test('missing seed → SeedNotFoundFailure (native path still typed)',
      () async {
    final res = await kd.accountXpub(
      seed: Fingerprint('00000000'),
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    );
    expect((res as Err).failure, isA<SeedNotFoundFailure>());
  });
}
