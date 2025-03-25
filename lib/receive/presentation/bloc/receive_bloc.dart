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
import 'package:intl/intl.dart';

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
    on<ReceiveAmountChanged>(_onAmountChanged);
    on<ReceiveAmountCurrencyChanged>(_onAmountCurrencyChanged);
    on<ReceiveNoteChanged>(_onNoteChanged);
    on<ReceiveAddressOnlyToggled>(_onAddressOnlyToggled);
    on<ReceiveNewAddressGenerated>(_onNewAddressGenerated);
    on<ReceiveLightningSwapCreated>(_onLightningSwapCreated);
    on<ReceivePaymentReceived>(_onPaymentReceived);
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

      String payjoinQueryParameter = '';
      try {
        final payjoin = await _receiveWithPayjoinUsecase.execute(
          walletId: wallet.id,
          address: address.address,
        );
        payjoinQueryParameter =
            Uri.parse(payjoin.pjUri).queryParameters['pj'] ?? '';
      } catch (e) {
        debugPrint('Payjoin not available');
      }

      final currencyValues = await Future.wait([
        _getBitcoinUnitUseCase.execute(),
        _getCurrencyUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
        _getAvailableCurrenciesUsecase.execute(),
      ]);

      final bitcoinUnit = currencyValues[0] as BitcoinUnit;
      final fiatCurrency = currencyValues[1] as String;
      final exchangeRate = currencyValues[2] as double;
      final fiatCurrencies = currencyValues[3] as List<String>;

      emit(
        ReceiveState.bitcoin(
          wallet: wallet,
          fiatCurrencyCodes: fiatCurrencies,
          defaultFiatCurrencyCode: fiatCurrency,
          defaultFiatCurrencyExchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          amountInputCurrencyCode: bitcoinUnit.code,
          amountInputCurrencyExchangeRate: exchangeRate,
          address: address.address,
          payjoinQueryParameter: payjoinQueryParameter,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onLightningStarted(
    ReceiveLightningStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
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

      final currencyValues = await Future.wait([
        _getBitcoinUnitUseCase.execute(),
        _getCurrencyUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
        _getAvailableCurrenciesUsecase.execute(),
      ]);

      final bitcoinUnit = currencyValues[0] as BitcoinUnit;
      final fiatCurrency = currencyValues[1] as String;
      final exchangeRate = currencyValues[2] as double;
      final fiatCurrencies = currencyValues[3] as List<String>;

      emit(
        ReceiveState.lightning(
          wallet: wallet,
          fiatCurrencyCodes: fiatCurrencies,
          defaultFiatCurrencyCode: fiatCurrency,
          defaultFiatCurrencyExchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          amountInputCurrencyCode: bitcoinUnit.code,
          amountInputCurrencyExchangeRate: exchangeRate,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      // If no wallet is passed through the constructor, get the default bitcoin wallet
      Wallet? wallet = _wallet;
      if (wallet == null) {
        final wallets = await _getWalletsUsecase.execute(
          onlyLiquid: true,
          onlyDefaults: true,
        );

        wallet = wallets.first;
      }

      final address =
          await _getReceiveAddressUsecase.execute(walletId: wallet.id);

      final currencyValues = await Future.wait([
        _getBitcoinUnitUseCase.execute(),
        _getCurrencyUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
        _getAvailableCurrenciesUsecase.execute(),
      ]);

      final bitcoinUnit = currencyValues[0] as BitcoinUnit;
      final fiatCurrency = currencyValues[1] as String;
      final exchangeRate = currencyValues[2] as double;
      final fiatCurrencies = currencyValues[3] as List<String>;

      emit(
        ReceiveState.liquid(
          wallet: wallet,
          fiatCurrencyCodes: fiatCurrencies,
          defaultFiatCurrencyCode: fiatCurrency,
          defaultFiatCurrencyExchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          amountInputCurrencyCode: bitcoinUnit.code,
          amountInputCurrencyExchangeRate: exchangeRate,
          address: address.address,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onAmountChanged(
    ReceiveAmountChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      String amount;

      if (event.amount.isEmpty) {
        amount = event.amount;
      } else if (state.isFiatAmountInput) {
        final amountFiat = double.tryParse(event.amount);
        final isDecimalPoint = event.amount == '.';

        amount = amountFiat == null && !isDecimalPoint
            ? state.amountInput
            : event.amount;
      } else if (state.amountInputCurrencyCode == BitcoinUnit.sats.code) {
        // If the amount is in sats, make sure it is a valid BigInt and do not
        //  allow a decimal point.
        final amountSats = BigInt.tryParse(event.amount);
        final hasDecimals = event.amount.contains('.');

        amount = amountSats == null || hasDecimals
            ? state.amountInput
            : event.amount;
      } else {
        // If the amount is in BTC, make sure it is a valid double and
        //  do not allow more than 8 decimal places.
        final amountBtc = double.tryParse(event.amount);
        final decimals = event.amount.split('.').last.length;
        final isDecimalPoint = event.amount == '.';

        amount = (amountBtc == null && !isDecimalPoint) ||
                decimals > BitcoinUnit.btc.decimals
            ? state.amountInput
            : event.amount;
      }

      emit(
        state.copyWith(
          amountInput: amount,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onAmountCurrencyChanged(
    ReceiveAmountCurrencyChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    double exchangeRate = state.amountInputCurrencyExchangeRate;

    if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
        .contains(event.currencyCode)) {
      exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: event.currencyCode,
      );
    }

    emit(
      state.copyWith(
        amountInputCurrencyCode: event.currencyCode,
        amountInputCurrencyExchangeRate: exchangeRate,
        amountInput: '', // Clear the amount when changing the currency
      ),
    );
  }

  Future<void> _onNoteChanged(
    ReceiveNoteChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(
      state.copyWith(
        note: event.note,
      ),
    );
  }

  Future<void> _onAddressOnlyToggled(
    ReceiveAddressOnlyToggled event,
    Emitter<ReceiveState> emit,
  ) async {
    // This toggle switch button is only available in the bitcoin receive screen
    if (state is BitcoinReceiveState) {
      final bitcoinReceiveState = state as BitcoinReceiveState;
      emit(
        bitcoinReceiveState.copyWith(
          isAddressOnly: event.isAddressOnly,
        ),
      );
    }
  }

  Future<void> _onNewAddressGenerated(
    ReceiveNewAddressGenerated event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      switch (state) {
        case final BitcoinReceiveState bitcoinReceiveState:
          final address = await _getReceiveAddressUsecase.execute(
            walletId: bitcoinReceiveState.wallet.id,
            newAddress: true,
          );

          emit(
            bitcoinReceiveState.copyWith(
              address: address.address,
            ),
          );
        case final LiquidReceiveState liquidReceiveState:
          final address = await _getReceiveAddressUsecase.execute(
            walletId: liquidReceiveState.wallet.id,
            newAddress: true,
          );

          emit(
            liquidReceiveState.copyWith(
              address: address.address,
            ),
          );
        default:
          break;
      }
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onLightningSwapCreated(
    ReceiveLightningSwapCreated event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      /*
      final swap = await _createReceiveSwapUsecase.execute(
        walletId: state.wallet.id,
        amount: state.amountInput,
        currencyCode: state.amountInputCurrencyCode,
        note: state.note,
      );

      emit(
        (state as LightningReceiveState).copyWith(
          swap: swap,
        ),
      );*/
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onPaymentReceived(
    ReceivePaymentReceived event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ReceiveStatus.success,
      ),
    );
  }
}
