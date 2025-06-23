import 'package:bb_mobile/core/errors/autoswap_errors.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

@freezed
part 'autoswap_settings_cubit.freezed.dart';
part 'autoswap_settings_state.dart';

class AutoSwapSettingsCubit extends Cubit<AutoSwapSettingsState> {
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final SaveAutoSwapSettingsUsecase _saveAutoSwapSettingsUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  static const int _minimumAmountThresholdSats = 100000;
  static const int _maximumFeeThreshold = 10;

  AutoSwapSettingsCubit({
    required GetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase,
    required SaveAutoSwapSettingsUsecase saveAutoSwapSettingsUsecase,
    required GetSettingsUsecase getSettingsUsecase,
  }) : _getAutoSwapSettingsUsecase = getAutoSwapSettingsUsecase,
       _saveAutoSwapSettingsUsecase = saveAutoSwapSettingsUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       super(const AutoSwapSettingsState());

  Future<void> loadSettings() async {
    try {
      emit(state.copyWith(loading: true, error: null));
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;
      final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute(
        isTestnet: isTestnet,
      );

      String amountThresholdInput;
      if (settings.bitcoinUnit == BitcoinUnit.btc) {
        // Convert sats to BTC for display
        final btcAmount = ConvertAmount.satsToBtc(
          autoSwapSettings.balanceThresholdSats,
        );
        amountThresholdInput = btcAmount.toString();
      } else {
        amountThresholdInput = autoSwapSettings.balanceThresholdSats.toString();
      }

      emit(
        state.copyWith(
          loading: false,
          settings: autoSwapSettings,
          amountThresholdInput: amountThresholdInput,
          feeThresholdInput: autoSwapSettings.feeThresholdPercent.toString(),
          enabledToggle: autoSwapSettings.enabled,
          alwaysBlock: autoSwapSettings.alwaysBlock,
          bitcoinUnit: settings.bitcoinUnit,
        ),
      );
    } catch (e) {
      log.severe('Error loading auto swap settings: $e');
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to load auto swap settings',
        ),
      );
    }
  }

  Future<void> updateSettings() async {
    try {
      emit(state.copyWith(saving: true, error: null, successfullySaved: false));
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;

      // Convert amount based on unit
      int balanceThresholdSats;
      if (settings.bitcoinUnit == BitcoinUnit.btc) {
        // Convert BTC to sats for storage
        final btcAmount =
            double.tryParse(state.amountThresholdInput ?? '0') ?? 0;
        balanceThresholdSats = ConvertAmount.btcToSats(btcAmount);
      } else {
        balanceThresholdSats =
            int.tryParse(state.amountThresholdInput ?? '0') ?? 0;
      }

      // Validate minimum amount threshold
      if (balanceThresholdSats < _minimumAmountThresholdSats) {
        final exception = MinimumAmountThresholdException(
          _minimumAmountThresholdSats,
          settings.bitcoinUnit,
        );
        emit(state.copyWith(saving: false, amountThresholdError: exception));
        return;
      }

      // Validate fee threshold
      final feeThreshold = int.tryParse(state.feeThresholdInput ?? '3') ?? 3;
      if (feeThreshold > _maximumFeeThreshold) {
        final exception = MaximumFeeThresholdException(_maximumFeeThreshold);
        emit(state.copyWith(saving: false, feeThresholdError: exception));
        return;
      }

      await _saveAutoSwapSettingsUsecase.execute(
        AutoSwap(
          enabled: state.enabledToggle,
          balanceThresholdSats: balanceThresholdSats,
          feeThresholdPercent: feeThreshold,
          alwaysBlock: state.alwaysBlock,
        ),
        isTestnet: isTestnet,
      );
      emit(
        state.copyWith(
          saving: false,
          settings: state.settings,
          successfullySaved: true,
          amountThresholdError: null,
          feeThresholdError: null,
        ),
      );
    } catch (e) {
      log.severe('Error updating auto swap settings: $e');
      emit(
        state.copyWith(
          saving: false,
          error: 'Failed to update auto swap settings',
          successfullySaved: false,
        ),
      );
    }
  }

  void onAmountThresholdChanged(String value) {
    // Remove decimal points if unit is sats
    final sanitizedValue =
        state.bitcoinUnit == BitcoinUnit.sats
            ? value.replaceAll(RegExp(r'[^\d]'), '')
            : value;

    emit(
      state.copyWith(
        amountThresholdInput: sanitizedValue,
        amountThresholdError: null,
      ),
    );
  }

  void onFeeThresholdChanged(String value) {
    // Remove any decimal points from fee input
    final sanitizedValue = value.replaceAll(RegExp(r'[^\d]'), '');
    emit(
      state.copyWith(
        feeThresholdInput: sanitizedValue,
        feeThresholdError: null,
      ),
    );
  }

  void onEnabledToggleChanged(bool value) {
    emit(state.copyWith(enabledToggle: value));
  }

  void onInfoToggleChanged() {
    emit(state.copyWith(showInfo: !state.showInfo));
  }

  void onAlwaysBlockToggleChanged(bool value) {
    emit(state.copyWith(alwaysBlock: value));
  }
}
