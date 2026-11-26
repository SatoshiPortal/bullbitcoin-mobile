import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/setup.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';

class _Inventory extends Mock implements WalletInventory {}

class _EnvironmentReader extends Mock implements ActiveEnvironmentReader {}

void main() {
  test('mount preserves receive route names, paths and overlay navigators', () {
    final root = GlobalKey<NavigatorState>();
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);
    services.registerSingleton<ActiveEnvironmentReader>(_EnvironmentReader());
    final feature = ReceiveFeature.mount(
      services,
      rootNavigatorKey: root,
      inventory: _Inventory(),
      loadWallet: (_) async => const Err(SyncNotFoundFailure()),
      readSigner: (_) async => const Ok(null),
      poll: (_, {required isActive}) async {},
      refreshAfterLightningPayment: () async {},
      orderSwaps: () => throw StateError('order observation not needed'),
      createOrder: ({required wallet, required amountSat, note}) =>
          throw StateError('order creation not needed'),
      setPayjoinEnabled: (_, {required requestConsent}) =>
          throw StateError('consent not needed'),
      openHome: (_) {},
      openPayjoinSettings: (_) {},
      successAnimation: const AssetImage('unused.gif'),
      orderSwapUnderReview: (_) => const SizedBox(),
    );
    final paths = <String?, String>{};
    final overlays = <String?>[];
    void walk(List<RouteBase> routes, [String prefix = '']) {
      for (final route in routes.whereType<GoRoute>()) {
        final path = prefix.isEmpty ? route.path : '$prefix/${route.path}';
        paths[route.name] = path;
        if (route.parentNavigatorKey == root) overlays.add(route.name);
        walk(route.routes, path);
      }
    }

    walk(feature.route.routes);
    expect(paths, {
      'receiveBitcoin': '/receive/bitcoin',
      'receiveLightning': '/receive/lightning',
      'receiveLiquid': '/receive/liquid',
      'lightningAmount': '/receive/lightning/qr/amount',
      'lightningQr': '/receive/lightning/qr',
      'payjoinInProgress': '/receive/bitcoin/payjoin',
      'lightningPaymentInProgress': '/receive/lightning/qr/in-progress',
      'lightningPaymentReceived': '/receive/lightning/qr/received',
    });
    expect(
      overlays,
      unorderedEquals([
        'payjoinInProgress',
        'lightningPaymentInProgress',
        'lightningPaymentReceived',
      ]),
    );
  });
}
