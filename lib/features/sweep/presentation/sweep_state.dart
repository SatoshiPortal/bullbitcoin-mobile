import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sweep_state.freezed.dart';

/// Where the user is in the sweep flow.
enum SweepStep {
  /// Splitting the selected coins across recipients.
  allocate,

  /// Reviewing the built transaction before signing.
  review,

  /// Broadcast, with a txid.
  success,
}

@freezed
sealed class SweepState with _$SweepState {
  const factory SweepState({
    required String walletId,
    required Network network,

    /// The coins handed over by the Coins screen — the exact set that will be
    /// spent. Never grows or shrinks during the flow.
    required List<WalletUtxo> inputs,
    @Default([SweepAllocation(address: '')]) List<SweepAllocation> allocations,
    @Default(SweepStep.allocate) SweepStep step,
    FeeOptions? feePresets,
    @Default(FeeSelection.economic) FeeSelection selectedFeeOption,
    NetworkFee? customFee,

    /// Real fee per preset, each read off a PSBT actually built for the plan
    /// under review. Feeds the shared fee modal and lets the confirm path
    /// broadcast the exact bytes the user priced.
    @Default(BitcoinFeePreviewCache()) BitcoinFeePreviewCache feePreviewCache,

    /// Selection to roll back to when the user opens the custom-fee field and
    /// dismisses without committing a valid rate. Null when nothing is armed.
    FeeSelection? armPriorSelection,
    NetworkFee? armPriorCustomFee,

    /// Fiat hints for the fee modal. Zero/empty simply hides them.
    @Default(0.0) double exchangeRate,
    @Default('') String fiatCurrencyCode,

    /// The wallet's own unused change addresses, offered in the address field.
    @Default([]) List<WalletAddress> ownChangeAddresses,

    /// The built, unsigned transaction under review. Cleared whenever the
    /// allocation or the fee changes, so a stale quote can never be signed.
    SweepQuote? quote,
    @Default(false) bool loadingFees,
    @Default(false) bool building,
    @Default(false) bool broadcasting,
    String? txId,
    SweepFailure? failure,
  }) = _SweepState;

  const SweepState._();

  /// Total value of the coins being swept.
  BigInt get totalInputSat =>
      inputs.fold(BigInt.zero, (sum, u) => sum + u.amountSat);

  /// Sum of the amounts pinned on the non-remainder rows.
  BigInt get allocatedSat => allocations
      .where((a) => !a.takesRemainder && a.amountSat != null)
      .fold(BigInt.zero, (sum, a) => sum + a.amountSat!);

  /// What is still unassigned, before the network fee. Goes to the remainder
  /// recipient when there is one, otherwise back as change. Can go negative
  /// while the user is over-allocating — the UI shows that as an error.
  BigInt get unallocatedSat => totalInputSat - allocatedSat;

  bool get isOverAllocated => allocatedSat > totalInputSat;

  /// Whether a row absorbs the remainder, which suppresses the change output.
  bool get hasRemainderRow => allocations.any((a) => a.takesRemainder);

  /// The fee currently chosen, resolved from the preset list or the custom
  /// value. Null until the presets have loaded.
  NetworkFee? get selectedFee => switch (selectedFeeOption) {
    FeeSelection.fastest => feePresets?.fastest,
    FeeSelection.economic => feePresets?.economic,
    FeeSelection.slow => feePresets?.slow,
    FeeSelection.custom => customFee,
  };

  /// Whether the form is complete enough to attempt a build. Deliberately
  /// permissive — the authoritative rules live in [SweepPlan.validate], this
  /// only drives whether the Continue button is enabled.
  bool get canReview {
    if (inputs.isEmpty || allocations.isEmpty) return false;
    if (selectedFee == null) return false;
    if (building) return false;
    if (allocations.any((a) => a.address.trim().isEmpty)) return false;
    if (allocations.any((a) => !a.takesRemainder && a.amountSat == null)) {
      return false;
    }
    return !isOverAllocated;
  }

  bool get isBusy => building || broadcasting;
}
