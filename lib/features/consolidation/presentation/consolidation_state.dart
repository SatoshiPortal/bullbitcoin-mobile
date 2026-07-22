import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'consolidation_state.freezed.dart';

/// Flow status for the consolidation screen. Mirrors the standard Liquid send
/// UX: review (idle) → broadcasting → success, or the failure banner.
enum ConsolidationStatus { idle, broadcasting, success, failed }

@freezed
abstract class ConsolidationState with _$ConsolidationState {
  const factory ConsolidationState({
    required String walletId,
    @Default(ConsolidationStatus.idle) ConsolidationStatus status,
    // Wallet balance for the header/amount row; fetched via GetWalletUsecase
    // (core), not the `wallet` feature's WalletBloc — see ConsolidationCubit.
    @Default(0) int balanceSat,
    // Confirmed L-BTC UTXO count (outputs "before"); null until loaded.
    int? utxoCount,
    // Built batches + total fee; null until `prepare` succeeds.
    ConsolidationPreview? preview,
    ConsolidationFailure? failure,
    // Set after a successful broadcast if one or more decoy outputs failed
    // to freeze (bookkeeping, not a fund-safety issue — see
    // ConsolidateLiquidWalletUsecase.broadcast).
    @Default(0) int unfrozenDecoyCount,
  }) = _ConsolidationState;

  const ConsolidationState._();

  /// Whether a non-empty preview (built batches) is available.
  bool get _hasPreview => preview != null && preview!.batches.isNotEmpty;

  /// Total network fee across all consolidation transactions, or null if not
  /// yet known (no PSETs built).
  int? get feeSat => _hasPreview ? preview!.totalFeeSat : null;

  /// Resulting output/transaction count (`ceil(utxos / maxInputs)`). Prefers the
  /// exact value from [preview], falling back to a client-side estimate.
  int? get transactionCount {
    if (_hasPreview) return preview!.transactionCount;
    final count = utxoCount;
    if (count == null) return null;
    final mi = ConsolidationConfig.maximumInputs;
    return (count + mi - 1) ~/ mi;
  }
}
