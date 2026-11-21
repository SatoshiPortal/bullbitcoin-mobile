import 'package:drift/native.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx;

import 'electrum_test_database.dart';

final class _Mainnet implements EnvironmentPort {
  @override
  Future<ElectrumEnvironment> getEnvironment() async =>
      ElectrumEnvironment.mainnet;
}

void main() {
  const network = ElectrumServerNetwork.bitcoinMainnet;
  const txid = 'cached-transaction';
  late ElectrumTestDatabase database;
  late Electrum electrum;

  setUp(() async {
    database = ElectrumTestDatabase(NativeDatabase.memory());
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);
    addTearDown(database.close);
    ElectrumLocator.registerDatasources(locator, () => database);
    ElectrumLocator.registerRepositories(locator);
    ElectrumLocator.registerPorts(
      locator,
      environment: _Mainnet(),
      readPreferences: () async => (
        isSuperuser: false,
        isDevModeEnabled: false,
        useTorProxy: false,
        torProxyPort: 9050,
      ),
      tor: () => throw StateError('A cached clearnet read does not open Tor'),
    );
    electrum = locator<Electrum>();
    await database
        .into(database.electrumSettings)
        .insert(
          const ElectrumSettingsRow(
            network: network,
            validateDomain: true,
            stopGap: 20,
            timeout: 5,
            retry: 5,
          ),
        );
  });

  test('lookup maps an existing row to the published BitcoinTx', () async {
    await database
        .into(database.electrumServers)
        .insert(
          ElectrumServerRow(
            url: 'tcp://127.0.0.1:1',
            network: network.storageName,
            priority: 0,
            isCustom: true,
          ),
        );
    await database
        .into(database.transactions)
        .insert(
          const TransactionModel(
            txid: txid,
            version: 2,
            size: '120',
            vsize: '90',
            locktime: 0,
            vin: '[]',
            vout: '[]',
          ),
        );

    expect(
      await electrum.fetchBitcoinTransaction(
        txid: txid,
        network: BitcoinNetwork.mainnet,
      ),
      isA<Ok<BitcoinTx, ElectrumFailure>>()
          .having((result) => result.value.txid, 'id', txid)
          .having((result) => result.value.vsize, 'vsize', BigInt.from(90)),
    );
  });

  test('lookup reports the network when no servers are configured', () async {
    expect(
      await electrum.fetchBitcoinTransaction(
        txid: txid,
        network: BitcoinNetwork.mainnet,
      ),
      isA<Err<BitcoinTx, ElectrumFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<ElectrumNoTransactionServersFailure>().having(
          (failure) => failure.network,
          'network',
          network,
        ),
      ),
    );
  });

  test(
    'an unsupported Bitcoin network is rejected before server selection',
    () async {
      expect(
        await electrum.fetchBitcoinTransaction(
          txid: txid,
          network: BitcoinNetwork.signet,
        ),
        isA<Err<BitcoinTx, ElectrumFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ElectrumUnsupportedNetworkFailure>(),
        ),
      );
    },
  );
}
