import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bwk.dart';
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Account extends Mock implements SpAccount {}

class _FailingNativeApi implements BullSdkApi {
  int calls = 0;
  List<int>? seed;
  List<int>? passedBuffer;
  SpAccount? account;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    final value = invocation.namedArguments[#seed];
    if (value is List<int>) {
      passedBuffer = value;
      seed = List<int>.of(value);
    }
    if (account case final value?) return Future<SpAccount>.value(value);
    throw Exception('untrusted native error');
  }
}

void main() {
  final api = _FailingNativeApi();
  setUpAll(() => BullSdk.initMock(api: api));
  tearDownAll(BullSdk.dispose);
  setUp(() {
    FakeSecureStoragePlatform().install();
    api.calls = 0;
    api.seed = null;
    api.passedBuffer = null;
    api.account = null;
  });

  for (final vector in [
    for (final language in bip39.Language.values)
      for (final passphrase in ['', 'TREZOR'])
        (language: language, passphrase: passphrase),
  ]) {
    test('${vector.language.name} with passphrase '
        '${vector.passphrase.isNotEmpty} reaches native boundary', () async {
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final words = bip39.Mnemonic(List.filled(16, 0), vector.language).words;
      final imported = await secrets.import(
        words: words,
        language: vector.language,
        passphrase: vector.passphrase,
      );
      final secret = (imported as Ok<Secret, SecretFailure>).value;
      final expected = bip39.Mnemonic(
        List.filled(16, 0),
        vector.language,
        passphrase: vector.passphrase,
      ).seed;
      try {
        final result = await secret.silentPayments.account(
          name: 'test',
          network: SpNetwork.signet,
          blindbitUrl: '',
          electrumUrl: '',
          dataDir: '/tmp',
          dustLimit: BigInt.zero,
          fetchConcurrencyFactor: 1,
          matchConcurrencyFactor: 1,
        );
        expect(result, isA<Err<SpAccount, SecretFailure>>());
        final failure = (result as Err<SpAccount, SecretFailure>).failure;
        expect(failure, isA<UseSecretFailure>());
        expect(failure.toString(), isNot(contains('untrusted native error')));
        expect(api.calls, 1);
        expect(api.seed, isNotNull);
        expect(api.passedBuffer, isNotNull);
        expect(
          api.seed!.length == expected.length &&
              List.generate(
                expected.length,
                (i) => api.seed![i] == expected[i],
              ).every((match) => match),
          isTrue,
          reason: 'native boundary receives the full BIP39 seed',
        );
        expect(
          api.passedBuffer!.length == 64 &&
              api.passedBuffer!.every((byte) => byte == 0),
          isTrue,
          reason: 'the transferred Dart buffer is wiped after the call',
        );
      } finally {
        api.seed?.fillRange(0, api.seed!.length, 0);
        expected.fillRange(0, expected.length, 0);
      }
    });
  }

  test('wipes the seed buffer after a successful native call', () async {
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final mnemonic = bip39.Mnemonic(List.filled(16, 0), bip39.Language.english);
    final imported = await secrets.import(words: mnemonic.words);
    final secret = (imported as Ok<Secret, SecretFailure>).value;
    final account = _Account();
    api.account = account;
    final expected = mnemonic.seed;
    try {
      final result = await secret.silentPayments.account(
        name: 'test',
        network: SpNetwork.signet,
        blindbitUrl: '',
        electrumUrl: '',
        dataDir: '/tmp',
        dustLimit: BigInt.zero,
        fetchConcurrencyFactor: 1,
        matchConcurrencyFactor: 1,
      );
      expect(result, isA<Ok<SpAccount, SecretFailure>>());
      expect((result as Ok<SpAccount, SecretFailure>).value, same(account));
      expect(api.calls, 1);
      expect(api.seed, isNotNull);
      expect(api.passedBuffer, isNotNull);
      expect(
        api.seed!.length == expected.length &&
            List.generate(
              expected.length,
              (i) => api.seed![i] == expected[i],
            ).every((match) => match),
        isTrue,
        reason: 'native boundary receives the full BIP39 seed',
      );
      expect(
        api.passedBuffer!.length == 64 &&
            api.passedBuffer!.every((byte) => byte == 0),
        isTrue,
        reason: 'the transferred Dart buffer is wiped after success',
      );
    } finally {
      api.seed?.fillRange(0, api.seed!.length, 0);
      expected.fillRange(0, expected.length, 0);
    }
  });
}
