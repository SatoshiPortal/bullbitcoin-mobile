import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/load_autoswap_settings_usecase.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/save_autoswap_settings_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

@freezed
part 'autoswap_settings_cubit.freezed.dart';
part 'autoswap_settings_state.dart';

class AutoSwapSettingsCubit extends Cubit<AutoSwapSettingsState> {
  final LoadAutoswapSettingsUsecase _loadAutoswapSettingsUsecase;
  final SaveAutoswapSettingsUsecase _saveAutoswapSettingsUsecase;

  AutoSwapSettingsCubit({
    required this._loadAutoswapSettingsUsecase,
    required this._saveAutoswapSettingsUsecase,
  }) : super(const AutoSwapSettingsState());

  Future<void> loadSettings() async {
    emit(state.copyWith(loading: true, failure: null));

    final result = await _loadAutoswapSettingsUsecase.execute();
    if (isClosed) return;

    switch (result) {
      case Ok(value: final data):
        final settings = data.settings;
        emit(
          state.copyWith(
            loading: false,
            settings: settings,
            amountThresholdInput: _formatAmount(
              settings.balanceThresholdSats,
              data.bitcoinUnit,
            ),
            triggerBalanceSatsInput: _formatAmount(
              settings.triggerBalanceSats,
              data.bitcoinUnit,
            ),
            feeThresholdInput: settings.feeThresholdPercent.toString(),
            enabledToggle: settings.enabled,
            alwaysBlock: settings.alwaysBlock,
            bitcoinUnit: data.bitcoinUnit,
            availableBitcoinWallets: data.bitcoinWallets,
            selectedBitcoinWalletId: data.recipientWalletId,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
    }
  }

  Future<void> updateSettings() => _save(enabled: state.enabledToggle);

  Future<void> _save({required bool enabled}) async {
    emit(
      state.copyWith(
        saving: true,
        successfullySaved: false,
        failure: null,
        amountThresholdFailure: null,
        triggerBalanceFailure: null,
        feeThresholdFailure: null,
      ),
    );

    final unit = state.unit;
    final result = await _saveAutoswapSettingsUsecase.execute(
      AutoSwap(
        enabled: enabled,
        balanceThresholdSats: _toSats(state.amountThresholdInput ?? '0', unit),
        triggerBalanceSats: _toSats(state.triggerBalanceSatsInput ?? '0', unit),
        feeThresholdPercent: _toFeePercent(state.feeThresholdInput ?? ''),
        alwaysBlock: state.alwaysBlock,
        recipientWalletId: state.selectedBitcoinWalletId,
        // Keep the warning pending only while auto swap stays on; disabling
        // clears it so re-enabling shows it again.
        showWarning: enabled ? state.settings?.showWarning ?? true : false,
      ),
    );
    if (isClosed) return;

    switch (result) {
      case Ok():
        emit(state.copyWith(saving: false, successfullySaved: true));
      case Err(:final failure):
        emit(_withFailurePlaced(failure));
    }
  }

  /// Puts a failure next to the field it is about, so the form can render it
  /// inline. Anything not field-specific goes to the shared slot.
  AutoSwapSettingsState _withFailurePlaced(AutoswapFailure failure) =>
      switch (failure) {
        AutoswapBalanceThresholdTooLowFailure() => state.copyWith(
          saving: false,
          amountThresholdFailure: failure,
        ),
        AutoswapTriggerBalanceTooLowFailure() => state.copyWith(
          saving: false,
          triggerBalanceFailure: failure,
        ),
        AutoswapFeeThresholdTooHighFailure() => state.copyWith(
          saving: false,
          feeThresholdFailure: failure,
        ),
        _ => state.copyWith(saving: false, failure: failure),
      };

  void onAmountThresholdChanged(String value) {
    // Remove decimal points if unit is sats
    final sanitizedValue = state.bitcoinUnit == BitcoinUnit.sats
        ? value.replaceAll(RegExp(r'[^\d]'), '')
        : value;
    final unit = state.unit;

    // Only nag once something has actually been entered: an empty or zero
    // field is still being typed, not yet wrong.
    final amountSats = _toSats(sanitizedValue, unit);
    final triggerSats = _toSats(state.triggerBalanceSatsInput ?? '', unit);

    emit(
      state.copyWith(
        amountThresholdInput: sanitizedValue,
        amountThresholdFailure:
            amountSats > 0 && AutoSwap.isBalanceThresholdTooLow(amountSats)
            ? const AutoswapBalanceThresholdTooLowFailure(
                AutoSwap.minimumBalanceThresholdSats,
              )
            : null,
        triggerBalanceFailure:
            amountSats > 0 &&
                triggerSats > 0 &&
                AutoSwap.isTriggerBalanceTooLow(
                  balanceThresholdSats: amountSats,
                  triggerBalanceSats: triggerSats,
                )
            ? const AutoswapTriggerBalanceTooLowFailure()
            : null,
      ),
    );
  }

  void onTriggerBalanceChanged(String value) {
    final sanitizedValue = state.bitcoinUnit == BitcoinUnit.sats
        ? value.replaceAll(RegExp(r'[^\d]'), '')
        : value;
    final unit = state.unit;

    final triggerSats = _toSats(sanitizedValue, unit);
    final amountSats = _toSats(state.amountThresholdInput ?? '', unit);

    emit(
      state.copyWith(
        triggerBalanceSatsInput: sanitizedValue,
        triggerBalanceFailure:
            triggerSats > 0 &&
                amountSats > 0 &&
                AutoSwap.isTriggerBalanceTooLow(
                  balanceThresholdSats: amountSats,
                  triggerBalanceSats: triggerSats,
                )
            ? const AutoswapTriggerBalanceTooLowFailure()
            : null,
      ),
    );
  }

  void onFeeThresholdChanged(String value) {
    // Remove any decimal points from fee input
    final sanitizedValue = value.replaceAll(RegExp(r'[^\d]'), '');
    emit(
      state.copyWith(
        feeThresholdInput: sanitizedValue,
        feeThresholdFailure: null,
      ),
    );
  }

  void onEnabledToggleChanged(bool value) {
    emit(state.copyWith(enabledToggle: value));

    // Auto-save and close when disabled
    if (!value) _save(enabled: false);
  }

  void onInfoToggleChanged() {
    emit(state.copyWith(showInfo: !state.showInfo));
  }

  void onAlwaysBlockToggleChanged(bool value) {
    emit(state.copyWith(alwaysBlock: value));
  }

  void onWalletSelected(String? walletId) {
    emit(
      state.copyWith(
        selectedBitcoinWalletId: walletId,
        // Clear any previous failure when a wallet is selected
        failure: null,
      ),
    );
  }

  void toggleBitcoinUnit() {
    emit(state.toggleBitcoinUnit());
  }

  static int _toSats(String input, BitcoinUnit unit) => unit == BitcoinUnit.btc
      ? ConvertAmount.btcToSats(double.tryParse(input) ?? 0)
      : int.tryParse(input) ?? 0;

  static double _toFeePercent(String input) =>
      double.tryParse(input) ?? AutoSwap.defaultFeeThresholdPercent;

  static String _formatAmount(int sats, BitcoinUnit unit) =>
      unit == BitcoinUnit.btc
      ? ConvertAmount.satsToBtc(sats).toString()
      : sats.toString();
}
