import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'coins_state.freezed.dart';

/// Top-level screen status. `ready`/`empty` are distinguished so the UI can
/// show the empty-state copy only after a completed load returned zero coins.
enum CoinsStatus { loading, ready, empty, error }

@freezed
abstract class CoinsState with _$CoinsState {
  const factory CoinsState({
    required String walletId,
    @Default(CoinsStatus.loading) CoinsStatus status,
    @Default([]) List<WalletUtxo> utxos,
    @Default({}) Set<String> allLabels,
    @Default(CoinsFilter()) CoinsFilter filter,
    @Default(false) bool selecting,
    @Default({}) Set<String> selectedOutpoints,
    @Default(false) bool syncing,
    CoinsError? error,
  }) = _CoinsState;

  const CoinsState._();

  /// The visible list — the pure sort/filter transform applied to [utxos].
  List<WalletUtxo> get visible => sortAndFilterUtxos(utxos, filter);

  /// The selected UTXO entities (intersection of selection with current utxos).
  List<WalletUtxo> get selectedUtxos => utxos
      .where((u) => selectedOutpoints.contains(utxoOutpointKey(u)))
      .toList();

  /// Total amount across all UTXOs, in sats.
  BigInt get totalSat => utxos.fold(BigInt.zero, (sum, u) => sum + u.amountSat);

  /// Total frozen amount, in sats.
  BigInt get frozenSat => utxos
      .where((u) => u.isFrozen)
      .fold(BigInt.zero, (sum, u) => sum + u.amountSat);

  /// Spendable (unfrozen) amount, in sats.
  BigInt get spendableSat => totalSat - frozenSat;

  bool get hasFrozen => utxos.any((u) => u.isFrozen);

  /// Whether the visible list is empty *because* a filter is narrowing it
  /// (distinct from "wallet has no coins").
  bool get isFilteredEmpty =>
      visible.isEmpty && utxos.isNotEmpty && filter.hasActiveFilter;

  bool get anySelectedFrozen => selectedUtxos.any((u) => u.isFrozen);

  bool get anySelectedUnfrozen => selectedUtxos.any((u) => !u.isFrozen);
}
