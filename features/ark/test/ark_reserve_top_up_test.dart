import 'package:ark/ark.dart';
import 'package:bull_ark/ark_wallet_setup.dart'
    show DeferredArkReserveTopUp, WalletArkReserveTopUp;
import 'package:bull_ark/ark_setup.dart';
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );

  ({WalletArkReserveTopUp topUp, List<String> steps}) rig({
    Result<String, ArkFailure> source = const Ok('secure'),
    Result<String, ArkFailure> sent = const Ok('txid'),
  }) {
    final steps = <String>[];
    return (
      steps: steps,
      topUp: WalletArkReserveTopUp(
        sourceWallet: (_) async {
          steps.add('source');
          return source;
        },
        send: (walletId, address, amount) async {
          steps.add('send $walletId $address ${amount.value}');
          return sent;
        },
      ),
    );
  }

  test("sends from the account's own wallet to the reserve", () async {
    final r = rig();
    final result = await r.topUp.topUp(
      account,
      address: 'bcrt1preserve',
      amount: Sats.fromInt(3500),
    );
    expect(
      result,
      isA<Ok<String, ArkFailure>>().having((r) => r.value, 'txid', 'txid'),
    );
    expect(r.steps, ['source', 'send secure bcrt1preserve 3500']);
  });

  test('an unaffordable top-up reports insufficient funds', () async {
    final r = rig(sent: const Err(ArkPaymentInsufficientFundsFailure()));
    expect(
      await r.topUp.topUp(
        account,
        address: 'bcrt1preserve',
        amount: Sats.fromInt(3500),
      ),
      isA<Err<String, ArkFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ArkPaymentInsufficientFundsFailure>(),
      ),
    );
  });

  test('a changed wallet selection sends nothing', () async {
    final r = rig(source: const Err(ArkDisabledFailure()));
    expect(
      await r.topUp.topUp(
        account,
        address: 'bcrt1preserve',
        amount: Sats.fromInt(3500),
      ),
      isA<Err<String, ArkFailure>>(),
    );
    expect(r.steps, ['source']);
  });

  test('a deferred top-up builds its send path only when used', () async {
    var built = 0;
    final deferred = DeferredArkReserveTopUp(() {
      built++;
      return rig().topUp;
    });
    expect(built, 0);
    for (var i = 0; i < 2; i++) {
      await deferred.topUp(
        account,
        address: 'bcrt1preserve',
        amount: Sats.fromInt(3500),
      );
    }
    expect(built, 1);
  });
}
