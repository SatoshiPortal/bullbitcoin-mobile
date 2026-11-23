import 'dart:io';

import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';

import 'bull_payjoin.dart';
import 'src/data/payjoin_database.dart';
import 'src/data/payjoin_migration.dart';
import 'src/data/payjoin_policy_store.dart';
import 'src/engine/payjoin_logger.dart';
import 'src/engine/payjoin_runtime.dart';

PayjoinDatabase openPayjoinDatabaseForTesting(String path) =>
    PayjoinDatabase.forTesting(
      NativeDatabase.createInBackground(
        File(path),
        setup: (database) {
          database.execute('PRAGMA busy_timeout = 2000');
          database.execute('PRAGMA journal_mode = WAL');
          database.execute('PRAGMA synchronous = FULL');
        },
      ),
    );

Future<Result<PayjoinLifecycle, PayjoinFailure>> openPayjoinForTesting({
  required String databasePath,
  required PayjoinWalletPort wallet,
  required PayjoinBlockchainPort blockchain,
  required PayjoinFeesPort fees,
  required PayjoinTransactionPort transactions,
  required PayjoinLabelsPort labels,
  required PayjoinLegacyDataPort legacyData,
  required PayjoinLogPort log,
  required PayjoinCodecPort codec,
  PayjoinRegtestProfile? regtestProfile,
  RegtestHostProfile? regtestHostProfile,
  Future<bool> Function()? isCurrent,
}) => openPayjoinWithStorage(
  openStorage: (regtest) async {
    final path = regtest
        ? '${File(databasePath).parent.path}${Platform.pathSeparator}payjoin-regtest.sqlite'
        : databasePath;
    final database = openPayjoinDatabaseForTesting(path);
    var migrating = false;
    try {
      await database.customSelect('SELECT 1').getSingle();
      migrating = true;
      if (regtest) {
        await PayjoinPolicyStore(database).ensureDefaults();
      } else {
        await importLegacyPayjoinData(database, legacyData, log: log);
      }
      return Ok((database: database, close: database.close));
    } catch (error, trace) {
      await database.close();
      PayjoinLogger(log).severe(
        code: PayjoinLogCode.migrationFailure,
        error: error,
        trace: trace,
      );
      return Err(
        migrating
            ? const PayjoinMigrationFailure('Could not migrate Payjoin storage')
            : const PayjoinStorageFailure('Could not open Payjoin storage'),
      );
    }
  },
  wallet: wallet,
  blockchain: blockchain,
  fees: fees,
  transactions: transactions,
  labels: labels,
  log: log,
  codec: codec,
  regtestProfile: regtestProfile,
  regtestHostProfile: regtestHostProfile,
  isCurrent: isCurrent,
);
