import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/swap_provider_mode.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_provider_availability_cubit.freezed.dart';
part 'swap_provider_availability_state.dart';

/// Checks once at wallet-home load whether the Exchange swap API is available.
///
/// Skipped entirely when a Boltz server URL is configured — the user already
/// switched to Boltz. When the Exchange answers HTTP 418 the cubit emits
/// [SwapProviderAvailabilityState.unavailable] so the UI can prompt the user
/// to configure a Boltz server.
class SwapProviderAvailabilityCubit
    extends Cubit<SwapProviderAvailabilityState> {
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SwapFacade _swapFacade;

  SwapProviderAvailabilityCubit({
    required this._getAutoSwapSettingsUsecase,
    required this._getSettingsUsecase,
    required this._swapFacade,
  }) : super(const SwapProviderAvailabilityState());

  Future<void> checkAvailability() async {
    final settings = await _getAutoSwapSettingsUsecase.execute();
    if (isClosed) return;

    // Boltz URL configured → already on Boltz, no check needed.
    if (settings.providerMode == SwapProviderMode.boltz) {
      emit(state.copyWith(mode: SwapProviderMode.boltz));
      return;
    }

    // Autoswap is mainnet-only — don't probe on testnet.
    final appSettings = await _getSettingsUsecase.execute();
    if (isClosed) return;
    if (appSettings.environment != Environment.mainnet) return;

    emit(state.copyWith(mode: SwapProviderMode.exchange, checking: true));

    // Lightweight probe: a minimal quote is the cheapest Exchange call.
    final result = await _swapFacade.getQuote(
      environment: OrderSwapEnvironment.mainnet,
      amountSat: BigInt.from(1000),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.liquid,
      outNetwork: OrderSwapNetwork.bitcoin,
    );
    if (isClosed) return;

    switch (result) {
      case Ok():
        emit(state.copyWith(checking: false));
      case Err(:final failure):
        if (failure is SwapProviderUnavailableFailure) {
          emit(state.copyWith(checking: false, exchangeUnavailable: true));
        } else {
          // Any other error (network, timeout, …) is not a provider switch
          // signal — stay on Exchange, don't prompt.
          emit(state.copyWith(checking: false));
        }
    }
  }
}
