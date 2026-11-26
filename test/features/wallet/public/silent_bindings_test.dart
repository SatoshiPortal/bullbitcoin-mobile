import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:silent/setup.dart';

class _Inventory extends Mock implements WalletInventory {}

void main() {
  test(
    'the Silent fingerprint is resolved on exactly the requested network',
    () async {
      final inventory = _Inventory();
      final fingerprint = Fingerprint('aabbccdd');
      when(() => inventory.walletsForNetwork(BitcoinNetwork.testnet))
          .thenAnswer(
            (_) async => Ok(
              walletSelectionForTesting([
                walletRegistrationForTesting(
                  id: 'testnet-wallet',
                  network: BitcoinNetwork.testnet,
                  isDefault: true,
                  signer: WalletSigner.local,
                  masterFingerprint: fingerprint,
                  secretFingerprint: fingerprint,
                ),
              ]),
            ),
          );
      when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
          .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
      final lookup = readSilentDefaultFromInventory(inventory);
      expect(
        (await lookup(BitcoinNetwork.testnet))
            .fold((value) => value, (_) => null),
        fingerprint,
      );
      expect(
        await lookup(BitcoinNetwork.mainnet),
        isA<Ok<Fingerprint?, Failure>>().having(
          (result) => result.value,
          'fingerprint',
          isNull,
        ),
      );
      expect(
        await lookup(BitcoinNetwork.regtest),
        isA<Ok<Fingerprint?, Failure>>().having(
          (result) => result.value,
          'fingerprint',
          isNull,
        ),
      );
      verifyNever(() => inventory.walletsForNetwork(BitcoinNetwork.regtest));
    },
  );

  test('storage errors are not missing wallets', () async {
    final inventory = _Inventory();
    when(() => inventory.walletsForNetwork(BitcoinNetwork.testnet))
        .thenAnswer((_) async => const Err(FetchSecretFailure()));
    final lookup = readSilentDefaultFromInventory(inventory);
    expect(
      await lookup(BitcoinNetwork.testnet),
      isA<Err<Fingerprint?, Failure>>(),
    );
  });
}
