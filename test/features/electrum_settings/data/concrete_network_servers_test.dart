import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/data/drift_electrum_server_repository.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/models/electrum_server_model.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  late SqliteDatabase database;
  late ElectrumServerStorageDatasource datasource;
  late DriftElectrumServerRepository repository;

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = ElectrumServerStorageDatasource(sqlite: database);
    repository = DriftElectrumServerRepository(
      electrumServerStorageDatasource: datasource,
    );
  });
  tearDown(() => database.close());

  test(
    'same endpoint is independently stored and deleted on each network',
    () async {
      const url = 'tcp://127.0.0.1:50000';
      const networks = [
        ElectrumServerNetwork.bitcoinMainnet,
        ElectrumServerNetwork.bitcoinTestnet,
        ElectrumServerNetwork.bitcoinRegtest,
      ];
      for (final network in networks) {
        await datasource.store(
          ElectrumServerModel(url: url, network: network, isCustom: true),
        );
      }
      for (final network in networks) {
        final active = await repository.fetchActiveServers(network: network);
        expect(active, isA<Ok>());
        active.fold((servers) {
          expect(servers, hasLength(1));
          expect(servers.single.network, network);
          expect(servers.single.url, url);
        }, (failure) => fail('Unexpected ${failure.runtimeType}'));
      }
      await datasource.deleteServer(
        url,
        network: ElectrumServerNetwork.bitcoinRegtest,
      );
      expect(
        await datasource.fetchByUrl(
          url,
          network: ElectrumServerNetwork.bitcoinRegtest,
        ),
        isNull,
      );
      expect(
        await datasource.fetchByUrl(
          url,
          network: ElectrumServerNetwork.bitcoinTestnet,
        ),
        isNotNull,
      );
      expect(
        await datasource.fetchByUrl(
          url,
          network: ElectrumServerNetwork.bitcoinMainnet,
        ),
        isNotNull,
      );
    },
  );

  test('Liquid regtest refuses even a manually persisted endpoint', () async {
    await datasource.store(
      ElectrumServerModel(
        url: '127.0.0.1:50001',
        network: ElectrumServerNetwork.liquidRegtest,
      ),
    );
    final result = await repository.fetchActiveServers(
      network: ElectrumServerNetwork.liquidRegtest,
    );
    result.fold(
      (_) => fail('Unsupported network admitted'),
      (failure) => expect(failure, isA<ElectrumUnsupportedNetworkFailure>()),
    );
  });

  test('primitive mapping never aliases regtest or signet to testnet', () {
    expect(
      ElectrumServerNetwork.fromNetworkEnv(NetworkEnv.regtest, isLiquid: false),
      ElectrumServerNetwork.bitcoinRegtest,
    );
    expect(
      ElectrumServerNetwork.fromNetworkEnv(NetworkEnv.regtest, isLiquid: true),
      ElectrumServerNetwork.liquidRegtest,
    );
    expect(
      () => ElectrumServerNetwork.fromNetworkEnv(
        NetworkEnv.signet,
        isLiquid: false,
      ),
      throwsA(isA<ElectrumUnsupportedNetworkException>()),
    );
  });

  test('persisted network codec is explicit and rejects unknown names', () {
    const names = [
      'bitcoinMainnet',
      'bitcoinTestnet',
      'liquidMainnet',
      'liquidTestnet',
      'bitcoinRegtest',
      'liquidRegtest',
    ];
    expect(
      ElectrumServerNetwork.values.map((network) => network.storageName),
      names,
    );
    for (final network in ElectrumServerNetwork.values) {
      expect(
        ElectrumServerNetwork.fromStorageName(network.storageName),
        network,
      );
    }
    expect(
      () => ElectrumServerNetwork.fromStorageName('signet'),
      throwsFormatException,
    );
  });
}
