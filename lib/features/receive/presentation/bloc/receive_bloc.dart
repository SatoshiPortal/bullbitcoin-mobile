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
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
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
        super(const ReceiveState()) {
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
      // Emit a fresh state with the Bitcoin type
      emit(const ReceiveState(type: ReceiveType.bitcoin));

      // If no wallet is passed through the constructor, get the default bitcoin wallet
      Wallet? wallet = _wallet;
      if (wallet == null) {
        final wallets = await _getWalletsUsecase.execute(
          onlyBitcoin: true,
          onlyDefaults: true,
        );

        wallet = wallets.first;
      }

      final futures = await Future.wait([
        _getBitcoinUnitUseCase.execute(),
        _getCurrencyUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
        _getAvailableCurrenciesUsecase.execute(),
        _getReceiveAddressUsecase.execute(walletId: wallet.id)
      ]);

      final bitcoinUnit = futures[0] as BitcoinUnit;
      final fiatCurrency = futures[1] as String;
      final exchangeRate = futures[2] as double;
      final fiatCurrencies = futures[3] as List<String>;
      final address = futures[4] as Address;

      PayjoinReceiver? payjoin;
      Object? error;
      try {
        payjoin = await _receiveWithPayjoinUsecase.execute(
          walletId: wallet.id,
          address: address.address,
        );
        // The payjoin receiver is created, now we can watch it for updates
        _watchPayjoin(payjoin.id);
      } catch (e) {
        debugPrint('Payjoin receiver creation failed: $e');
        error = e;
      }

      emit(
        state.copyWith(
          wallet: wallet,
          fiatCurrencyCodes: fiatCurrencies,
          fiatCurrencyCode: fiatCurrency,
          exchangeRate: exchangeRate,
          bitcoinUnit: bitcoinUnit,
          // Start entering the amount in bitcoin
          inputAmountCurrencyCode: bitcoinUnit.code,
          bitcoinAddress: address.address,
          payjoin: payjoin,
          error: error,
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
      // Emit a fresh state with the Lightning type
      emit(const ReceiveState());

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
        state.copyWith(
          wallet: wallet,
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
      // Emit a fresh state with the Liquid type
      emit(const ReceiveState(type: ReceiveType.liquid));

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

      // Emit the state with the address already before the async calls
      emit(state.copyWith(liquidAddress: address.address));

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
          wallet: wallet,
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

    if (state.type == ReceiveType.lightning && state.wallet != null) {
      LnReceiveSwap? swap;
      Object? error;
      try {
        swap = await _createReceiveSwapUsecase.execute(
          walletId: state.wallet!.id,
          type: SwapType.lightningToLiquid,
          amountSat: confirmedAmountSat.toInt(),
          description: state.note,
        );
        // The swap is created, now we can watch it for updates
        _watchLnReceiveSwap(swap.id);
      } catch (e) {
        debugPrint('Swap creation failed: $e');
        error = e;
      }

      emit(
        state.copyWith(
          lightningSwap: swap,
          error: error,
        ),
      );
    }
  }

  Future<void> _onNoteChanged(
    ReceiveNoteChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(
      state.copyWith(note: event.note),
    );
  }

  Future<void> _onAddressOnlyToggled(
    ReceiveAddressOnlyToggled event,
    Emitter<ReceiveState> emit,
  ) async {
    // This toggle switch button is only available in the bitcoin receive screen
    if (state.type == ReceiveType.bitcoin) {
      emit(
        state.copyWith(isAddressOnly: event.isAddressOnly),
      );
    }
  }

  Future<void> _onNewAddressGenerated(
    ReceiveNewAddressGenerated event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(state.copyWith(
      bitcoinAddress: '',
      liquidAddress: '',
      payjoin: null,
    ));

    try {
      if (state.wallet == null) {
        throw Exception('No wallet found');
      }

      final address = await _getReceiveAddressUsecase.execute(
        walletId: state.wallet!.id,
        newAddress: true,
      );

      switch (state.type) {
        case ReceiveType.bitcoin:
          // If a new address is generated, we need to update the payjoin receiver as well
          PayjoinReceiver? payjoin;
          Object? error;
          try {
            payjoin = await _receiveWithPayjoinUsecase.execute(
              walletId: state.wallet!.id,
              address: address.address,
            );
            // The payjoin receiver is created, now we can watch it for updates
            _watchPayjoin(payjoin.id);
          } catch (e) {
            debugPrint('Payjoin receiver creation failed: $e');
            error = e;
          }

          emit(state.copyWith(
            bitcoinAddress: address.address,
            payjoin: payjoin,
            error: error,
          ));

        case ReceiveType.liquid:
          emit(state.copyWith(liquidAddress: address.address));
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
    if (state.type == ReceiveType.bitcoin &&
        state.payjoin?.id != null &&
        updatedPayjoin.id == state.payjoin!.id) {
      emit(
        state.copyWith(
          payjoin: updatedPayjoin,
          txId: state.txId.isEmpty ? updatedPayjoin.txId ?? '' : state.txId,
        ),
      );
    }
  }

  Future<void> _onPayjoinOriginalTxBroadcasted(
    ReceivePayjoinOriginalTxBroadcasted event,
    Emitter<ReceiveState> emit,
  ) async {
    final payjoin = state.payjoin;
    if (state.type == ReceiveType.bitcoin &&
        payjoin != null &&
        payjoin.originalTxBytes != null) {
      try {
        await _broadcastOriginalTransactionUsecase.execute(payjoin);
      } catch (e) {
        // TODO: In the ui, show the error if it is a BroadcastOriginalTransactionException
        emit(state.copyWith(error: e));
      }
    }
  }

  Future<void> _onLightningSwapUpdated(
    ReceiveLightningSwapUpdated event,
    Emitter<ReceiveState> emit,
  ) async {
    final updatedSwap = event.swap;
    // Make sure the state is a Lightning state and the correct swap is updated
    if (state.type == ReceiveType.lightning &&
        state.lightningSwap?.id != null &&
        updatedSwap.id == state.lightningSwap!.id) {
      emit(state.copyWith(lightningSwap: updatedSwap));
    }
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
