import 'package:electrum/testing.dart';
import 'package:drift/native.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx;

import 'electrum_test_database.dart';

void main() {
  const network = ElectrumServerNetwork.bitcoinMainnet;
  const txid = 'cached-transaction';
  late ElectrumTestDatabase database;
  late Electrum electrum;

  setUp(() async {
    database = ElectrumTestDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    electrum = createElectrumForTesting(
      database: database,
      readPreferences: () async => const Ok((
        isSuperuser: false,
        isDevModeEnabled: false,
        useTorProxy: false,
        torProxyPort: 9050,
      )),
      tor: () => throw StateError('A cached clearnet read does not open Tor'),
    );
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

  test('missing options produce a typed storage failure', () async {
    const unprovisioned = ElectrumServerNetwork.liquidRegtest;
    final expected = isA<Err<Object?, ElectrumFailure>>().having(
      (result) => result.failure,
      'failure',
      isA<ElectrumLoadFailure>(),
    );

    expect(
      await electrum.servers.options.fetch(network: unprovisioned),
      expected,
    );
    final updates = await electrum.servers
        .watchChecks(network: unprovisioned)
        .toList();
    expect(updates, [expected]);
  });

  test(
    'detects a custom onion on the requested Bitcoin network only',
    () async {
      const fixtures = [
        (
          'ssl://default.onion:50002',
          ElectrumServerNetwork.bitcoinMainnet,
          false,
        ),
        (
          'ssl://custom.example:50002',
          ElectrumServerNetwork.bitcoinMainnet,
          true,
        ),
        ('ssl://liquid.onion:50002', ElectrumServerNetwork.liquidMainnet, true),
      ];
      Future<void> seed(
        String url,
        ElectrumServerNetwork network,
        bool isCustom,
      ) => database
          .into(database.electrumServers)
          .insert(
            ElectrumServerRow(
              url: url,
              network: network.storageName,
              priority: 0,
              isCustom: isCustom,
            ),
          );

      for (final (url, network, isCustom) in fixtures) {
        await seed(url, network, isCustom);
      }
      final without = await electrum.servers.hasCustomOnionServer(
        network: network,
      );
      expect(without.fold((value) => value, (_) => null), isFalse);

      await seed('ssl://custom.onion.:50002', network, true);
      final withOnion = await electrum.servers.hasCustomOnionServer(
        network: network,
      );
      expect(withOnion.fold((value) => value, (_) => null), isTrue);
    },
  );

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
      await electrum.transactions.fetch(txid, network: BitcoinNetwork.mainnet),
      isA<Ok<BitcoinTx, ElectrumFailure>>()
          .having((result) => result.value.txid, 'id', txid)
          .having((result) => result.value.vsize, 'vsize', BigInt.from(90)),
    );
  });

  test('lookup reports the network when no servers are configured', () async {
    expect(
      await electrum.transactions.fetch(txid, network: BitcoinNetwork.mainnet),
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
        await electrum.transactions.fetch(txid, network: BitcoinNetwork.signet),
        isA<Err<BitcoinTx, ElectrumFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ElectrumUnsupportedNetworkFailure>(),
        ),
      );
    },
  );
}
