import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:primitives/primitives.dart';

import 'data/wallet_history_datasource.dart';
import 'data/wallet_transaction_repository_impl.dart';
import 'domain/usecases/wallet_history_events.dart';
import 'domain/usecases/watch_wallet_transaction_by_address_usecase.dart';

import 'package:exchange/exchange.dart';
import 'package:transactions/src/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:transactions/src/domain/repositories/wallet_transaction_repository.dart';
import 'package:transactions/src/domain/usecases/get_wallet_transaction_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'package:labels/labels.dart';
import 'package:transactions/src/data/csv_transaction_export_formatter.dart';
import 'package:transactions/src/domain/transaction_export_formatter.dart';
import 'package:transactions/src/domain/usecases/save_transactions_csv_usecase.dart';
import 'package:transactions/src/domain/usecases/export_transactions_csv_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transactions_by_tx_id_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transactions_usecase.dart';
import 'package:transactions/src/domain/usecases/refresh_transaction_labels_usecase.dart';
import 'package:transactions/src/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:transactions/src/domain/usecases/get_payjoin_by_id_usecase.dart';
import 'package:transactions/src/domain/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_payjoin_usecase.dart';
import 'package:transactions/src/domain/usecases/label_exchange_orders_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_order_swaps_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_order_swap_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_transaction_order_swap_usecase.dart';
import 'package:transactions/src/domain/usecases/delete_transaction_note_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_note_suggestions_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_order_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_swap_usecase.dart';
import 'package:transactions/src/domain/usecases/get_transaction_wallet_usecase.dart';
import 'package:transactions/src/domain/usecases/save_transaction_note_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_transaction_swap_usecase.dart';
import 'package:swaps/order_swaps.dart';
import 'package:transactions/src/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:transactions/src/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:transactions/src/presentation/blocs/transaction_status/transaction_status_cubit.dart';
import 'package:transactions/src/presentation/blocs/transactions_cubit.dart';
import 'package:transactions/src/domain/usecases/read_transaction_payment_animations_usecase.dart';
import 'package:transactions/src/domain/usecases/watch_settlement_transaction_usecase.dart';
import 'package:file_system/file_system.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class TransactionsLocator {
  static void registerHistory(
    GetIt locator, {
    required WalletInventory inventory,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required Future<Result<PublicWalletDescriptor, SyncFailure>> Function(
      WalletKey,
    )
    findDescriptor,
    required Future<Result<void, SyncFailure>> Function(PublicWalletDescriptor)
    synchronize,
    required WalletHistoryEvents events,
  }) {
    Future<Result<void, SyncFailure>> syncWallet(WalletKey key) async {
      return switch (await findDescriptor(key)) {
        Ok(:final value) => synchronize(value),
        Err(:final failure) => Err(failure),
      };
    }

    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        inventory: inventory,
        labelsFacade: locator<Labels>(),
        history: WalletHistoryDatasource(load: loadWallet),
        synchronize: syncWallet,
      ),
    );
    locator.registerFactory(
      () => GetWalletTransactionUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory(
      () => WatchWalletTransactionByAddressUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletFacade: events,
      ),
    );
    locator.registerFactory(
      () => WatchWalletTransactionByTxIdUsecase(
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        walletFacade: events,
      ),
    );
    locator.registerFactory(
      () => GetTransactionWalletUsecase(inventory, syncWallet),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetPayjoinByIdUsecase>(
      () => GetPayjoinByIdUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetPayjoinByTxIdUsecase>(
      () => GetPayjoinByTxIdUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<LabelExchangeOrdersUsecase>(
      () => LabelExchangeOrdersUsecase(
        labelsFacade: locator<Labels>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
      ),
    );
    locator.registerFactory<GetTransactionSwapUsecase>(
      () => GetTransactionSwapUsecase(locator<GetSwapUsecase>()),
    );
    locator.registerFactory<WatchTransactionSwapUsecase>(
      () => WatchTransactionSwapUsecase(locator<WatchSwapUsecase>()),
    );
    locator.registerFactory<GetTransactionOrderUsecase>(
      () => GetTransactionOrderUsecase(
        locator<Exchange>(),
        locator<Preferences>(),
      ),
    );
    locator.registerFactory<SaveTransactionNoteUsecase>(
      () => SaveTransactionNoteUsecase(locator<Labels>()),
    );
    locator.registerFactory<DeleteTransactionNoteUsecase>(
      () => DeleteTransactionNoteUsecase(locator<Labels>()),
    );
    locator.registerFactory<GetTransactionNoteSuggestionsUsecase>(
      () => GetTransactionNoteSuggestionsUsecase(locator<Labels>()),
    );

    locator.registerFactory<GetTransactionOrderSwapsUsecase>(
      () => GetTransactionOrderSwapsUsecase(locator<ReadOrderSwaps>()),
    );
    locator.registerFactory<GetTransactionOrderSwapUsecase>(
      () => GetTransactionOrderSwapUsecase(locator<ReadOrderSwaps>()),
    );
    locator.registerFactory<WatchTransactionOrderSwapUsecase>(
      () => WatchTransactionOrderSwapUsecase(locator<ReadOrderSwaps>()),
    );
    locator.registerFactory<GetTransactionsUsecase>(
      () => GetTransactionsUsecase(
        settingsRepository: locator<Preferences>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        swapStore: locator<SwapStore>(),
        payjoinSessions: locator<PayjoinSessions>(),
        exchange: locator<Exchange>(),
        labelExchangeOrdersUsecase: locator<LabelExchangeOrdersUsecase>(),
        getTransactionOrderSwapsUsecase:
            locator<GetTransactionOrderSwapsUsecase>(),
      ),
    );

    locator.registerFactory<RefreshTransactionLabelsUsecase>(
      () => RefreshTransactionLabelsUsecase(labelsFacade: locator<Labels>()),
    );

    locator.registerFactory<ExportTransactionsCsvUsecase>(
      () => ExportTransactionsCsvUsecase(
        getTransactionsUsecase: locator<GetTransactionsUsecase>(),
        formatter: locator<TransactionExportFormatter>(),
      ),
    );

    locator.registerFactory<GetTransactionsByTxIdUsecase>(
      () => GetTransactionsByTxIdUsecase(
        settingsRepository: locator<Preferences>(),
        walletTransactionRepository: locator<WalletTransactionRepository>(),
        swapStore: locator<SwapStore>(),
        payjoinSessions: locator<PayjoinSessions>(),
        exchange: locator<Exchange>(),
        getTransactionOrderSwapsUsecase:
            locator<GetTransactionOrderSwapsUsecase>(),
      ),
    );
  }

  static void registerAdapters(GetIt locator) {
    locator.registerLazySingleton<TransactionExportFormatter>(
      CsvTransactionExportFormatter.new,
    );

    locator.registerLazySingleton<SaveTransactionsCsvUsecase>(
      () => const SaveTransactionsCsvUsecase(FileSystem.open()),
    );
  }

  static void registerBlocs(
    GetIt locator,
    WalletHistoryEvents events,
    Stream<String> Function() started,
    Stream<String> Function() finished,
  ) {
    // Bloc
    locator.registerFactoryParam<TransactionsCubit, String?, bool?>(
      (walletId, exchangeOnly) => TransactionsCubit(
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(events),
        watchTransactionReloadsUsecase: WatchTransactionReloadsUsecase(events),
        walletId: walletId,
        exchangeOnly: exchangeOnly ?? false,
        getTransactionsUsecase: locator<GetTransactionsUsecase>(),
        refreshTransactionLabelsUsecase:
            locator<RefreshTransactionLabelsUsecase>(),
        watchStartedWalletSyncsUsecase: started(),
        watchFinishedWalletSyncsUsecase: finished(),
      ),
    );
    locator.registerFactory<ReadTransactionPaymentAnimationsUsecase>(
      () => ReadTransactionPaymentAnimationsUsecase(locator<Preferences>()),
    );
    locator.registerFactory<WatchSettlementTransactionUsecase>(
      () => WatchSettlementTransactionUsecase(
        locator<GetWalletTransactionUsecase>(),
        locator<WatchWalletTransactionByTxIdUsecase>(),
      ),
    );
    locator.registerFactory<TransactionStatusCubit>(
      () => TransactionStatusCubit(
        readAnimations: locator<ReadTransactionPaymentAnimationsUsecase>(),
        watchSettlement: locator<WatchSettlementTransactionUsecase>(),
      ),
    );
    locator.registerFactory<ExportTransactionsCubit>(
      () => ExportTransactionsCubit(
        exportTransactionsCsvUsecase: locator<ExportTransactionsCsvUsecase>(),
        saver: locator<SaveTransactionsCsvUsecase>(),
      ),
    );
    locator.registerFactory<TransactionDetailsCubit>(
      () => TransactionDetailsCubit(
        getTransactionWalletUsecase: locator<GetTransactionWalletUsecase>(),
        getTransactionsByTxIdUsecase: locator<GetTransactionsByTxIdUsecase>(),
        getWalletTransactionUsecase: locator<GetWalletTransactionUsecase>(),
        getTransactionOrderSwapUsecase:
            locator<GetTransactionOrderSwapUsecase>(),
        watchWalletTransactionByTxIdUsecase:
            locator<WatchWalletTransactionByTxIdUsecase>(),
        getTransactionSwapUsecase: locator<GetTransactionSwapUsecase>(),
        getPayjoinByIdUsecase: locator<GetPayjoinByIdUsecase>(),
        getPayjoinByTxIdUsecase: locator<GetPayjoinByTxIdUsecase>(),
        getTransactionOrderUsecase: locator<GetTransactionOrderUsecase>(),
        watchTransactionSwapUsecase: locator<WatchTransactionSwapUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchTransactionOrderSwapUsecase:
            locator<WatchTransactionOrderSwapUsecase>(),
        saveTransactionNoteUsecase: locator<SaveTransactionNoteUsecase>(),
        deleteTransactionNoteUsecase: locator<DeleteTransactionNoteUsecase>(),
        getTransactionNoteSuggestionsUsecase:
            locator<GetTransactionNoteSuggestionsUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        retrySwapUsecase: locator<RetrySwapUsecase>(),
      ),
    );
  }
}
