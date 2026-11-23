import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';
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
    // Unspent L-BTC output count; null until loaded.
    int? utxoCount,
    // Opaque prepared batches and total fee; null before preparation.
    ConsolidationPreview? preview,
  }) = _ConsolidationState;

  const ConsolidationState._();

  /// Whether a non-empty preview (built PSETs) is available.
  bool get hasPreview => (preview?.transactionCount ?? 0) > 0;

  /// Total network fee across all consolidation transactions, or null if not
  /// yet known (no PSETs built).
  int? get feeSat => hasPreview ? preview?.totalFeeSat : null;

  /// Resulting output/transaction count (`ceil(utxos / maxInputs)`). Prefers the
  /// exact value from [preview], falling back to a client-side estimate.
  int? get transactionCount {
    if (hasPreview) return preview?.transactionCount;
    final count = utxoCount;
    if (count == null) return null;
    final mi = ConsolidationConfig.maximumInputs;
    return (count + mi - 1) ~/ mi;
  }
}
