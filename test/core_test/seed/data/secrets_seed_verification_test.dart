import 'package:bb_mobile/core/seed/data/secrets_seed_verification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches the full account xpub to the stored secret', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '');
    final secret =
        (await secrets.import(
                  words:
                      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                          .split(' '),
                )
                as Ok<Secret, SecretFailure>)
            .value;
    final account =
        (await secret.derive.account(
                  derivationPath: "m/48'/1'/0'/2'",
                  network: BitcoinNetwork.testnet,
                )
                as Ok<PublicAccountKey, SecretFailure>)
            .value;
    final verification = SecretsSeedVerification(secrets);

    expect(
      await verification.matchesXpubs(
        fingerprint: secret.id.hex,
        keys: [(derivationPath: "m/48'/1'/0'/2'", xpub: account.xpub)],
      ),
      isTrue,
    );
    expect(
      await verification.matchesXpubs(
        fingerprint: secret.id.hex,
        keys: [(derivationPath: "m/48'/1'/1'/2'", xpub: account.xpub)],
      ),
      isFalse,
    );
  });
}
