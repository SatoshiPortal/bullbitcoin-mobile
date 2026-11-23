import 'package:sync/sync.dart';

import 'src/domain/usecases/wallet_history_events.dart';

export 'transactions.dart';
export 'src/data/csv_transaction_export_formatter.dart';
export 'src/data/models/wallet_transaction_model.dart';
export 'src/data/wallet_history_datasource.dart';
export 'src/data/wallet_transaction_repository_impl.dart';
export 'src/domain/entities/transaction.dart';
export 'src/domain/entities/transaction_output.dart';
export 'src/domain/entities/wallet_transaction.dart';
export 'src/domain/repositories/wallet_transaction_repository.dart';
export 'src/domain/transaction_failure.dart';
export 'src/domain/transaction_label_policy.dart';
export 'src/domain/usecases/broadcast_original_transaction_usecase.dart';
export 'src/domain/usecases/delete_transaction_note_usecase.dart';
export 'src/domain/usecases/export_transactions_csv_usecase.dart';
export 'src/domain/usecases/get_payjoin_by_id_usecase.dart';
export 'src/domain/usecases/get_payjoin_by_tx_id_usecase.dart';
export 'src/domain/usecases/get_transaction_note_suggestions_usecase.dart';
export 'src/domain/usecases/get_transaction_order_swap_usecase.dart';
export 'src/domain/usecases/get_transaction_order_swaps_usecase.dart';
export 'src/domain/usecases/get_transaction_order_usecase.dart';
export 'src/domain/usecases/get_transaction_swap_usecase.dart';
export 'src/domain/usecases/get_transaction_wallet_usecase.dart';
export 'src/domain/usecases/get_transactions_by_tx_id_usecase.dart';
export 'src/domain/usecases/get_transactions_usecase.dart';
export 'src/domain/usecases/get_wallet_transaction_usecase.dart';
export 'src/domain/usecases/label_exchange_orders_usecase.dart';
export 'src/domain/usecases/refresh_transaction_labels_usecase.dart';
export 'src/domain/usecases/save_transaction_note_usecase.dart';
export 'src/domain/usecases/save_transactions_csv_usecase.dart';
export 'src/domain/usecases/watch_payjoin_usecase.dart';
export 'src/domain/usecases/watch_transaction_order_swap_usecase.dart';
export 'src/domain/usecases/watch_transaction_reloads_usecase.dart';
export 'src/domain/usecases/watch_transaction_swap_usecase.dart';
export 'src/domain/usecases/watch_wallet_revisions_usecase.dart';
export 'src/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
export 'src/domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
export 'src/presentation/blocs/export/export_transactions_cubit.dart';
export 'src/presentation/blocs/export/export_transactions_state.dart';
export 'src/presentation/blocs/transaction_details/transaction_details_cubit.dart';
export 'src/presentation/blocs/transactions_cubit.dart';
export 'src/presentation/order_l10n.dart';
export 'src/presentation/order_payment_method_l10n.dart';
export 'src/presentation/order_swap_status_l10n.dart';
export 'src/presentation/transaction_failure_l10n.dart';
export 'src/ui/screens/transaction_details_screen.dart';
export 'src/ui/widgets/broadcast_payjoin_original_tx_button.dart';
export 'src/ui/widgets/transaction_details_table.dart';
export 'src/ui/widgets/txs_filter_item.dart';

WalletHistoryEvents walletHistoryEvents(
  Stream<WalletRevisionState> revisions, {
  Stream<void> syncFinished = const Stream.empty(),
  Stream<bool> syncPassActivity = const Stream.empty(),
  bool Function()? isSyncPassActive,
}) => WalletHistoryEvents(
  watchRevisions: ({walletId}) => revisions.where(
    (event) => walletId == null || event.stamp.key.id == walletId,
  ),
  watchSyncPassActivity: () => syncPassActivity,
  watchSyncFinished: () => syncFinished,
  isSyncPassActive: isSyncPassActive ?? () => false,
);
