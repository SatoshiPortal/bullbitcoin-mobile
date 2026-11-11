import 'package:bb_mobile/core/exchange/data/datasources/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _Keys extends Mock implements BullbitcoinApiKeyProvider {}

void main() {
  testWidgets('registered sockets preserve foreground through inactive', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final locator = GetIt.asNewInstance();
    ExchangeLocator.registerDatasources(locator);
    final keys = _Keys();
    await locator.unregister<BullbitcoinApiKeyProvider>();
    locator.registerSingleton<BullbitcoinApiKeyProvider>(keys);
    final sockets = [
      locator<ExchangeNotificationDatasource>(
        instanceName: 'mainnetExchangeNotificationDatasource',
      ),
      locator<ExchangeNotificationDatasource>(
        instanceName: 'testnetExchangeNotificationDatasource',
      ),
    ];
    for (final isTestnet in [false, true]) {
      when(
        () => keys.getApiKey(isTestnet: isTestnet),
      ).thenAnswer((_) async => null);
    }
    addTearDown(() async {
      for (final socket in sockets) {
        socket.dispose();
      }
      await locator.reset();
    });
    Future<void> connectBoth() async {
      for (final socket in sockets) {
        await socket.connect();
      }
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await connectBoth();
    for (final isTestnet in [false, true]) {
      verify(() => keys.getApiKey(isTestnet: isTestnet)).called(1);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await connectBoth();
    for (final isTestnet in [false, true]) {
      verifyNever(() => keys.getApiKey(isTestnet: isTestnet));
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await connectBoth();
    for (final isTestnet in [false, true]) {
      verify(() => keys.getApiKey(isTestnet: isTestnet)).called(1);
    }
  });
}
