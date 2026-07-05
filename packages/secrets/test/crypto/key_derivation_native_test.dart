@Tags(['native'])
library;
// Native (bdk) integration test — the bdk FFI lib loads under `flutter test` on
// this host, so the previously-untested public-key/descriptor derivation path
// is exercised for real here (not just the pure logic).
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/key_derivation_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

class _FakeSeedIndex implements SecretIndexPort {
  final Map<String, SecretInfo> _m = {};
  @override
  Future<List<SecretInfo>> all() async => _m.values.toList();
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SecretInfo info) async => _m[info.fingerprint.hex] = info;
}

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

void main() {
  late KeyDerivationAdapter kd;
  late SecretLifecycleAdapter repo;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    repo = SecretLifecycleAdapter(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    kd = KeyDerivationAdapter(store);
  });

  test('masterFingerprint round-trips to the stored handle', () async {
    final fp = _unwrap(await kd.masterFingerprint(zooFp));
    expect(fp, zooFp);
  });

  test('accountXpub (testnet bip84) derives a deterministic vpub', () async {
    final xpub = _unwrap(await kd.accountXpub(
      fingerprint: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    ));
    expect(xpub.type, XpubType.vpub);
    expect(xpub.value, startsWith('vpub'));
    // Determinism.
    final again = _unwrap(await kd.accountXpub(
      fingerprint: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    ));
    expect(again.value, xpub.value);
  });

  test('bitcoinDescriptor returns distinct external/internal wpkh descriptors',
      () async {
    final d = _unwrap(await kd.bitcoinDescriptor(
      fingerprint: zooFp,
      scriptType: ScriptType.bip84,
      isTestnet: true,
    ));
    expect(d.external, contains('wpkh'));
    expect(d.internal, contains('wpkh'));
    expect(d.external, isNot(d.internal)); // external (0/*) != change (1/*)
    // SEAL: the descriptor is built from an xprv but MUST stringify to the
    // PUBLIC (watch-only) form — the root xprv must never leak into wallet
    // metadata/logs. A bdk_dart bump that flips toString() to the secret form
    // (or the guard failing to fire) turns these red. tprv/xprv are the only
    // "prv" a descriptor can carry; testnet uses tpub.
    expect(d.external, isNot(contains('prv')));
    expect(d.internal, isNot(contains('prv')));
    expect(d.external, contains('tpub')); // testnet public key material
    expect(d.internal, contains('tpub'));
  });

  test('missing seed → SecretNotFoundFailure (native path still typed)',
      () async {
    final res = await kd.accountXpub(
      fingerprint: Fingerprint('00000000'),
      scriptType: ScriptType.bip84,
      isTestnet: true,
      account: 0,
    );
    expect((res as Err).failure, isA<SecretNotFoundFailure>());
  });

  test('liquidDescriptor REJECTS a passphrase wallet (would derive a wallet it '
      'cannot sign for)', () async {
    // LWK derives from the bare mnemonic, so a hasPassphrase seed would yield
    // the bare-seed Liquid wallet under this passphrase-scoped handle — a
    // wallet the signer then refuses to sign for. The check fails closed BEFORE
    // any native LWK call, so this is sound even on the pure path.
    final withPass =
        _unwrap(await repo.importMnemonic(words: zooWords, passphrase: 'trezor'));
    expect(withPass, isNot(zooFp)); // distinct fingerprint from the bare seed
    final res = await kd.liquidDescriptor(fingerprint: withPass, isTestnet: true);
    expect((res as Err).failure, isA<DerivationFailure>());
  });
}
