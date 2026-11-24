import 'package:ark/ark.dart';
import 'package:bull_ark/ark_wallet_setup.dart' show WalletArkExitDestination;
import 'package:bull_ark/ark_setup.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );

  test(
    'the address comes from the wallet the Ark account belongs to',
    () async {
      final asked = <Object>[];
      final destination = WalletArkExitDestination(
        sourceWallet: (id) async {
          asked.add(id);
          return const Ok('secure-wallet');
        },
        nextAddress: (walletId) async {
          asked.add(walletId);
          return const Ok('bcrt1qfresh');
        },
      );
      expect(
        await destination.secureBitcoinAddress(account),
        isA<Ok<String, ArkFailure>>().having(
          (r) => r.value,
          'value',
          'bcrt1qfresh',
        ),
      );
      expect(asked, [account, 'secure-wallet']);
    },
  );

  test('a changed wallet selection keeps its own failure', () async {
    var addresses = 0;
    final destination = WalletArkExitDestination(
      sourceWallet: (_) async => const Err(ArkDisabledFailure()),
      nextAddress: (_) async {
        addresses++;
        return const Ok('never');
      },
    );
    expect(
      await destination.secureBitcoinAddress(account),
      isA<Err<String, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkDisabledFailure>(),
      ),
    );
    expect(addresses, 0);
  });

  test('a wallet that cannot issue an address says why', () async {
    final destination = WalletArkExitDestination(
      sourceWallet: (_) async => const Ok('secure-wallet'),
      // The app maps its wallet's failure to an Ark one.
      nextAddress: (_) async => const Err(ArkServiceUnavailableFailure()),
    );
    expect(
      await destination.secureBitcoinAddress(account),
      isA<Err<String, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkServiceUnavailableFailure>(),
      ),
    );
  });
}
