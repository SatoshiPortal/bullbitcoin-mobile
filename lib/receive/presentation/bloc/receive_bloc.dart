import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/receive/domain/usecases/get_receive_address_use_case.dart';
import 'package:flutter/material.dart';
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
    required GetBitcoinUnitUsecase getBitcoinUnitUseCase,
    required ConvertSatsToCurrencyAmountUsecase
        convertSatsToCurrencyAmountUsecase,
    required ConvertCurrencyToSatsAmountUsecase
        convertCurrencyToSatsAmountUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required CreateReceiveSwapUsecase createReceiveSwapUsecase,
    required ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase,
    Wallet? wallet,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _getCurrencyUsecase = getCurrencyUsecase,
        _getBitcoinUnitUseCase = getBitcoinUnitUseCase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        _convertCurrencyToSatsAmountUsecase =
            convertCurrencyToSatsAmountUsecase,
        _getReceiveAddressUsecase = getReceiveAddressUsecase,
        _createReceiveSwapUsecase = createReceiveSwapUsecase,
        _receiveWithPayjoinUsecase = receiveWithPayjoinUsecase,
        _wallet = wallet,
        // Lightning is the default when pressing the receive button on the home screen
        super(const ReceiveState.networkUndefined()) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final GetBitcoinUnitUsecase _getBitcoinUnitUseCase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final ConvertCurrencyToSatsAmountUsecase _convertCurrencyToSatsAmountUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final ReceiveWithPayjoinUsecase _receiveWithPayjoinUsecase;
  final CreateReceiveSwapUsecase _createReceiveSwapUsecase;
  final Wallet? _wallet;

  Future<void> _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      // If no wallet is passed through the constructor, get the default bitcoin wallet
      Wallet? wallet = _wallet;
      if (wallet == null) {
        final wallets = await _getWalletsUsecase.execute(
          onlyBitcoin: true,
          onlyDefaults: true,
        );

        wallet = wallets.first;
      }

      final address =
          await _getReceiveAddressUsecase.execute(walletId: wallet.id);

      String? payjoinQueryParameter;
      try {
        final payjoin = await _receiveWithPayjoinUsecase.execute(
          walletId: wallet.id,
          address: address.address,
        );
        payjoinQueryParameter = Uri.parse(payjoin.pjUri).queryParameters['pj'];
      } catch (e) {
        debugPrint('Payjoin not available');
      }

      final bitcoinUnit = await _getBitcoinUnitUseCase.execute();
      final fiatCurrency = await _getCurrencyUsecase.execute();
      // TODO: analyse if getting the exchange rate should be done on every amount change
      //  or if it is ok to do it only once at start and use that rate for the whole receive flow
      final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: fiatCurrency,
      );
      final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();

      emit(
        ReceiveState.bitcoin(
          wallet: wallet,
          fiatCurrencyCodes: fiatCurrencies,
          fiatCurrencyCode: fiatCurrency,
          exchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          amountInputCurrencyCode: bitcoinUnit.code,
          address: address.address,
          payjoinQueryParameter: payjoinQueryParameter,
        ),
      );
    } catch (e) {
      emit(
        ReceiveState.error(error: e),
      );
    }
  }

  Future<void> _onLightningStarted(
    ReceiveLightningStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    // If no wallet is passed through the constructor, get the default liquid wallet,
    //  which is the default wallet to receive lightning payments since fees are lower
    //  than on the bitcoin network.
    Wallet? wallet = _wallet;
    if (wallet == null) {
      final wallets = await _getWalletsUsecase.execute(
        onlyLiquid: true,
        onlyDefaults: true,
      );

      wallet = wallets.first;
    }

    final bitcoinUnit = await _getBitcoinUnitUseCase.execute();
    final fiatCurrency = await _getCurrencyUsecase.execute();
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: fiatCurrency,
    );
    final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();

    emit(
      ReceiveState.lightning(
        wallet: wallet,
        fiatCurrencyCodes: fiatCurrencies,
        fiatCurrencyCode: fiatCurrency,
        exchangeRate: exchangeRate,
        bitcoinUnit: bitcoinUnit,
        // Start entering the amount in bitcoin
        amountInputCurrencyCode: bitcoinUnit.code,
      ),
    );
  }

  Future<void> _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    // If no wallet is passed through the constructor, get the default bitcoin wallet
    Wallet? wallet = _wallet;
    if (wallet == null) {
      final wallets = await _getWalletsUsecase.execute(
        onlyBitcoin: true,
        onlyDefaults: true,
      );

      wallet = wallets.first;
    }

    final address =
        await _getReceiveAddressUsecase.execute(walletId: wallet.id);

    final bitcoinUnit = await _getBitcoinUnitUseCase.execute();
    final fiatCurrency = await _getCurrencyUsecase.execute();
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: fiatCurrency,
    );
    final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();

    emit(
      ReceiveState.liquid(
        wallet: wallet,
        fiatCurrencyCodes: fiatCurrencies,
        fiatCurrencyCode: fiatCurrency,
        exchangeRate: exchangeRate,
        bitcoinUnit: bitcoinUnit,
        // Start entering the amount in bitcoin
        amountInputCurrencyCode: bitcoinUnit.code,
        address: address.address,
      ),
    );
  }
}
