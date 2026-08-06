import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('all unavailable role views return the original failure', () async {
    const failure = PayjoinMigrationFailure('migration failed');
    final payjoin = Payjoin.unavailable(failure);
    final senderRequest = StartPayjoinSender(
      walletId: 'wallet',
      network: BitcoinNetwork.mainnet,
      bip21Uri: 'bitcoin:address?pj=https://example.com',
      unsignedOriginalPsbt: 'psbt',
      amount: Sats.fromInt(10000),
      feeRate: FeeRate(1),
    );
    final receiverRequest = StartPayjoinReceiver(
      walletId: 'wallet',
      network: BitcoinNetwork.mainnet,
      address: 'address',
    );

    await _expectFailure(payjoin.sender.start(senderRequest), failure);
    await _expectFailure(payjoin.sender.broadcastOriginal('session'), failure);
    await _expectFailure(payjoin.receiver.start(receiverRequest), failure);
    await _expectFailure(payjoin.receiver.cancel('session'), failure);
    await _expectFailure(payjoin.receiver.disableAll(), failure);
    await _expectFailure(payjoin.sessions.byId('session'), failure);
    await _expectFailure(
      payjoin.sessions.byTransactionId('transaction'),
      failure,
    );
    await _expectFailure(
      payjoin.sessions.list(PayjoinSessionFilter()),
      failure,
    );
    await _expectFailure(payjoin.sessions.reservedOutpoints(), failure);
    await _expectFailure(payjoin.policy.load(), failure);
    await _expectFailure(payjoin.policy.setEnabled(true), failure);
    await _expectFailure(
      payjoin.policy.setMinimumAmount(Sats.fromInt(10000)),
      failure,
    );
    await _expectFailure(
      payjoin.policy.setSessionLifetime(const Duration(hours: 1)),
      failure,
    );
    await _expectFailure(payjoin.diagnostics.relayHealth(), failure);
    _expectResultFailure(await payjoin.sessions.watch().first, failure);
    _expectResultFailure(await payjoin.policy.watch().first, failure);
  });
}

Future<void> _expectFailure<T>(
  Future<Result<T, PayjoinFailure>> result,
  PayjoinFailure failure,
) async {
  _expectResultFailure(await result, failure);
}

void _expectResultFailure<T>(
  Result<T, PayjoinFailure> result,
  PayjoinFailure failure,
) {
  expect(result, isA<Err<T, PayjoinFailure>>());
  expect((result as Err<T, PayjoinFailure>).failure, same(failure));
}
