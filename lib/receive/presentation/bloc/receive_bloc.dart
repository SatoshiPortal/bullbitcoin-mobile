import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_bloc.freezed.dart';
part 'receive_event.dart';
part 'receive_state.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required GetCurrencyUsecase getCurrencyUsecase,
    required ConvertSatsToCurrencyAmountUsecase
        convertSatsToCurrencyAmountUsecase,
    required ConvertCurrencyToSatsAmountUsecase
        convertCurrencyToSatsAmountUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required CreateReceiveSwapUsecase createReceiveSwapUsecase,
    Wallet? wallet,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _getCurrencyUsecase = getCurrencyUsecase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        _convertCurrencyToSatsAmountUsecase =
            convertCurrencyToSatsAmountUsecase,
        _getReceiveAddressUsecase = getReceiveAddressUsecase,
        _createReceiveSwapUsecase = createReceiveSwapUsecase,
        // Lightning is the default when pressing the receive button on the home screen
        super(ReceiveState.lightning(wallet: wallet)) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final ConvertCurrencyToSatsAmountUsecase _convertCurrencyToSatsAmountUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final CreateReceiveSwapUsecase _createReceiveSwapUsecase;

  void _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the selected wallet id from if none was passed through the constructor (from the event or from the default wallet use case if not present in the event?)
    // TODO: also get the first unused address for the selected wallet
    emit(
      state.copyWith(
        status: ReceiveStatus.inProgress,
      ),
    );
  }

  void _onLightningStarted(
    ReceiveLightningStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    emit(
      const ReceiveState.lightning(
        status: ReceiveStatus.inProgress,
      ),
    );
  }

  void _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) {
    // TODO: get the wallet, fiat currency, exchange rate, and bitcoin unit
    // TODO: check where to get the wallet id from (from the event or from the default wallet use case if not present in the event?)
    // TODO: also get the first unused address for the selected wallet
    emit(
      const ReceiveState.liquid(
        status: ReceiveStatus.inProgress,
      ),
    );
  }
}
