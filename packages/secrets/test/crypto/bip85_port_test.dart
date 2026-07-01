import 'package:convert/convert.dart' as conv;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/bip85_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];
const recoverbullKeyForPath =
    '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';
const arkSecretForZooSeed =
    'a30097fcca0406e6003b46b0a8ac5e4af856bf0d31f901b2f580df7d3f5395a3';

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
  late FssSecretStoreAdapter store;
  late Bip85Adapter bip85;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    final repo = SecretLifecycleAdapter(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    bip85 = Bip85Adapter(store);
  });

  test('deriveRecoverbullKey matches the frozen KAT vector', () async {
    final key = _unwrap(await bip85.deriveRecoverbullKey(
      fingerprint: zooFp,
      path: Bip85Path("1608'/0'/586053381"),
    ));
    expect(conv.hex.encode(key.bytes), recoverbullKeyForPath);
  });

  test('deriveChildMnemonic returns the right path + 12 words', () async {
    final d = _unwrap(await bip85.deriveChildMnemonic(
      fingerprint: zooFp,
      length: MnemonicLength.words12,
      index: 0,
    ));
    expect(d.path.path, "39'/0'/12'/0'");
    expect(d.words, hasLength(12));
  });

  test('deriveArkSecret matches the frozen vector', () async {
    final ark = _unwrap(await bip85.deriveArkSecret(fingerprint: zooFp));
    expect(conv.hex.encode(ark.bytes), arkSecretForZooSeed);
  });

  test('deriveHex returns the requested byte length', () async {
    final hexRes = _unwrap(await bip85.deriveHex(
      fingerprint: zooFp,
      numBytes: 16,
      index: 0,
    ));
    expect(hexRes.hexForView.length, 32); // 16 bytes = 32 hex chars
  });

  test('missing seed → SecretNotFoundFailure (not locked, not a crash)', () async {
    final res = await bip85.deriveArkSecret(fingerprint: Fingerprint('00000000'));
    expect((res as Err).failure, isA<SecretNotFoundFailure>());
  });
}
