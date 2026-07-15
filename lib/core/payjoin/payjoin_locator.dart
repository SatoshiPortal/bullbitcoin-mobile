import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/local_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/pdk_payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/check_payjoin_relay_health_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoins_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class PayjoinLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<LocalPayjoinDatasource>(
      () => LocalPayjoinDatasource(db: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<PdkPayjoinDatasource>(
      // Timeouts bound how long a single directory/relay poll can hang, so a
      // slow OHTTP relay can't hold a polling session in flight for long.
      // All three phases must be bounded: the per-session in-flight guard
      // turns any unbounded await into a permanent stall (the poll's finally
      // never runs, the session id is never removed from the in-flight set,
      // and every later tick is skipped). sendTimeout bounds the request-body
      // upload phase — OHTTP bodies are small, so 10s is ample.
      //
      // receiveTimeout MUST exceed the payjoin directory's long-poll hold:
      // payjo.in (payjoin-mailroom) keeps an empty-mailbox poll open for 30s
      // before answering 202 Accepted (config.rs, `timeout:
      // Duration::from_secs(30)`). A timeout at or below that hold races it
      // and loses every time — each empty poll aborts just before the 202,
      // is misread as a relay failure, and cascades through all three
      // relays, so a payjoin never completes and every send falls back to
      // the original transaction (this was a real, previously-shipped bug —
      // see git history on this line).
      //
      // 35s = the 30s hold + a minimal margin for relay forwarding and
      // OHTTP/TLS overhead — deliberately NOT the generous 60s this used to
      // be. PayjoinConstants.defaultExpireAfterSec is now 60s (1 minute,
      // down from 5), so receiveTimeout must leave room for the session's
      // own expiry check to actually run: at 60s it could not (one hung
      // poll could alone consume the entire session budget, and 3 relays
      // cascading at 60s each could burn 180s — three times the whole
      // session). At 35s, a session gets one full poll cycle with a little
      // headroom, which is what a 1-minute expiry can realistically afford;
      // it does NOT restore multiple full cycles, so a slow counterparty is
      // more likely to miss the window than with the old 5-minute expiry —
      // an accepted trade for faster, more legible failure (see
      // PayjoinConstants.defaultExpireAfterSec).
      () => PdkPayjoinDatasource(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 35),
          ),
        ),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    // Not a lazy singleton, because it should resume payjoins from the
    // moment the app starts.
    locator.registerSingleton<PayjoinRepository>(
      PayjoinRepositoryImpl(
        localPayjoinDatasource: locator<LocalPayjoinDatasource>(),
        pdkPayjoinDatasource: locator<PdkPayjoinDatasource>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        seedDatasource: locator<SeedDatasource>(),
        blockchainDatasource: locator<BdkBitcoinBlockchainDatasource>(),
        serversPort: locator<ElectrumServersPort>(),
        // wallet repositories and the labels facade are registered AFTER this
        // eager singleton (see CoreLocator ordering), so they must be passed
        // as lazy closures — resolving them here would throw. They're only
        // called from broadcast watchers, well after startup.
        walletRepository: () => locator<WalletRepository>(),
        walletTransactionRepository: () =>
            locator<WalletTransactionRepository>(),
        // SettingsRepository is registered just BEFORE payjoin, so it already
        // exists and can be resolved eagerly here. (If the locator ordering
        // ever moves payjoin ahead of settings, switch this to a closure too.)
        settingsRepository: locator<SettingsRepository>(),
        labelsFacade: () => locator<LabelsFacade>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<CheckPayjoinRelayHealthUsecase>(
      () => CheckPayjoinRelayHealthUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );

    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
        settingsRepository: locator<domain.SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetPayjoinByIdUsecase>(
      () => GetPayjoinByIdUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );

    locator.registerFactory<GetPayjoinsUsecase>(
      () => GetPayjoinsUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<WatchPayjoinUsecase>(
      () =>
          WatchPayjoinUsecase(payjoinRepository: locator<PayjoinRepository>()),
    );
  }
}
