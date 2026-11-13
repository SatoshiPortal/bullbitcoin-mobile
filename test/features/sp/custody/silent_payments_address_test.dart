import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bwk.dart';
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _AddressApi implements BullSdkApi {
  List<int>? copy;
  List<int>? buffer;
  bool fail = false;
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    final seed = invocation.namedArguments[#seed];
    if (seed is List<int>) {
      buffer = seed;
      copy = List<int>.of(seed);
    }
    if (fail) throw Exception('untrusted native message');
    return Future<String>.value('public-address');
  }
}

void main() {
  final api = _AddressApi();
  setUpAll(() => BullSdk.initMock(api: api));
  tearDownAll(BullSdk.dispose);
  setUp(() {
    FakeSecureStoragePlatform().install();
    api.calls = 0;
    api.copy = null;
    api.buffer = null;
    api.fail = false;
  });

  for (final fails in [false, true]) {
    test(
      'address derives from seed and wipes buffer (failure: $fails)',
      () async {
        final mnemonic = bip39.Mnemonic(
          List.filled(16, 0),
          bip39.Language.french,
          passphrase: 'TREZOR',
        );
        final secrets = Secrets(scratchDirectory: () async => '/tmp');
        final imported = await secrets.import(
          words: mnemonic.words,
          language: mnemonic.language,
          passphrase: mnemonic.passphrase,
        );
        final secret = (imported as Ok<Secret, SecretFailure>).value;
        final expected = mnemonic.seed;
        api.fail = fails;
        try {
          final result = await secret.silentPayments.address(
            network: SpNetwork.signet,
          );
          if (fails) {
            expect(result, isA<Err<String, SecretFailure>>());
            final failure = (result as Err<String, SecretFailure>).failure;
            expect(failure, isA<UseSecretFailure>());
            expect(
              failure.toString(),
              isNot(contains('untrusted native message')),
            );
          } else {
            expect(
              (result as Ok<String, SecretFailure>).value,
              'public-address',
            );
          }
          expect(api.calls, 1);
          expect(api.copy, isNotNull);
          expect(api.buffer, isNotNull);
          expect(
            api.copy!.length == expected.length &&
                List.generate(
                  expected.length,
                  (i) => api.copy![i] == expected[i],
                ).every((match) => match),
            isTrue,
          );
          expect(
            api.buffer!.length == 64 && api.buffer!.every((b) => b == 0),
            isTrue,
          );
        } finally {
          api.copy?.fillRange(0, api.copy!.length, 0);
          expected.fillRange(0, expected.length, 0);
        }
      },
    );
  }
}
