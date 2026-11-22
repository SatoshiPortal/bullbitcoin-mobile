import 'package:drift/native.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/src/domain/electrum_default_endpoints.dart';
import 'package:electrum/storage.dart' show ElectrumServerRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'electrum_test_database.dart';

void main() {
  const network = ElectrumServerNetwork.bitcoinMainnet;
  late ElectrumTestDatabase database;
  late ElectrumServers servers;

  setUp(() {
    database = ElectrumTestDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    servers = Electrum.open(
      database: database,
      readPreferences: () => throw StateError('Unexpected preferences read'),
      tor: () => throw StateError('Unexpected Tor access'),
    ).servers;
  });

  for (final (address, priority) in [
    ('bad', 0),
    ('host:0', 0),
    ('host:65536', 0),
    ('host:50002', -1),
  ]) {
    test('store rejects $address with priority $priority', () async {
      final result = await servers.store(
        address,
        network: network,
        priority: priority,
        enableSsl: true,
      );

      expect(
        result,
        isA<Err<ElectrumEndpoint, ElectrumFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<ElectrumInvalidEndpointFailure>(),
        ),
      );
      expect(await database.select(database.electrumServers).get(), isEmpty);
    });
  }

  test('trash preserves a default endpoint and its stored priority', () async {
    final defaultRow = ElectrumServerRow(
      url: ElectrumDefaultEndpoints.fulcrumElectrumUrl,
      network: network.storageName,
      priority: 7,
      isCustom: false,
    );
    await database.into(database.electrumServers).insert(defaultRow);

    expect(
      await servers.trash(defaultRow.url, network: network),
      isA<Ok<void, ElectrumFailure>>(),
    );
    expect(await database.select(database.electrumServers).get(), [defaultRow]);
  });
}
