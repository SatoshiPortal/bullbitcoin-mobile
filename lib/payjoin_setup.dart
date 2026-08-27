import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/payjoin_legacy_data_adapter.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/payjoin_runtime_adapters.dart';
import 'package:bb_mobile/recoverable_payjoin.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class PayjoinSetup {
  static void setup(
    GetIt locator,
    SqliteDatabase database, {
    String? databasePath,
    bool startRecovery = true,
  }) {
    final runtime = RecoverablePayjoin(() async {
      final path =
          databasePath ??
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'payjoin.sqlite',
          );
      return openPayjoin(
        databasePath: path,
        wallet: PayjoinWalletAdapter(
          locator<SeedDatasource>(),
          locator<BdkWalletDatasource>(),
          locator<WalletMetadataDatasource>(),
        ),
        blockchain: AppPayjoinBlockchainAdapter(
          locator<BdkBitcoinBlockchainDatasource>(),
          locator<ElectrumServersPort>(),
        ),
        fees: AppPayjoinFeesAdapter(locator<FeesRepository>()),
        transactions: AppPayjoinTransactionAdapter(
          locator<WalletRepository>(),
          locator<WalletTransactionRepository>(),
        ),
        labels: AppPayjoinLabelsAdapter(locator<LabelsFacade>()),
        legacyData: PayjoinLegacyDataAdapter(database),
        log: const AppPayjoinLogAdapter(),
      );
    });
    _registerRoles(locator, runtime.payjoin);
    locator.registerSingleton<PayjoinLifecycle>(runtime);

    // Opening the package database and resuming sessions must not delay
    // runApp. Background isolates (workmanager handler) register the roles
    // but must NOT start recovery: the engine's own invariant is that only
    // the foreground composition root resumes sessions — a BG isolate would
    // open payjoin.sqlite concurrently with the foreground engine and run
    // the legacy migration + recovery sweep inside a ~30s iOS budget.
    if (startRecovery) {
      unawaited(
        Future<void>(() async {
          await runtime.resume();
        }),
      );
    }
  }

  static void _registerRoles(GetIt locator, Payjoin payjoin) {
    locator.registerSingleton<Payjoin>(payjoin);
    locator.registerSingleton<PayjoinSender>(payjoin.sender);
    locator.registerSingleton<PayjoinReceiver>(payjoin.receiver);
    locator.registerSingleton<PayjoinSessions>(payjoin.sessions);
    locator.registerSingleton<PayjoinPolicyAccess>(payjoin.policy);
    locator.registerSingleton<PayjoinDiagnostics>(payjoin.diagnostics);
  }
}
