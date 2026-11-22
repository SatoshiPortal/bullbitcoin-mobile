import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:mempool/mempool.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:mempool/src/data/tables/mempool_servers_table.dart';
import 'package:mempool/src/data/tables/mempool_servers_table.drift.dart';
import 'package:mempool/src/data/tables/mempool_settings_table.dart';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'mempool_storage_failure_test.drift.dart';

@DriftDatabase(tables: [MempoolServers, MempoolSettings])
class TestDatabase extends $TestDatabase {
  TestDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

class _ServerReads extends QueryInterceptor {
  bool failCustom = false;
  bool failDefault = false;
  int customReads = 0;
  int defaultReads = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('FROM "mempool_servers"') && args.length == 3) {
      final custom = args.last == true || args.last == 1;
      if (custom) {
        customReads++;
      } else {
        defaultReads++;
      }
      if (custom ? failCustom : failDefault) {
        throw Exception('Injected mempool storage read failure');
      }
    }
    return executor.runSelect(statement, args);
  }
}

final _customLoadFailure = isA<Err<Uri, MempoolFailure>>().having(
  (result) => result.failure,
  'failure',
  isA<MempoolLoadFailure>().having(
    (failure) => failure.serverKind,
    'server kind',
    MempoolServerKind.custom,
  ),
);

void main() {
  late TestDatabase database;
  late _ServerReads reads;
  late Mempool mempool;

  setUp(() {
    reads = _ServerReads();
    database = TestDatabase(NativeDatabase.memory().interceptWith(reads));
    mempool = Mempool.testing(
      database: database,
      tor: () => throw StateError('Link lookup must not use Tor'),
      torHttp: const TorHttpClientFactory(),
    );
  });
  tearDown(() async => database.close());

  Future<void> insertServer(
    MempoolServerNetwork network,
    String url, {
    bool isCustom = false,
    bool enableSsl = true,
  }) async {
    await database
        .into(database.mempoolServers)
        .insert(
          MempoolServersCompanion.insert(
            url: url,
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
            isCustom: isCustom,
            enableSsl: Value(enableSsl),
          ),
        );
  }

  for (final persisted in MempoolServerNetwork.values) {
    final network = persisted.network;
    group('$network storage resolution', () {
      setUp(() => insertServer(persisted, 'public.example.com/base'));

      test(
        'transaction lookup returns the storage failure as a value',
        () async {
          await insertServer(persisted, 'private.example.com', isCustom: true);
          reads.failCustom = true;
          final result = await mempool.links.transaction(
            'txid',
            network: network,
          );
          expect(result, _customLoadFailure);
          expect(reads.customReads, 1);
          expect(reads.defaultReads, 0);
        },
      );

      test('address lookup keeps the failure typed', () async {
        reads.failCustom = true;
        expect(
          await mempool.links.address('address', network: network),
          _customLoadFailure,
        );
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 0);
      });

      test('configured custom server prevents default lookup', () async {
        await insertServer(
          persisted,
          'private.example.com:8080',
          isCustom: true,
          enableSsl: false,
        );
        final result = await mempool.links.address('address', network: network);
        expect(
          result,
          isA<Ok<Uri, MempoolFailure>>().having(
            (result) => result.value.toString(),
            'URL',
            'http://private.example.com:8080/address/address',
          ),
        );
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 0);
      });

      test('successful no-row permits default lookup', () async {
        final result = await mempool.links.transaction(
          'txid',
          network: network,
        );
        expect(
          result,
          isA<Ok<Uri, MempoolFailure>>().having(
            (result) => result.value.toString(),
            'URL',
            'https://public.example.com/base/tx/txid',
          ),
        );
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 1);
      });

      test('default read failure propagates after successful no-row', () async {
        reads.failDefault = true;
        final result = await mempool.links.transaction(
          'txid',
          network: network,
        );
        expect(
          result,
          isA<Err<Uri, MempoolFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<MempoolLoadFailure>().having(
              (failure) => failure.serverKind,
              'server kind',
              MempoolServerKind.defaultServer,
            ),
          ),
        );
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 1);
      });

      test('fetch and trash select the persisted network', () async {
        await insertServer(persisted, 'private.example.com', isCustom: true);
        final selection = await mempool.servers.fetch(network: network);
        expect(
          selection,
          isA<Ok<MempoolServerSelection, MempoolFailure>>()
              .having(
                (result) => result.value.defaultServer.network,
                'network',
                network,
              )
              .having(
                (result) => result.value.customServer?.url,
                'custom URL',
                'private.example.com',
              ),
        );
        if (selection case Ok(:final value)) {
          final storeDefault = await mempool.servers.store(value.defaultServer);
          expect(
            storeDefault,
            isA<Err<void, MempoolFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<MempoolServerSameAsDefaultFailure>(),
            ),
          );
        }
        expect(await mempool.servers.trash(network: network), isA<Ok>());
        expect(
          await mempool.servers.fetch(network: network),
          isA<Ok<MempoolServerSelection, MempoolFailure>>().having(
            (result) => result.value.customServer,
            'custom server',
            isNull,
          ),
        );
        expect(
          await mempool.servers.trash(network: network),
          isA<Err<void, MempoolFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<MempoolDeleteFailure>(),
          ),
        );
      });
    });
  }

  test('keeps the Bitcoin output fragment and seeded testnet path', () async {
    await insertServer(
      MempoolServerNetwork.bitcoinTestnet,
      'public.example.com/testnet',
    );
    expect(
      await mempool.links.transaction(
        'txid',
        network: BitcoinNetwork.testnet,
        fragment: 'pj=1:rss:rs',
      ),
      isA<Ok<Uri, MempoolFailure>>().having(
        (result) => result.value.toString(),
        'URL',
        'https://public.example.com/testnet/tx/txid?showDetails=true#pj=1:rss:rs',
      ),
    );
  });

  test('keeps the Liquid unblinded path and stored transport', () async {
    const host = 'private.example.com:8080';
    await insertServer(
      MempoolServerNetwork.liquidTestnet,
      host,
      isCustom: true,
      enableSsl: false,
    );
    expect(
      await mempool.links.unblindedTransaction(
        'tx/txid#blinded=details',
        network: LiquidNetwork.testnet,
      ),
      isA<Ok<Uri, MempoolFailure>>().having(
        (result) => result.value.toString(),
        'URL',
        'http://$host/tx/txid#blinded=details',
      ),
    );
  });

  test(
    'fees use the custom base then the default only after a successful miss',
    () async {
      const persisted = MempoolServerNetwork.bitcoinTestnet;
      const network = BitcoinNetwork.testnet;
      await insertServer(persisted, 'default.example.com/testnet');
      await insertServer(
        persisted,
        'private.example.com:8080',
        isCustom: true,
        enableSsl: false,
      );
      expect(
        await mempool.servers.activeBase(network: network),
        isA<Ok<Uri, MempoolFailure>>().having(
          (result) => result.value.toString(),
          'URL',
          'http://private.example.com:8080',
        ),
      );
      expect(reads.defaultReads, 0);
      reads.failCustom = true;
      expect(
        await mempool.servers.activeBase(network: network),
        _customLoadFailure,
      );
      expect(reads.defaultReads, 0);
      reads.failCustom = false;
      expect(await mempool.servers.trash(network: network), isA<Ok>());
      expect(
        await mempool.servers.activeBase(network: network),
        isA<Ok<Uri, MempoolFailure>>().having(
          (result) => result.value.toString(),
          'URL',
          'https://default.example.com/testnet',
        ),
      );
      expect(reads.defaultReads, 1);
    },
  );

  test('store validates and replaces only its network custom server', () async {
    const genesis =
        '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) {
      final path = request.uri.path;
      paths.add(path);
      switch (path) {
        case '/api/v1/blocks/tip/height':
          request.response.write('880000');
        case '/api/block/$genesis':
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"id":"$genesis"}');
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      request.response.close();
    });
    const mainnet = MempoolServerNetwork.bitcoinMainnet;
    const testnet = MempoolServerNetwork.bitcoinTestnet;
    await insertServer(mainnet, 'mainnet.example.com');
    await insertServer(mainnet, 'previous.example.com', isCustom: true);
    await insertServer(testnet, 'testnet.example.com');
    await insertServer(testnet, 'unchanged.example.com', isCustom: true);

    final url = '127.0.0.1:${server.port}';
    final custom = MempoolServer.tryCreateCustom(
      url: 'http://$url',
      network: BitcoinNetwork.mainnet,
      enableSsl: false,
    ).fold((value) => value, (_) => throw StateError('Invalid test server'));

    expect(await mempool.servers.store(custom), isA<Ok>());
    expect(paths, ['/api/v1/blocks/tip/height', '/api/block/$genesis']);

    final mainnetResult = await mempool.servers.fetch(
      network: BitcoinNetwork.mainnet,
    );
    expect(
      mainnetResult,
      isA<Ok<MempoolServerSelection, MempoolFailure>>().having(
        (result) => result.value.customServer,
        'custom server',
        custom,
      ),
    );
    final testnetResult = await mempool.servers.fetch(
      network: BitcoinNetwork.testnet,
    );
    expect(
      testnetResult,
      isA<Ok<MempoolServerSelection, MempoolFailure>>().having(
        (result) => result.value.customServer?.url,
        'custom URL',
        'unchanged.example.com',
      ),
    );
  });

  for (final network in <Network>[
    BitcoinNetwork.signet,
    BitcoinNetwork.regtest,
    LiquidNetwork.regtest,
  ]) {
    test(
      '$network returns an unsupported failure before server lookup',
      () async {
        final link = await mempool.links.transaction('txid', network: network);
        expect(
          link,
          isA<Err<Uri, MempoolFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<MempoolUnsupportedNetworkFailure>().having(
              (failure) => failure.network,
              'network',
              network,
            ),
          ),
        );
        expect(await mempool.servers.fetch(network: network), isA<Err>());
        if (network is BitcoinNetwork) {
          expect(
            await mempool.servers.activeBase(network: network),
            isA<Err>(),
          );
        }
        expect(reads.customReads, 0);
        expect(reads.defaultReads, 0);
      },
    );
  }
}
