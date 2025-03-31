import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_use_case.dart';
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
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required CreateReceiveSwapUsecase createReceiveSwapUsecase,
    required ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase,
    required BroadcastOriginalTransactionUsecase
        broadcastOriginalTransactionUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    Wallet? wallet,
  })  : _getWalletsUsecase = getWalletsUsecase,
        _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _getCurrencyUsecase = getCurrencyUsecase,
        _getBitcoinUnitUseCase = getBitcoinUnitUseCase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        _getReceiveAddressUsecase = getReceiveAddressUsecase,
        _createReceiveSwapUsecase = createReceiveSwapUsecase,
        _receiveWithPayjoinUsecase = receiveWithPayjoinUsecase,
        _broadcastOriginalTransactionUsecase =
            broadcastOriginalTransactionUsecase,
        _watchPayjoinUsecase = watchPayjoinUsecase,
        _watchSwapUsecase = watchSwapUsecase,
        _wallet = wallet,
        // Lightning is the default when pressing the receive button on the home screen
        super(const ReceiveState.networkUndefined()) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
    on<ReceiveAmountInputChanged>(_onAmountInputChanged);
    on<ReceiveAmountConfirmed>(_onAmountConfirmed);
    on<ReceiveAmountCurrencyChanged>(_onAmountCurrencyChanged);
    on<ReceiveNoteChanged>(_onNoteChanged);
    on<ReceiveAddressOnlyToggled>(_onAddressOnlyToggled);
    on<ReceiveNewAddressGenerated>(_onNewAddressGenerated);
    on<ReceivePayjoinUpdated>(_onPayjoinUpdated);
    on<ReceivePayjoinOriginalTxBroadcasted>(_onPayjoinOriginalTxBroadcasted);
    on<ReceiveLightningSwapUpdated>(_onLightningSwapUpdated);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final GetBitcoinUnitUsecase _getBitcoinUnitUseCase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final ReceiveWithPayjoinUsecase _receiveWithPayjoinUsecase;
  final BroadcastOriginalTransactionUsecase
      _broadcastOriginalTransactionUsecase;
  final CreateReceiveSwapUsecase _createReceiveSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final Wallet? _wallet;
  StreamSubscription<Payjoin>? _payjoinSubscription;
  StreamSubscription<Swap>? _swapSubscription;

  @override
  Future<void> close() {
    _swapSubscription?.cancel();
    return super.close();
  }

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

      // Emit the bitcoin state with the wallet already for the UI to update
      emit(ReceiveState.bitcoin(wallet: wallet));

      final address =
          await _getReceiveAddressUsecase.execute(walletId: wallet.id);

      // Emit the address so the UI can already show it before the async operations are done
      emit((state as BitcoinReceiveState).copyWith(address: address.address));

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
        (state as BitcoinReceiveState).copyWith(
          fiatCurrencyCodes: fiatCurrencies,
          fiatCurrencyCode: fiatCurrency,
          exchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          inputAmountCurrencyCode: bitcoinUnit.code,
        ),
      );

      try {
        final payjoin = await _receiveWithPayjoinUsecase.execute(
          walletId: wallet.id,
          address: address.address,
        );
        // The payjoin receiver is created, now we can watch it for updates
        _watchPayjoin(payjoin.id);

        emit((state as BitcoinReceiveState).copyWith(payjoin: payjoin));
      } catch (e) {
        debugPrint('Payjoin receiver creation failed: $e');
        emit(state.copyWith(error: e));
      }
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

      // Emit the lightning state with the wallet already so the UI can already
      // update before the async operations are done
      emit(ReceiveState.lightning(wallet: wallet));

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
        state.copyWith(
          fiatCurrencyCodes: fiatCurrencies,
          fiatCurrencyCode: fiatCurrency,
          exchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          inputAmountCurrencyCode: bitcoinUnit.code,
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

      // Emit the liquid state with the wallet already so the UI can already
      // update before the async operations are done
      emit(ReceiveState.liquid(wallet: wallet));

      final address =
          await _getReceiveAddressUsecase.execute(walletId: wallet.id);
      emit(
        (state as LiquidReceiveState).copyWith(
          address: address.address,
        ),
      );
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
        (state as LiquidReceiveState).copyWith(
          fiatCurrencyCodes: fiatCurrencies,
          fiatCurrencyCode: fiatCurrency,
          exchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          inputAmountCurrencyCode: bitcoinUnit.code,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(error: e),
      );
    }
  }

  Future<void> _onAmountInputChanged(
    ReceiveAmountInputChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      String amount;

      if (event.amount.isEmpty) {
        amount = event.amount;
      } else if (state.isInputAmountFiat) {
        final amountFiat = double.tryParse(event.amount);
        final isDecimalPoint = event.amount == '.';

        amount = amountFiat == null && !isDecimalPoint
            ? state.inputAmount
            : event.amount;
      } else if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        // If the amount is in sats, make sure it is a valid BigInt and do not
        //  allow a decimal point.
        final amountSats = BigInt.tryParse(event.amount);
        final hasDecimals = event.amount.contains('.');

        amount = amountSats == null || hasDecimals
            ? state.inputAmount
            : event.amount;
      } else {
        // If the amount is in BTC, make sure it is a valid double and
        //  do not allow more than 8 decimal places.
        final amountBtc = double.tryParse(event.amount);
        final decimals = event.amount.split('.').last.length;
        final isDecimalPoint = event.amount == '.';

        amount = (amountBtc == null && !isDecimalPoint) ||
                decimals > BitcoinUnit.btc.decimals
            ? state.inputAmount
            : event.amount;
      }

      emit(
        state.copyWith(
          inputAmount: amount,
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
    double exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;

    if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
        .contains(event.currencyCode)) {
      // If the currency is a fiat currency, retrieve the exchange rate and replace
      //  the current exchange rate and fiat currency code.
      fiatCurrencyCode = event.currencyCode;
      exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: event.currencyCode,
      );
    } else {
      // If the currency is a bitcoin unit, set the fiat currency and exchange
      //  rate back to the currency from the settings.
      final currencyValues = await Future.wait([
        _getCurrencyUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
      ]);

      fiatCurrencyCode = currencyValues[0] as String;
      exchangeRate = currencyValues[1] as double;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: event.currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
        inputAmount: '', // Clear the amount when changing the currency
      ),
    );
  }

  Future<void> _onAmountConfirmed(
    ReceiveAmountConfirmed event,
    Emitter<ReceiveState> emit,
  ) async {
    final confirmedAmountSat = state.inputAmountSat;
    emit(
      state.copyWith(
        confirmedAmountSat: confirmedAmountSat,
      ),
    );

    if (state is LightningReceiveState) {
      final lightningReceiveState = state as LightningReceiveState;

      // Reset the swap and error before creating a new swap
      emit(
        lightningReceiveState.copyWith(
          swap: null,
          error: null,
          note: state.note,
        ),
      );

      LnReceiveSwap? swap;
      try {
        swap = await _createLnReceiveSwap(
          walletId: lightningReceiveState.wallet.id,
          amountSat: confirmedAmountSat,
          note: lightningReceiveState.note,
        );

        emit(
          lightningReceiveState.copyWith(
            swap: swap,
            error: null,
            // note: lightningReceiveState.note,
          ),
        );
      } catch (e) {
        emit(state.copyWith(error: e));
        return;
      }
    }
  }

  Future<void> _onNoteChanged(
    ReceiveNoteChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    final note = event.note;

    emit(
      state.copyWith(
        note: note,
      ),
    );

    // Create a new swap if the description is still changed after the amount was already confirmed
    if (state is LightningReceiveState && state.confirmedAmountSat != null) {
      final lightningReceiveState = state as LightningReceiveState;

      // Reset the swap and error before creating a new swap
      emit(lightningReceiveState.copyWith(swap: null, error: null));

      LnReceiveSwap? swap;
      try {
        swap = await _createLnReceiveSwap(
          walletId: lightningReceiveState.wallet.id,
          amountSat: lightningReceiveState.confirmedAmountSat!,
          note: note,
        );

        emit(
          lightningReceiveState.copyWith(
            swap: swap,
            error: null,
            note: note,
          ),
        );
      } catch (e) {
        emit(state.copyWith(error: e));
        return;
      }
    }
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

  Future<void> _onPayjoinUpdated(
    ReceivePayjoinUpdated event,
    Emitter<ReceiveState> emit,
  ) async {
    final updatedPayjoin = event.payjoin;
    // Make sure the state is a Bitcoin state and the correct payjoin is updated
    if (state is BitcoinReceiveState) {
      final bitcoinReceiveState = state as BitcoinReceiveState;
      if (bitcoinReceiveState.payjoin?.id != null &&
          updatedPayjoin.id == bitcoinReceiveState.payjoin!.id) {
        emit(
          bitcoinReceiveState.copyWith(
            payjoin: updatedPayjoin,
            txId: bitcoinReceiveState.txId.isEmpty
                ? updatedPayjoin.txId ?? ''
                : bitcoinReceiveState.txId,
          ),
        );
      }
    }
  }

  Future<void> _onPayjoinOriginalTxBroadcasted(
    ReceivePayjoinOriginalTxBroadcasted event,
    Emitter<ReceiveState> emit,
  ) async {
    if (state is BitcoinReceiveState) {
      final bitcoinReceiveState = state as BitcoinReceiveState;
      final payjoin = bitcoinReceiveState.payjoin;
      if (payjoin != null && payjoin.originalTxBytes != null) {
        try {
          await _broadcastOriginalTransactionUsecase.execute(payjoin);
        } catch (e) {
          // TODO: In the ui, show the error if it is a BroadcastOriginalTransactionException
          emit(state.copyWith(error: e));
        }
      }
    }
  }

  Future<void> _onLightningSwapUpdated(
    ReceiveLightningSwapUpdated event,
    Emitter<ReceiveState> emit,
  ) async {
    final updatedSwap = event.swap;
    // Make sure the state is a Lightning state and the correct swap is updated
    if (state is LightningReceiveState) {
      final lightningReceiveState = state as LightningReceiveState;
      if (lightningReceiveState.swap?.id != null &&
          updatedSwap.id == lightningReceiveState.swap!.id) {
        emit(lightningReceiveState.copyWith(swap: updatedSwap));
      }
    }
  }

  Future<LnReceiveSwap> _createLnReceiveSwap({
    required String walletId,
    required BigInt amountSat,
    String? note,
  }) async {
    // TODO: check how to pass a note/description
    final swap = await _createReceiveSwapUsecase.execute(
      walletId: walletId,
      type: SwapType.lightningToLiquid,
      amountSat: amountSat.toInt(),
    );

    _watchLnReceiveSwap(swap.id);

    return swap;
  }

  void _watchPayjoin(String payjoinId) {
    // Cancel the previous subscription if it exists
    _payjoinSubscription?.cancel();
    _payjoinSubscription =
        _watchPayjoinUsecase.execute(ids: [payjoinId]).listen(
      (updatedPayjoin) {
        debugPrint(
          '[ReceiveBloc] Watched payjoin ${updatedPayjoin.id} updated: ${updatedPayjoin.status}',
        );
        if (updatedPayjoin is PayjoinReceiver) {
          add(ReceivePayjoinUpdated(updatedPayjoin));
        }
      },
    );
  }

  void _watchLnReceiveSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      debugPrint(
        '[ReceiveBloc] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is LnReceiveSwap) {
        add(ReceiveLightningSwapUpdated(updatedSwap));
      }
    });
  }
}
