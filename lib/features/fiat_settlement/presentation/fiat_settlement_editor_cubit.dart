import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/has_bull_bitcoin_account_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/presentation/fiat_settlement_editor_state.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the shared fiat-settlement editor for one product. A draft is never
/// shown as active until the server confirms a save; a failed save/disable
/// preserves the previously saved configuration exactly.
class FiatSettlementEditorCubit extends Cubit<FiatSettlementEditorState> {
  final FiatSettlementFacade _facade;
  final HasBullBitcoinAccountUsecase _hasBullBitcoinAccount;

  int _operationId = 0;

  FiatSettlementEditorCubit({
    required this._facade,
    required this._hasBullBitcoinAccount,
    required FiatSettlementProduct product,
  }) : super(FiatSettlementEditorState.initial(product));

  bool _isStale(int op) => op != _operationId || isClosed;

  Future<void> load() async {
    final op = ++_operationId;
    emit(state.copyWith(status: FiatSettlementEditorStatus.loading));
    // Local-only connection check. Fail open (assume connected) so an
    // unexpected read error never blocks a genuinely connected merchant; a
    // truly missing credential still surfaces at Save.
    bool hasAccount = true;
    try {
      hasAccount = await _hasBullBitcoinAccount.execute();
    } catch (_) {
      hasAccount = true;
    }
    final result = await _facade.configuration();
    if (_isStale(op)) return;
    switch (result) {
      case Ok(:final value):
        final config = value.configFor(state.product);
        emit(
          state.copyWith(
            status: FiatSettlementEditorStatus.ready,
            saved: config,
            mode: _modeFor(config),
            mixFiatPercentage: config.mode == FiatSettlementMode.mixed
                ? config.fiatPercentage
                : 50,
            currency: config.currency,
            hasBullBitcoinAccount: hasAccount,
          ),
        );
      case Err():
        // A read failure leaves the editor unusable but never destructive.
        emit(state.copyWith(status: FiatSettlementEditorStatus.loadError));
    }
  }

  void selectMode(FiatSettlementReceiveMode mode) {
    emit(state.copyWith(mode: mode, clearFailure: true, understood: false));
  }

  void setMixPercentage(int fiatPercentage) {
    final clamped = fiatPercentage.clamp(0, 100);
    emit(state.copyWith(mixFiatPercentage: clamped, clearFailure: true));
  }

  void selectCurrency(FiatCurrency currency) {
    // Changing currency re-arms the acceptance gate.
    emit(
      state.copyWith(
        currency: currency,
        understood: false,
        clearFailure: true,
      ),
    );
  }

  void setUnderstood(bool value) {
    emit(state.copyWith(understood: value, clearFailure: true));
  }

  Future<void> save() async {
    if (!state.canSave) return;
    // An effective 0% (Bitcoin mode, or the mix slider at 0% fiat) is a
    // disable, which needs no currency/acceptance.
    if (state.effectiveFiatPercentage == 0) {
      return _disable();
    }
    final currency = state.currency;
    if (currency == null) return;

    final op = ++_operationId;
    emit(
      state.copyWith(
        status: FiatSettlementEditorStatus.saving,
        clearFailure: true,
      ),
    );
    final result = await _facade.set(
      product: state.product,
      fiatPercentage: state.effectiveFiatPercentage,
      currency: currency,
    );
    if (_isStale(op)) return;
    _applyResult(result);
  }

  /// Switch the product back to Bitcoin-only. Always available, even when the
  /// server rejected a prior activation.
  Future<void> disable() => _disable();

  Future<void> _disable() async {
    final op = ++_operationId;
    emit(
      state.copyWith(
        status: FiatSettlementEditorStatus.saving,
        clearFailure: true,
      ),
    );
    final result = await _facade.disable(product: state.product);
    if (_isStale(op)) return;
    _applyResult(result);
  }

  void _applyResult(
    Result<FiatSettlementConfigurationView, FiatSettlementFailure> result,
  ) {
    switch (result) {
      case Ok(:final value):
        final config = value.configFor(state.product);
        emit(
          state.copyWith(
            status: FiatSettlementEditorStatus.success,
            saved: config,
            mode: _modeFor(config),
            currency: config.currency,
          ),
        );
      case Err(:final failure):
        // Preserve the prior saved config; surface the failure for the outcome
        // UI. The draft selections stay so the merchant can retry.
        emit(
          state.copyWith(
            status: FiatSettlementEditorStatus.ready,
            failure: failure,
          ),
        );
    }
  }

  FiatSettlementReceiveMode _modeFor(FiatSettlementProductConfig config) {
    return switch (config.mode) {
      FiatSettlementMode.bitcoinOnly => FiatSettlementReceiveMode.bitcoin,
      FiatSettlementMode.fiatOnly => FiatSettlementReceiveMode.fiat,
      FiatSettlementMode.mixed => FiatSettlementReceiveMode.mix,
    };
  }
}
