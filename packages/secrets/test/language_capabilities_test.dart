import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_sdk/bwk.dart' show SpNetwork;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

void main() {
  setUp(() => FakeSecureStoragePlatform().install());

  for (final language in bip39.Language.values.where(
    (l) => l != bip39.Language.english,
  )) {
    test(
      '${language.name} refuses word-only engines before native calls',
      () async {
        var scratchCalls = 0;
        final secrets = Secrets(
          scratchDirectory: () async {
            scratchCalls++;
            return '/tmp';
          },
        );
        final words = bip39.Mnemonic(List.filled(16, 0), language).words;
        final secret = ok(
          await secrets.import(words: words, language: language),
        );
        final before = scratchCalls;
        expect(
          err(
            await secret.derive.descriptors.liquid(
              network: LiquidNetwork.mainnet,
            ),
          ),
          isA<LanguageUnsupportedFailure>(),
        );
        expect(
          err(
            await secret.sign.pset('invalid', network: LiquidNetwork.mainnet),
          ),
          isA<LanguageUnsupportedFailure>(),
        );
        expect(scratchCalls, before);
        expect(
          err(await secret.derive.swapKey(network: BitcoinNetwork.mainnet)),
          isA<LanguageUnsupportedFailure>(),
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
