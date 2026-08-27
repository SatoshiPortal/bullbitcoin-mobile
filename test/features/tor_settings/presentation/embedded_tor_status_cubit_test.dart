import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockWatchTorConnectionUsecase extends Mock
    implements WatchTorConnectionUsecase {}

class _MockRetryTorConnectionUsecase extends Mock
    implements RetryTorConnectionUsecase {}

void main() {
  late _MockGetSettingsUsecase getSettings;
  late _MockWatchTorConnectionUsecase watchTor;
  late _MockRetryTorConnectionUsecase retryTor;

  setUp(() {
    getSettings = _MockGetSettingsUsecase();
    watchTor = _MockWatchTorConnectionUsecase();
    retryTor = _MockRetryTorConnectionUsecase();
  });

  test('loads the routing mode and follows embedded Tor state', () async {
    final connections = StreamController<TorConnectionState>();
    addTearDown(connections.close);
    when(() => watchTor.execute()).thenAnswer((_) => connections.stream);
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final cubit = EmbeddedTorStatusCubit(
      getSettingsUsecase: getSettings,
      watchTorConnectionUsecase: watchTor,
      retryTorConnectionUsecase: retryTor,
    );
    addTearDown(cubit.close);

    await cubit.init();
    connections.add(
      TorReady(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.configurationLoaded, isTrue);
    expect(cubit.state.externalProxySelected, isFalse);
    expect(cubit.state.connection, isA<TorReady>());
  });

  test('ignores a stale routing mode refresh', () async {
    final first = Completer<SettingsEntity>();
    final second = Completer<SettingsEntity>();
    var calls = 0;
    when(() => getSettings.execute()).thenAnswer((_) {
      calls++;
      return calls == 1 ? first.future : second.future;
    });
    final cubit = EmbeddedTorStatusCubit(
      getSettingsUsecase: getSettings,
      watchTorConnectionUsecase: watchTor,
      retryTorConnectionUsecase: retryTor,
    );
    addTearDown(cubit.close);

    final staleRefresh = cubit.refreshConfiguration();
    final currentRefresh = cubit.refreshConfiguration();
    second.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    await currentRefresh;
    first.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
      ),
    );
    await staleRefresh;

    expect(cubit.state.externalProxySelected, isFalse);
  });

  test('delegates retry to the embedded Tor use case', () async {
    when(
      () => retryTor.execute(),
    ).thenAnswer((_) async => const TorConnecting(source: TorSource.embedded));
    final cubit = EmbeddedTorStatusCubit(
      getSettingsUsecase: getSettings,
      watchTorConnectionUsecase: watchTor,
      retryTorConnectionUsecase: retryTor,
    );
    addTearDown(cubit.close);

    await cubit.retry();

    verify(() => retryTor.execute()).called(1);
  });
}
