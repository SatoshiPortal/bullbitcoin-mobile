import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/usecases/release_buy_payjoin_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

const _bip21 = 'bitcoin:bc1qreceive?pj=https://relay.example/abc';

void main() {
  test('an abandoned quote cancels the receiver its create attached, by the '
      'URI the reply did not echo', () async {
    final receiver = BuyTestReceiver();
    final sessions = BuyTestPayjoinSessions([
      buyReceiverSession(id: 'pj-other', uri: 'bitcoin:x?pj=https://other'),
      buyReceiverSession(uri: _bip21),
    ]);
    final uris = BuyPayjoinUris()..attachToOrder('b-1', _bip21);
    await ReleaseBuyPayjoinUsecase(
      sessions,
      receiver,
      uris,
    ).execute(buyOrder());
    expect(receiver.log, ['cancel pj-1']);
  });

  test('an order with no payjoin URI cancels nothing', () async {
    final receiver = BuyTestReceiver();
    final sessions = BuyTestPayjoinSessions([buyReceiverSession()]);
    await ReleaseBuyPayjoinUsecase(
      sessions,
      receiver,
      BuyPayjoinUris(),
    ).execute(buyOrder());
    expect(receiver.log, isEmpty);
    expect(sessions.lists, 0);
  });
}
