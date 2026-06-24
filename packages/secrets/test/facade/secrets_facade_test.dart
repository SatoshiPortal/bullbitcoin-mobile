import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';

import '../data/fake_secure_key_value_store.dart';

/// In-memory [SecretIndexPort] backed by a fingerprint-keyed map.
class _FakeIndex implements SecretIndexPort {
  final Map<String, SecretInfo> _m = {};

  @override
  Future<void> upsert(SecretInfo info) async => _m[info.fingerprint.hex] = info;

  @override
  Future<List<SecretInfo>> all() async => _m.values.toList();

  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _m[fp.hex];

  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
}

void main() {
  // The standard BIP39 test vector (valid 12-word checksum).
  const words = <String>[
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  setUp(() {
    Secrets.init(
      index: _FakeIndex(),
      store: FssSecretStoreAdapter(FakeSecureKeyValueStore()),
    );
  });

  tearDown(Secrets.reset);

  test('import → fetch → derive round-trip', () async {
    // import returns a typed MnemonicSecret handle
    final imported = await Secrets.importMnemonic(words);
    expect(imported, isA<Ok<MnemonicSecret, SecretsFailure>>());
    final mnemonic = (imported as Ok<MnemonicSecret, SecretsFailure>).value;
    expect(mnemonic.wordCount, 12);

    final fp = mnemonic.fingerprint;

    // fetch resolves the kind from the index and returns the subtype
    final fetched = await Secrets.fetch(fp);
    expect(fetched, isA<Ok<Secret, SecretsFailure>>());
    final secret = (fetched as Ok<Secret, SecretsFailure>).value;
    expect(secret, isA<MnemonicSecret>());

    // capability on the handle
    final desc = await secret.bitcoinDescriptor(
      scriptType: ScriptType.bip84,
      network: BitcoinNetwork.mainnet,
    );
    expect(desc, isA<Ok<BitcoinDescriptor, SecretsFailure>>());

    // registry sees exactly one
    final listed = await Secrets.list();
    expect(listed, isA<Ok<List<Secret>, SecretsFailure>>());
    expect((listed as Ok<List<Secret>, SecretsFailure>).value, hasLength(1));

    // unknown fingerprint → SecretNotFoundFailure
    final unknown = await Secrets.fetch(Fingerprint('deadbeef'));
    expect(unknown, isA<Err<Secret, SecretsFailure>>());
    expect(
      (unknown as Err<Secret, SecretsFailure>).failure,
      isA<SecretNotFoundFailure>(),
    );
  });
}
