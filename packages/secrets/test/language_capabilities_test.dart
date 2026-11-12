import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bwk.dart' show SpNetwork;
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  setUp(() => FakeSecureStoragePlatform().install());

  // Liquid and swap keys derive from the seed, so every language reaches
  // them; their vectors need the FFI and live in
  // integration_test/secrets_derivation_vectors_test.dart. bwk still builds
  // a Silent Payments account from English words only.
  for (final language in bip39.Language.values.where(
    (l) => l != bip39.Language.english,
  )) {
    test(
      '${language.name} refuses Silent Payments before native calls',
      () async {
        final secrets = Secrets(scratchDirectory: () async => '/tmp');
        final words = bip39.Mnemonic(List.filled(16, 0), language).words;
        final secret = ok(
          await secrets.import(words: words, language: language),
        );
        expect(
          err(
            await secret.silentPayments.account(
              name: 'test',
              network: SpNetwork.bitcoin,
              blindbitUrl: '',
              electrumUrl: '',
              dataDir: '/tmp',
              dustLimit: BigInt.zero,
              fetchConcurrencyFactor: 1,
              matchConcurrencyFactor: 1,
            ),
          ),
          isA<LanguageUnsupportedFailure>(),
        );
      },
    );
  }
}
