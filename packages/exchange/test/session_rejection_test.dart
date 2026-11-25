import 'package:bbx_api/bbx_api_testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

class _MockAccess extends Mock implements ExchangeAccessLifecycle {}

void main() {
  late _MockAccess access;

  setUp(() {
    access = _MockAccess();
    when(
      () => access.expireSession(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  Exchange exchangeOver(FakeBbxHttp http) => exchangeWithTransportForTesting(
    readSession: () async => const Ok((
      environment: ExchangeEnvironment.testnet,
      epoch: 7,
      apiKey: 'synthetic-key',
    )),
    openClient: (endpoint, readKey) => bbxForTesting(
      endpoint: endpoint.toString(),
      adapter: http,
      readActiveApiKey: readKey,
    ),
    access: access,
  );

  test('a 401 on any exchange call expires the session that sent it '
      '(INT-7)', () async {
    final exchange = exchangeOver(FakeBbxHttp(status: 401, body: const {}));

    final _ = await exchange.getOrderStats();
    await pumpEventQueue();

    verify(() => access.expireSession(epoch: 7, isTestnet: true)).called(1);
  });

  test('a 401 to a write expires it too', () async {
    final exchange = exchangeOver(FakeBbxHttp(status: 401, body: const {}));

    final _ = await exchange
        .orders(ExchangeEnvironment.testnet)
        .confirmBuyOrder('order-1');
    await pumpEventQueue();

    verify(() => access.expireSession(epoch: 7, isTestnet: true)).called(1);
  });

  test('another failure does not expire the session', () async {
    final exchange = exchangeOver(FakeBbxHttp(status: 403, body: const {}));

    final _ = await exchange.getOrderStats();
    await pumpEventQueue();

    verifyNever(
      () => access.expireSession(
        epoch: any(named: 'epoch'),
        isTestnet: any(named: 'isTestnet'),
      ),
    );
  });
}
