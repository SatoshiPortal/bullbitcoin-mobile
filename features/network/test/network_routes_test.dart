import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:network/network.dart';
import 'package:primitives/primitives.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mount contributes existing root routes and nested Tor route', () {
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);
    final feature = NetworkFeature.mount(
      services: services,
      bindings: (
        readDefaultNetwork: () async => const Ok(null),
        checkBitcoinFees: (_) async {},
        isTorRequired: () async => false,
        readTorPreferences: () async => throw StateError('Unexpected Tor read'),
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
  });
}
