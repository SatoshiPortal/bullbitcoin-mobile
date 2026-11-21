import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/repositories/drift_mempool_server_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/mempool_servers_table.drift.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

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

void main() {
  for (final network in MempoolServerNetwork.values) {
    group('$network storage resolution', () {
      late SqliteDatabase database;
      late _ServerReads reads;
      late DriftMempoolServerRepository repository;
      late GetActiveMempoolServerUsecase activeServer;
      late MempoolUrlBuilder urls;

      setUp(() async {
        reads = _ServerReads();
        database = SqliteDatabase(NativeDatabase.memory().interceptWith(reads));
        await database.delete(database.mempoolServers).go();
        await database
            .into(database.mempoolServers)
            .insert(
              MempoolServersCompanion.insert(
                url: 'public.example.com',
                isTestnet: network.isTestnet,
                isLiquid: network.isLiquid,
                isCustom: false,
              ),
            );
        repository = DriftMempoolServerRepository(
          mempoolServerStorageDatasource: MempoolServerStorageDatasource(
            sqlite: database,
          ),
        );
        activeServer = GetActiveMempoolServerUsecase(
          serverRepository: repository,
        );
        urls = MempoolUrlBuilder(getActiveMempoolServerUsecase: activeServer);
      });

      tearDown(() async => database.close());

      Future<void> configureCustom() async {
        await database
            .into(database.mempoolServers)
            .insert(
              MempoolServersCompanion.insert(
                url: 'private.example.com',
                isTestnet: network.isTestnet,
                isLiquid: network.isLiquid,
                isCustom: true,
              ),
            );
      }

      test(
        'custom read failure stays typed and never queries default',
        () async {
          await configureCustom();
          // Prove the fallback would succeed; only the custom SELECT will fail.
          expect(await repository.fetchDefaultServer(network), isA<Ok>());
          reads.defaultReads = 0;
          reads.failCustom = true;

          final stored = await repository.fetchCustomServer(network);
          expect(stored, isA<Err<dynamic, MempoolFailure>>());
          if (stored case Err(:final failure)) {
            expect(failure, isA<MempoolLoadFailure>());
          }
          final result = await activeServer.execute(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          );
          expect(result, isA<Err<dynamic, MempoolFailure>>());
          if (result case Err(:final failure)) {
            expect(failure, isA<MempoolLoadFailure>());
          }
          expect(reads.customReads, 2);
          expect(reads.defaultReads, 0);
        },
      );

      test(
        'failed resolution cannot reach explorer open continuation',
        () async {
          await configureCustom();
          reads.failCustom = true;
          var explorerOpens = 0;
          Future<void> openExplorer() async {
            if (network.isLiquid) {
              await urls.liquidTxid('txid', isTestnet: network.isTestnet);
            } else {
              await urls.bitcoinTxid('txid', isTestnet: network.isTestnet);
            }
            explorerOpens++;
          }

          await expectLater(openExplorer(), throwsException);
          expect(explorerOpens, 0);
          expect(reads.customReads, 1);
          expect(reads.defaultReads, 0);
        },
      );

      test('failed address resolution cannot reach explorer open', () async {
        await configureCustom();
        reads.failCustom = true;
        var explorerOpens = 0;
        Future<void> openExplorer() async {
          if (network.isLiquid) {
            await urls.liquidAddress('address', isTestnet: network.isTestnet);
          } else {
            await urls.bitcoinAddress('address', isTestnet: network.isTestnet);
          }
          explorerOpens++;
        }

        await expectLater(openExplorer(), throwsException);
        expect(explorerOpens, 0);
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 0);
      });

      test('configured custom server prevents default lookup', () async {
        await configureCustom();
        final result = await activeServer.execute(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );
        expect(result, isA<Ok>());
        if (result case Ok(:final value)) {
          expect(value.url, 'private.example.com');
          expect(value.isCustom, isTrue);
        }
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 0);
      });

      test('successful no-row permits default lookup', () async {
        final stored = await repository.fetchCustomServer(network);
        expect(stored, isA<Ok>());
        if (stored case Ok(:final value)) {
          expect(value, isNull);
        }
        final result = await activeServer.execute(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );
        expect(result, isA<Ok>());
        if (result case Ok(:final value)) {
          expect(value.url, 'public.example.com');
          expect(value.isCustom, isFalse);
        }
        expect(reads.customReads, 2);
        expect(reads.defaultReads, 1);
      });

      test('default read failure propagates after successful no-row', () async {
        reads.failDefault = true;
        final result = await activeServer.execute(
          isTestnet: network.isTestnet,
          isLiquid: network.isLiquid,
        );
        expect(result, isA<Err<dynamic, MempoolFailure>>());
        if (result case Err(:final failure)) {
          expect(failure, isA<MempoolLoadFailure>());
        }
        expect(reads.customReads, 1);
        expect(reads.defaultReads, 1);
      });
    });
  }
}
