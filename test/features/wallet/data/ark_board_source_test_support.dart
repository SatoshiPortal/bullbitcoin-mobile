import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/ark_foreground_runtime.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;

import '../../../../features/ark/test/fake_ark_board_funding.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/electrum_fixture.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Settings extends Mock implements SettingsRepository {}

class _Value extends Mock implements SettingsEntity {}

class _Bip85 extends Mock implements Bip85Repository {}

class _Custody extends Mock implements ParentCustodyAdmissionPort {}

class _References extends Mock implements SeedReferences {}

class _Paths extends PathProviderPlatform {
  final String root;
  _Paths(this.root);
  @override
  Future<String> getApplicationDocumentsPath() async => root;
}

class _Reservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

class _Preferences implements ArkPreferencesRepository {
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      const Ok(true);
  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async => const Ok(null);
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw StateError(
    'Source navigation fixture refused ${result.runtimeType}',
  ),
};

typedef BoardSourceRig = ({
  WalletNativeRuntime runtime,
  ForegroundWalletSync source,
  WalletMetadataModel row,
  WalletMetadataDatasource metadata,
  ArkForegroundRuntime opened,
  ElectrumFixture server,
  FixtureConnections connections,
  FakeArkBoardFunding funding,
});

Future<BoardSourceRig> boardSourceRig({bool funded = true}) async {
  final root = Directory.systemTemp.createTempSync('board-source-navigation-');
  final previousPaths = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _Paths(root.path);
  addTearDown(() {
    PathProviderPlatform.instance = previousPaths;
    root.deleteSync(recursive: true);
  });
  final locator = GetIt.asNewInstance();
  addTearDown(locator.reset);
  final descriptor = regtestDescriptor();
  final row = WalletMetadataModel(
    id: '[73c5da0a/84h/1h/0h]:regtest',
    networkCode: 'bitcoinRegtest',
    masterFingerprint: '73c5da0a',
    xpubFingerprint: '73c5da0a',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'public',
    externalPublicDescriptor: descriptor.externalDescriptor,
    internalPublicDescriptor: descriptor.internalDescriptor,
    signer: Signer.local,
    isDefault: true,
  );
  final scripts = <String, String>{};
  for (final (prefix, keychain, count) in [
    ('ext', bdk.KeychainKind.external_, 6),
    ('int', bdk.KeychainKind.internal, 3),
  ]) {
    final parsed = bdk.Descriptor(
      descriptor: descriptor.externalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final change = bdk.Descriptor(
      descriptor: descriptor.internalDescriptor,
      networkKind: bdk.NetworkKind.test,
    );
    final persister = bdk.Persister.newInMemory();
    final native = bdk.Wallet(
      descriptor: parsed,
      changeDescriptor: change,
      network: bdk.Network.regtest,
      persister: persister,
      lookahead: 25,
    );
    try {
      for (var i = 0; i < count; i++) {
        final script = native
            .peekAddress(keychain: keychain, index: i)
            .address
            .scriptPubkey();
        try {
          scripts['$prefix$i'] = script
              .toBytes()
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join();
        } finally {
          script.dispose();
        }
      }
    } finally {
      native.dispose();
      persister.dispose();
      parsed.dispose();
      change.dispose();
    }
  }
  final server = await ElectrumFixture.start(scripts, regtest: true);
  addTearDown(server.close);
  if (funded) await server.load('S10-no-change', 0);
  final metadata = _Metadata();
  when(() => metadata.fetchAll()).thenAnswer((_) async => [row]);
  when(() => metadata.fetch(row.id)).thenAnswer((_) async => row);
  final connections = FixtureConnections([server.url]);
  late WalletNativeRuntime runtime;
  final engine = ElectrumSync(
    connections: connections,
    documentsDirectory: () async => root.path,
    readRevision: (key) => runtime.readRevision(key),
  );
  runtime = WalletNativeRuntime(
    catalog: WalletCatalogPortImpl(metadata),
    reserved: NoReservedAddresses(),
    inputReservations: _Reservations(),
    metadata: metadata,
    sync: engine,
    documentsDirectory: () async => root.path,
    freezes: MemoryFreezeStore(),
    connections: connections,
  );
  addTearDown(runtime.close);
  final source = ForegroundWalletSync(engine, native: runtime);
  await runtime.create(row);
  final settings = _Settings();
  final settingsValue = _Value();
  when(() => settings.fetch()).thenAnswer((_) async => settingsValue);
  when(() => settings.currencyChangeStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => settingsValue.environment).thenReturn(Environment.regtest);
  when(() => settingsValue.currencyCode)
      .thenReturn('unsupported-fixture-currency');
  FakeSecureStoragePlatform().install();
  locator.registerSingleton<SettingsRepository>(settings);
  locator.registerSingleton<WalletMetadataDatasource>(metadata);
  locator.registerSingleton<WalletNativeRuntime>(runtime);
  locator.registerSingleton<ForegroundWalletSync>(source);
  locator.registerSingleton<Bip85Repository>(_Bip85());
  locator.registerSingleton<Secrets>(
    Secrets(scratchDirectory: () async => root.path),
  );
  locator.registerSingleton<ParentCustodyAdmissionPort>(_Custody());
  locator.registerSingleton<SeedReferences>(_References());
  final funding = FakeArkBoardFunding();
  final opened = _ok(
    await openArkForeground(
      locator,
      arkUrl: Uri.parse('http://ark.invalid'),
      primaryEsploraUrl: Uri.parse('http://chain.invalid'),
      initializeNew: true,
      preferences: _Preferences(),
      boardFunding: (bind: (_, _) => funding, close: () async {}),
    ),
  );
  addTearDown(opened.close);
  return (
    runtime: runtime,
    source: source,
    row: row,
    metadata: metadata,
    opened: opened,
    server: server,
    connections: connections,
    funding: funding,
  );
}
