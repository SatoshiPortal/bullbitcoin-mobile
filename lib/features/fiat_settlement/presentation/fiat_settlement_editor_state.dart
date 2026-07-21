import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';

enum FiatSettlementEditorStatus { loading, ready, saving, success, loadError }

/// How the merchant wants to receive funds — the three chooser options.
enum FiatSettlementReceiveMode { bitcoin, fiat, mix }

class FiatSettlementEditorState {
  final FiatSettlementEditorStatus status;
  final FiatSettlementProduct product;

  /// The server-confirmed saved configuration for this product (null until
  /// loaded). Drives the summary and whether this is a first activation.
  final FiatSettlementProductConfig? saved;

  // Draft selections (never shown as active until the server confirms a save).
  final FiatSettlementReceiveMode mode;
  final int mixFiatPercentage; // 0..100, used only when mode == mix
  final FiatCurrency? currency;
  final bool understood;

  /// Whether a Bull Bitcoin account is connected on THIS device (a purely local
  /// check). Fiat/mixed modes require a connection; Bitcoin mode never does.
  final bool hasBullBitcoinAccount;

  /// The last operation's failure (save/disable), for the outcome UI.
  final FiatSettlementFailure? failure;

  const FiatSettlementEditorState({
    required this.status,
    required this.product,
    this.saved,
    this.mode = FiatSettlementReceiveMode.bitcoin,
    this.mixFiatPercentage = 50,
    this.currency,
    this.understood = false,
    this.hasBullBitcoinAccount = true,
    this.failure,
  });

  factory FiatSettlementEditorState.initial(FiatSettlementProduct product) =>
      FiatSettlementEditorState(
        status: FiatSettlementEditorStatus.loading,
        product: product,
      );

  /// The effective fiat percentage implied by the current draft mode.
  int get effectiveFiatPercentage => switch (mode) {
    FiatSettlementReceiveMode.bitcoin => 0,
    FiatSettlementReceiveMode.fiat => 100,
    FiatSettlementReceiveMode.mix => mixFiatPercentage,
  };

  /// True when the product currently settles fully to Bitcoin, so a nonzero
  /// save is a first activation (which may offer "Continue with Bitcoin only").
  bool get isFirstActivation => saved?.isBitcoinOnly ?? true;

  /// Whether the disclosure + "I understand" gate applies: enabling fiat, or
  /// changing the currency. An effective 0% (Bitcoin-only save) and a
  /// percentage-only change on the same currency need neither.
  bool get requiresAcceptance {
    if (effectiveFiatPercentage == 0) return false;
    final savedConfig = saved;
    final isCurrencyChange =
        savedConfig == null ||
        savedConfig.isBitcoinOnly ||
        savedConfig.currency != currency;
    return isCurrencyChange;
  }

  /// Whether Save may proceed with the current draft.
  bool get canSave {
    if (status == FiatSettlementEditorStatus.saving) return false;
    // An effective 0% is a Bitcoin-only save (disable) — always allowed.
    if (effectiveFiatPercentage == 0) return true;
    if (currency == null) return false;
    if (requiresAcceptance && !understood) return false;
    return true;
  }

  FiatSettlementEditorState copyWith({
    FiatSettlementEditorStatus? status,
    FiatSettlementProductConfig? saved,
    FiatSettlementReceiveMode? mode,
    int? mixFiatPercentage,
    FiatCurrency? currency,
    bool? understood,
    bool? hasBullBitcoinAccount,
    FiatSettlementFailure? failure,
    bool clearFailure = false,
    bool clearCurrency = false,
  }) {
    return FiatSettlementEditorState(
      status: status ?? this.status,
      product: product,
      saved: saved ?? this.saved,
      mode: mode ?? this.mode,
      mixFiatPercentage: mixFiatPercentage ?? this.mixFiatPercentage,
      currency: clearCurrency ? null : (currency ?? this.currency),
      understood: understood ?? this.understood,
      hasBullBitcoinAccount:
          hasBullBitcoinAccount ?? this.hasBullBitcoinAccount,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
