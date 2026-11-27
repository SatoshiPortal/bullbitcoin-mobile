import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';
import 'package:wallet_import/setup.dart';
import 'package:wallet_import/wallet_import.dart' show QrImportDevice;
import 'package:secrets/testing.dart' show unlockedSessionAuthority;

class _Preferences extends Fake implements Preferences {}

class _Servers extends Fake implements ElectrumServersPort {}

class _Inventory extends Fake implements WalletInventory {}

class _Admission extends Fake implements ParentCustodyAdmissionPort {}

/// Mounting wires the provisioning capability into the import screens; it
/// never calls it.
final class _Accounts implements WalletProvisioning {
  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      throw StateError('Unexpected provisioning while mounting');

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) async => throw StateError('Unexpected provisioning while mounting');

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) async => throw StateError('Unexpected provisioning while mounting');

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) async => throw StateError('Unexpected provisioning while mounting');

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) async => throw StateError('Unexpected provisioning while mounting');
}

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
      secrets: Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => fail('unused'),
      ),
      inventory: _Inventory(),
      admission: _Admission(),
      accounts: _Accounts(),
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
