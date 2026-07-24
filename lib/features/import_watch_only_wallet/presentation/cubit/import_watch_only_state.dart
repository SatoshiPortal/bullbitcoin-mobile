import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_watch_only_state.freezed.dart';

@freezed
abstract class ImportWatchOnlyState with _$ImportWatchOnlyState {
  const factory ImportWatchOnlyState({
    WatchOnlyWalletEntity? watchOnlyWallet,
    Wallet? importedWallet,
    @Default('') String input,
    ImportWatchOnlyFailure? failure,
    // Whether the compact-block-filter choice is offered at all — the same
    // build/developer-mode gate as `WalletOptionsScreen`'s per-wallet tile
    // (see `CheckCompactBlockFiltersAvailableUsecase`). Electrum is always
    // offered and needs no such gate.
    @Default(false) bool isCbfAvailable,
    @Default(BitcoinSyncBackend.electrum) BitcoinSyncBackend syncBackend,
    // The user-picked wallet birthday, only consulted when [syncBackend] is
    // `BitcoinSyncBackend.compactBlockFilters`. `null` means "the earliest
    // possible date" (this network's genesis block) — the picker's own
    // default, and the only choice that can never fail to resolve.
    DateTime? birthday,
  }) = _ImportWatchOnlyState;

  const ImportWatchOnlyState._();
}
