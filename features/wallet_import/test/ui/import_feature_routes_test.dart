import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:wallet_import/setup.dart';
import 'package:wallet_import/wallet_import.dart' show QrImportDevice;

class _Preferences extends Fake implements Preferences {}

class _Servers extends Fake implements ElectrumServersPort {}

class _Inventory extends Fake implements WalletInventory {}

class _Admission extends Fake implements ParentCustodyAdmissionPort {}

Iterable<GoRoute> _namedRoutes(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) yield route;
    yield* _namedRoutes(route.routes);
  }
}

void main() {
  test('mount owns the existing import route names and paths', () {
    final feature = ImportFeature.mount(
      preferences: _Preferences(),
      servers: _Servers(),
      secrets: Secrets(scratchDirectory: () async => fail('unused')),
      inventory: _Inventory(),
      admission: _Admission(),
      provisionMnemonic: ({
        required parent,
        required secrets,
        required admission,
        required network,
        required scriptType,
        label,
      }) async => fail('unused'),
      provisionDescriptor: ({
        required descriptor,
        required signer,
        required label,
      }) async => fail('unused'),
      provisionXpub: ({
        required xpub,
        required network,
        required scriptType,
        required label,
      }) async => fail('unused'),
      networkOf: (_) => null,
      onImported: (_) => fail('unused'),
      onExit: (_) => fail('unused'),
      qrIllustration: const AssetImage('unused.png'),
    );

    final routes = _namedRoutes(feature.routes).toList();
    expect(routes, hasLength(7 + QrImportDevice.values.length));
    expect(
      {for (final route in routes) route.name: route.path},
      {
        'importWalletHome': '/import-wallet-home',
        'importMnemonicHome': '/import-mnemonic-home',
        'selectScriptType': '/select-script-type',
        'import': '/import-watch-only',
        'scan': '/import-watch-only-scanner',
        'importColdcardQ': '/import-coldcard-q',
        'importColdcardMk4': '/import-coldcard-mk4',
        for (final device in QrImportDevice.values)
          device.routeName: device.path,
      },
    );
  });
}
