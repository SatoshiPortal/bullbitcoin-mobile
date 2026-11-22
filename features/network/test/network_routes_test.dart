import 'package:bull_tor/tor.dart';
import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mempool/mempool.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart';
import 'package:network/src/electrum_settings/ui/screens/electrum_settings_screen.dart';
import 'package:network/src/mempool_settings/ui/mempool_settings_screen.dart';
import 'package:primitives/primitives.dart';

import 'fixtures.dart';

class _Electrum extends Mock implements Electrum {}

class _ElectrumServers extends Mock implements ElectrumServers {}

class _ElectrumOptions extends Mock implements ElectrumServerOptions {}

class _Mempool extends Mock implements Mempool {}

class _MempoolServers extends Mock implements MempoolServerSettings {}

class _Tor extends Mock implements Tor {}

class _ExternalTor extends Mock implements ExternalTor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

void main() {
  testWidgets('mounted settings routes use the supplied services', (
    tester,
  ) async {
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);
    final electrum = _Electrum();
    final electrumServers = _ElectrumServers();
    when(() => electrum.servers).thenReturn(electrumServers);
    when(() => electrumServers.options).thenReturn(_ElectrumOptions());
    when(
      () => electrumServers.watchChecks(
        network: ElectrumServerNetwork.bitcoinTestnet,
      ),
    ).thenAnswer((_) => Stream.value(const Err(ElectrumLoadFailure())));
    services.registerSingleton<Electrum>(electrum);

    final mempool = _Mempool();
    final mempoolServers = _MempoolServers();
    when(() => mempool.servers).thenReturn(mempoolServers);
    when(() => mempoolServers.fetch(network: BitcoinNetwork.testnet))
        .thenAnswer(
          (_) async =>
              const Err(MempoolLoadFailure(MempoolServerKind.defaultServer)),
        );
    services.registerSingleton<Mempool>(mempool);

    final tor = _Tor();
    final embedded = _EmbeddedTor();
    when(() => tor.embedded).thenReturn(embedded);
    when(() => tor.external).thenReturn(_ExternalTor());
    when(() => embedded.states).thenAnswer((_) => const Stream.empty());
    services.registerSingleton<Tor>(tor);

    final feature = NetworkFeature.mount(
      services: services,
      bindings: (
        readDefaultNetwork: () async => const Ok(null),
        readEnvironment: () async => NetworkEnv.testnet,
        readMempoolEnvironment: () async => const Ok(BitcoinNetwork.testnet),
        checkBitcoinFees: (_) async {},
        isTorRequired: () async => const Ok(false),
        readTorPreferences: () async => (
          useTorProxy: false,
          torProxyPort: 9050,
          torTransportMode: TorTransportMode.automatic,
          lastSuccessfulTorTransport: null,
        ),
        saveTorProxy: ({required enabled, required port}) async => false,
        saveTorMode: (_) async => const Ok(null),
      ),
    );
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        ...feature.routes.root,
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'app-settings',
              builder: (_, _) => const SizedBox.shrink(),
              routes: feature.routes.appSettings,
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    expect(router.namedLocation('electrumSettings'), '/electrum-settings');
    expect(router.namedLocation('mempoolSettings'), '/mempool-settings');
    expect(router.namedLocation('serviceStatus'), '/service-status');
    expect(
      router.namedLocation('torSettings'),
      '/settings/app-settings/tor-settings',
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: networkTestTheme(),
        localizationsDelegates: networkTestLocalizationsDelegates,
      ),
    );

    router.goNamed('electrumSettings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ElectrumSettingsScreen), findsOneWidget);
    verify(
      () => electrumServers.watchChecks(
        network: ElectrumServerNetwork.bitcoinTestnet,
      ),
    ).called(1);

    router.goNamed('mempoolSettings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MempoolSettingsScreen), findsOneWidget);
    verify(() => mempoolServers.fetch(network: BitcoinNetwork.testnet))
        .called(1);
  });
}
