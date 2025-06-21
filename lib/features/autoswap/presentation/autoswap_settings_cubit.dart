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
          autoSwapSettings.amountThresholdSats,
        );
        amountThresholdInput = btcAmount.toString();
      } else {
        amountThresholdInput = autoSwapSettings.amountThresholdSats.toString();
      }

      emit(
        state.copyWith(
          loading: false,
          settings: autoSwapSettings,
          amountThresholdInput: amountThresholdInput,
          feeThresholdInput: autoSwapSettings.feeThreshold.toString(),
          enabledToggle: autoSwapSettings.enabled,
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
      emit(state.copyWith(loading: true, error: null));
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment == Environment.testnet;

      // Convert amount based on unit
      int amountThresholdSats;
      if (settings.bitcoinUnit == BitcoinUnit.btc) {
        // Convert BTC to sats for storage
        final btcAmount =
            double.tryParse(state.amountThresholdInput ?? '0') ?? 0;
        amountThresholdSats = ConvertAmount.btcToSats(btcAmount);
      } else {
        amountThresholdSats =
            int.tryParse(state.amountThresholdInput ?? '0') ?? 0;
      }

      await _saveAutoSwapSettingsUsecase.execute(
        AutoSwap(
          enabled: state.enabledToggle,
          amountThresholdSats: amountThresholdSats,
          feeThreshold: int.tryParse(state.feeThresholdInput ?? '3') ?? 3,
        ),
        isTestnet: isTestnet,
      );
      emit(state.copyWith(loading: false, settings: state.settings));
    } catch (e) {
      log.severe('Error updating auto swap settings: $e');
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to update auto swap settings',
        ),
      );
    }
  }

  void onAmountThresholdChanged(String value) {
    emit(state.copyWith(amountThresholdInput: value));
  }

  void onFeeThresholdChanged(String value) {
    emit(state.copyWith(feeThresholdInput: value));
  }

  void onEnabledToggleChanged(bool value) {
    emit(state.copyWith(enabledToggle: value));
  }
}
