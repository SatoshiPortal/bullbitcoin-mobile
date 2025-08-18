import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_wallet_address_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_new_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_bloc.freezed.dart';
part 'receive_event.dart';
part 'receive_state.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc({
    required GetWalletsUsecase getWalletsUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
    convertSatsToCurrencyAmountUsecase,
    required GetNewReceiveAddressUsecase getNewReceiveAddressUsecase,
    required CreateReceiveSwapUsecase createReceiveSwapUsecase,
    required ReceiveWithPayjoinUsecase receiveWithPayjoinUsecase,
    required BroadcastOriginalTransactionUsecase
    broadcastOriginalTransactionUsecase,
    required WatchPayjoinUsecase watchPayjoinUsecase,
    required WatchWalletTransactionByAddressUsecase
    watchWalletTransactionByAddressUsecase,
    required WatchSwapUsecase watchSwapUsecase,
    required LabelWalletAddressUsecase labelWalletAddressUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
    Wallet? wallet,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _convertSatsToCurrencyAmountUsecase = convertSatsToCurrencyAmountUsecase,
       _getNewReceiveAddressUsecase = getNewReceiveAddressUsecase,
       _createReceiveSwapUsecase = createReceiveSwapUsecase,
       _receiveWithPayjoinUsecase = receiveWithPayjoinUsecase,
       _broadcastOriginalTransactionUsecase =
           broadcastOriginalTransactionUsecase,
       _watchPayjoinUsecase = watchPayjoinUsecase,
       _watchWalletTransactionByAddressUsecase =
           watchWalletTransactionByAddressUsecase,
       _watchSwapUsecase = watchSwapUsecase,
       _labelWalletAddressUsecase = labelWalletAddressUsecase,
       _getSwapLimitsUsecase = getSwapLimitsUsecase,
       _wallet = wallet,
       super(const ReceiveState()) {
    on<ReceiveBitcoinStarted>(_onBitcoinStarted);
    on<ReceiveLightningStarted>(_onLightningStarted);
    on<ReceiveLiquidStarted>(_onLiquidStarted);
    on<ReceiveAmountInputChanged>(_onAmountInputChanged);
    on<ReceiveAmountConfirmed>(_onAmountConfirmed);
    on<ReceiveAmountCurrencyChanged>(_onAmountCurrencyChanged);
    on<ReceiveNoteChanged>(_onNoteChanged);
    on<ReceiveNoteSaved>(_onNoteSaved);
    on<ReceiveAddressOnlyToggled>(_onAddressOnlyToggled);
    on<ReceiveNewAddressGenerated>(_onNewAddressGenerated);
    on<ReceivePayjoinUpdated>(_onPayjoinUpdated);
    on<ReceivePayjoinOriginalTxBroadcasted>(_onPayjoinOriginalTxBroadcasted);
    on<ReceiveTransactionReceived>(_onReceiveTransactionReceived);
    on<ReceiveLightningSwapUpdated>(_onLightningSwapUpdated);
  }

  final GetWalletsUsecase _getWalletsUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNewReceiveAddressUsecase _getNewReceiveAddressUsecase;
  final ReceiveWithPayjoinUsecase _receiveWithPayjoinUsecase;
  final BroadcastOriginalTransactionUsecase
  _broadcastOriginalTransactionUsecase;
  final CreateReceiveSwapUsecase _createReceiveSwapUsecase;
  final WatchPayjoinUsecase _watchPayjoinUsecase;
  final WatchWalletTransactionByAddressUsecase
  _watchWalletTransactionByAddressUsecase;
  final WatchSwapUsecase _watchSwapUsecase;
  final LabelWalletAddressUsecase _labelWalletAddressUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;
  final Wallet? _wallet;
  StreamSubscription<Payjoin>? _payjoinSubscription;
  StreamSubscription<WalletTransaction>? _walletTransactionSubscription;
  StreamSubscription<Swap>? _swapSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      _payjoinSubscription?.cancel() ?? Future.value(),
      _walletTransactionSubscription?.cancel() ?? Future.value(),
      _swapSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  Future<void> _onBitcoinStarted(
    ReceiveBitcoinStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      // Emit a state with the Bitcoin type so the UI can update allready before
      // the async data is loaded. Remove values that should
      // not be shared between the different receive types. Currently only the
      // amount and note shouldn't be shared.
      emit(
        state.copyWith(
          type: ReceiveType.bitcoin,
          inputAmount: '',
          confirmedAmountSat: null,
          note: '',
          amountException: null,
          error: null,
        ),
      );

      // If no wallet is passed through the constructor, get the default bitcoin wallet
      Wallet? wallet = _wallet;
      if (wallet == null) {
        final wallets = await _getWalletsUsecase.execute(
          onlyBitcoin: true,
          onlyDefaults: true,
        );
        wallet = wallets.first;
      }
      emit(state.copyWith(wallet: wallet));

      if (state.bitcoinUnit == null) {
        // If the bitcoin unit is not set yet, we need to get it from the settings
        // And set the input amount currency code to the bitcoin unit code
        // if no other currency code was selected yet.
        final settings = await _getSettingsUsecase.execute();
        final bitcoinUnit = settings.bitcoinUnit;
        emit(
          state.copyWith(
            bitcoinUnit: bitcoinUnit,
            inputAmountCurrencyCode:
                state.inputAmountCurrencyCode.isNotEmpty
                    ? state.inputAmountCurrencyCode
                    : bitcoinUnit.code,
          ),
        );
      }

      if (state.fiatCurrencyCode.isEmpty) {
        // If the fiat currency code is not set yet, we need to get it from the settings
        final settings = await _getSettingsUsecase.execute();
        final fiatCurrency = settings.currencyCode;
        emit(state.copyWith(fiatCurrencyCode: fiatCurrency));
      }

      if (state.fiatCurrencyCodes.isEmpty) {
        // If the fiat currency codes are not set yet, we need to get them from the settings
        final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();
        emit(state.copyWith(fiatCurrencyCodes: fiatCurrencies));
      }

      var bitcoinAddress = state.bitcoinAddress;
      if (bitcoinAddress == null) {
        // If the bitcoin address is not set yet, we need to get it from the wallet
        final address = await _getNewReceiveAddressUsecase.execute(
          walletId: wallet.id,
        );
        bitcoinAddress = address;
        emit(state.copyWith(bitcoinAddress: bitcoinAddress));
      }

      // If the payjoin receiver is not set yet, we need to create it, but only
      //  if the wallet is not watch only. If the wallet is watch only, we shouldn't
      //  create a payjoin receiver since we can't sign proposals non-interactively.
      if (state.payjoin == null && wallet.signsLocally) {
        PayjoinReceiver? payjoin;
        Object? error;
        try {
          payjoin = await _receiveWithPayjoinUsecase.execute(
            walletId: wallet.id,
            address: bitcoinAddress.address,
          );
          // The payjoin receiver is created, now we can watch it for updates
          _watchPayjoin(payjoin.id);
        } catch (e) {
          log.severe('Payjoin receiver creation failed: $e');
          error = e;
        }

        emit(
          state.copyWith(
            payjoin: payjoin,
            error: error is! ReceivePayjoinException ? error : null,
            receivePayjoinException:
                error is ReceivePayjoinException ? error : null,
          ),
        );
      } else if (state.payjoin != null && !wallet.signsLocally) {
        // If the wallet is watch only, we need to clear the payjoin receiver
        //  since we can't sign proposals non-interactively.
        emit(state.copyWith(payjoin: null));
        // cancel the payjoin subscription as well if it exists
        await _payjoinSubscription?.cancel();
      }

      if (state.exchangeRate == 0) {
        // If the exchange rate is not set yet, we need to get it from the settings
        final exchangeRate =
            await _convertSatsToCurrencyAmountUsecase.execute();
        emit(state.copyWith(exchangeRate: exchangeRate));
      }

      // Start watching for transactions on the wallet address
      _watchWalletTransactionToAddress(
        walletId: wallet.id,
        address: bitcoinAddress.address,
      );
    } catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onLightningStarted(
    ReceiveLightningStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      // Emit a state with the Lightning type so the UI can update allready before
      // the async data is loaded. Remove values that should
      // not be shared between the different receive types. Currently only the
      // amount and note shouldn't be shared. But for Lightning, also clear the
      // swap since it goes to the amount screen first and so a new swap should
      // be created anyways.
      emit(
        state.copyWith(
          type: ReceiveType.lightning,
          lightningSwap: null,
          inputAmount: '',
          confirmedAmountSat: null,
          note: '',
          amountException: null,
        ),
      );

      if (state.bitcoinUnit == null) {
        // If the bitcoin unit is not set yet, we need to get it from the settings
        // And set the input amount currency code to the bitcoin unit code
        // if no other currency code was selected yet.
        final settings = await _getSettingsUsecase.execute();
        final bitcoinUnit = settings.bitcoinUnit;
        emit(
          state.copyWith(
            bitcoinUnit: bitcoinUnit,
            inputAmountCurrencyCode:
                state.inputAmountCurrencyCode.isNotEmpty
                    ? state.inputAmountCurrencyCode
                    : bitcoinUnit.code,
          ),
        );
      }

      if (state.fiatCurrencyCode.isEmpty) {
        // If the fiat currency code is not set yet, we need to get it from the settings
        final settings = await _getSettingsUsecase.execute();
        final fiatCurrency = settings.currencyCode;
        emit(state.copyWith(fiatCurrencyCode: fiatCurrency));
      }

      if (state.fiatCurrencyCodes.isEmpty) {
        // If the fiat currency codes are not set yet, we need to get them from the settings
        final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();
        emit(state.copyWith(fiatCurrencyCodes: fiatCurrencies));
      }

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
      emit(state.copyWith(wallet: wallet));

      if (state.swapLimits == null) {
        // If the swap limits are not set yet, fetch them.
        final (swapLimits, fees) = await _getSwapLimitsUsecase.execute(
          type:
              wallet.isLiquid
                  ? SwapType.lightningToLiquid
                  : SwapType.lightningToBitcoin,
          isTestnet: wallet.network.isTestnet,
        );
        emit(state.copyWith(swapLimits: swapLimits));
      }

      if (state.exchangeRate == 0) {
        // If the exchange rate is not set yet, we need to get it from the settings
        final exchangeRate =
            await _convertSatsToCurrencyAmountUsecase.execute();
        emit(state.copyWith(exchangeRate: exchangeRate));
      }
    } catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onLiquidStarted(
    ReceiveLiquidStarted event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      // Emit a state with the Liquid type so the UI can update with the Liquid
      // receive UI already before the async data is loaded. Remove values that should
      // not be shared between the different receive types. Currently only the
      // amount and note shouldn't be shared.
      emit(
        state.copyWith(
          type: ReceiveType.liquid,
          inputAmount: '',
          confirmedAmountSat: null,
          note: '',
          amountException: null,
          error: null,
        ),
      );

      if (state.bitcoinUnit == null) {
        // If the bitcoin unit is not set yet, we need to get it from the settings
        // And set the input amount currency code to the bitcoin unit code
        // if no other currency code was selected yet.
        final settings = await _getSettingsUsecase.execute();
        final bitcoinUnit = settings.bitcoinUnit;
        emit(
          state.copyWith(
            bitcoinUnit: bitcoinUnit,
            inputAmountCurrencyCode:
                state.inputAmountCurrencyCode.isNotEmpty
                    ? state.inputAmountCurrencyCode
                    : bitcoinUnit.code,
          ),
        );
      }

      if (state.fiatCurrencyCode.isEmpty) {
        // If the fiat currency code is not set yet, we need to get it from the settings
        final settings = await _getSettingsUsecase.execute();
        final fiatCurrency = settings.currencyCode;
        emit(state.copyWith(fiatCurrencyCode: fiatCurrency));
      }

      if (state.fiatCurrencyCodes.isEmpty) {
        // If the fiat currency codes are not set yet, we need to get them from the settings
        final fiatCurrencies = await _getAvailableCurrenciesUsecase.execute();
        emit(state.copyWith(fiatCurrencyCodes: fiatCurrencies));
      }

      // If no wallet is passed through the constructor, get the default liquid wallet
      Wallet? wallet = _wallet;
      if (wallet == null) {
        final wallets = await _getWalletsUsecase.execute(
          onlyLiquid: true,
          onlyDefaults: true,
        );
        wallet = wallets.first;
      }
      emit(state.copyWith(wallet: wallet));

      var liquidAddress = state.liquidAddress;
      if (liquidAddress == null) {
        // If the liquid address is not set yet, we need to get it from the wallet
        final address = await _getNewReceiveAddressUsecase.execute(
          walletId: wallet.id,
        );
        liquidAddress = address;
        emit(state.copyWith(liquidAddress: liquidAddress));
      }

      if (state.exchangeRate == 0) {
        // If the exchange rate is not set yet, we need to get it from the settings
        final exchangeRate =
            await _convertSatsToCurrencyAmountUsecase.execute();
        emit(state.copyWith(exchangeRate: exchangeRate));
      }

      // Start watching for transactions on the wallet address
      _watchWalletTransactionToAddress(
        walletId: wallet.id,
        address: liquidAddress.address,
      );
    } catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onAmountInputChanged(
    ReceiveAmountInputChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      String amount;
      AmountException? amountException;

      if (event.amount.isEmpty) {
        amount = event.amount;
        amountException = null;
      } else if (state.isInputAmountFiat) {
        final amountFiat = double.tryParse(event.amount);
        final isDecimalPoint = event.amount == '.';
        amount =
            amountFiat == null && !isDecimalPoint
                ? state.inputAmount
                : event.amount;
      } else if (state.inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        // If the amount is in sats, make sure it is a valid BigInt and do not
        //  allow a decimal point or for it to be bigger than the max sats amount that can exist.
        final amountSats = BigInt.tryParse(event.amount);
        final hasDecimals = event.amount.contains('.');
        if (amountSats == null || hasDecimals) {
          amount = state.inputAmount; // revert if not integer
        } else {
          amount = amountSats.toString();
        }
      } else {
        // If the amount is in BTC, make sure it is a valid double and
        //  do not allow more than 8 decimal places and that it is not bigger than the max bitcoin amount that can exist.
        final amountBtc = double.tryParse(event.amount);
        final decimals = event.amount.split('.').last.length;
        final isDecimalPoint = event.amount == '.';
        if ((amountBtc == null && !isDecimalPoint) ||
            decimals > BitcoinUnit.btc.decimals) {
          amount = state.inputAmount;
        } else {
          amount = event.amount;
        }
      }

      int inputSat = 0;
      if (amount.isNotEmpty) {
        inputSat =
            state.isInputAmountFiat
                ? ConvertAmount.fiatToSats(
                  double.tryParse(amount) ?? 0,
                  state.exchangeRate,
                )
                : state.inputAmountCurrencyCode == BitcoinUnit.sats.code
                ? int.tryParse(amount) ?? 0
                : ConvertAmount.btcToSats(double.tryParse(amount) ?? 0);
      }
      if (inputSat > ConversionConstants.maxSatsAmount.toInt()) {
        amountException = AmountException.aboveBitcoinProtocolLimit(
          ConversionConstants.maxSatsAmount.toInt(),
        );
        amount = state.inputAmount;
      }

      // if (state.type == ReceiveType.lightning &&
      //     state.swapLimits != null &&
      //     amount.isNotEmpty) {
      //   if (inputSat < state.swapLimits!.min) {
      //     amountException = AmountException.belowSwapLimit(
      //       state.swapLimits!.min,
      //     );
      //   } else if (inputSat > state.swapLimits!.max) {
      //     amountException = AmountException.aboveSwapLimit(
      //       state.swapLimits!.max,
      //     );
      //   }
      // }

      emit(
        state.copyWith(inputAmount: amount, amountException: amountException),
      );
    } catch (e) {
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onAmountCurrencyChanged(
    ReceiveAmountCurrencyChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    double exchangeRate = state.exchangeRate;
    String fiatCurrencyCode = state.fiatCurrencyCode;

    if (![
      BitcoinUnit.btc.code,
      BitcoinUnit.sats.code,
    ].contains(event.currencyCode)) {
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
        _getSettingsUsecase.execute(),
        _convertSatsToCurrencyAmountUsecase.execute(),
      ]);

      fiatCurrencyCode = (currencyValues[0] as SettingsEntity).currencyCode;
      exchangeRate = currencyValues[1] as double;
    }

    emit(
      state.copyWith(
        inputAmountCurrencyCode: event.currencyCode,
        fiatCurrencyCode: fiatCurrencyCode,
        exchangeRate: exchangeRate,
        inputAmount: '',
        amountException: null,
      ),
    );
  }

  Future<void> _onAmountConfirmed(
    ReceiveAmountConfirmed event,
    Emitter<ReceiveState> emit,
  ) async {
    final confirmedAmountSat = state.inputAmountSat;

    if (state.type != ReceiveType.lightning) {
      // No further checks on the amount are needed for normal
      // bitcoin and liquid transactions, they don't have receive limits.
      emit(state.copyWith(confirmedAmountSat: confirmedAmountSat));
      return;
    }
    // For lightning, we need to check if the amount is within the limits
    //  and create a swap if it is.
    emit(state.copyWith(creatingSwap: true));
    if (state.isInputAmountBelowLimit || state.isInputAmountAboveLimit) {
      emit(
        state.copyWith(
          amountException:
              state.isInputAmountBelowLimit
                  ? BelowSwapLimitAmountException(state.swapLimits!.min)
                  : AboveSwapLimitAmountException(state.swapLimits!.max),
          creatingSwap: false,
        ),
      );
      return;
    } else {
      // If the amount is within the limits, we can confirm it and clear the exception.
      // We also clear the swap since we can creaet a new one now.
      emit(
        state.copyWith(
          confirmedAmountSat: confirmedAmountSat,
          amountException: null,
          lightningSwap: null,
        ),
      );
    }

    // Now that we know the amount is valid, we can create the swap
    LnReceiveSwap? swap;
    Object? error;
    try {
      final wallet = state.wallet!;
      swap = await _createReceiveSwapUsecase.execute(
        walletId: wallet.id,
        type:
            wallet.isLiquid
                ? SwapType.lightningToLiquid
                : SwapType.lightningToBitcoin,
        amountSat: confirmedAmountSat,
        description: state.note,
      );
      // The swap is created, now we can watch it for updates
      _watchLnReceiveSwap(swap.id);
      _watchWalletTransactionToAddress(
        walletId: state.wallet!.id,
        address: swap.receiveAddress!,
      );
    } catch (e) {
      log.severe('Swap creation failed: $e');
      error = e;
      emit(state.copyWith(error: error, creatingSwap: false));
    }

    emit(
      state.copyWith(lightningSwap: swap, creatingSwap: false, error: error),
    );
  }

  Future<void> _onNoteChanged(
    ReceiveNoteChanged event,
    Emitter<ReceiveState> emit,
  ) async {
    final validationResult = NoteValidator.validate(event.note);

    if (validationResult.isValid) {
      emit(state.copyWith(note: event.note.trim(), error: null));
    } else {
      emit(state.copyWith(error: validationResult.errorMessage));
    }
  }

  Future<void> _onNoteSaved(
    ReceiveNoteSaved event,
    Emitter<ReceiveState> emit,
  ) async {
    try {
      final note = state.note;
      switch (state.type) {
        case ReceiveType.bitcoin:
          if (state.bitcoinAddress == null) return;
          await _labelWalletAddressUsecase.execute(
            address: state.bitcoinAddress!,
            label: note,
          );
        case ReceiveType.liquid:
          if (state.liquidAddress == null) return;
          await _labelWalletAddressUsecase.execute(
            address: state.liquidAddress!,
            label: note,
          );
        case _:
          break;
      }
    } catch (e) {
      emit(state.copyWith(error: e));
      return;
    }
  }

  Future<void> _onAddressOnlyToggled(
    ReceiveAddressOnlyToggled event,
    Emitter<ReceiveState> emit,
  ) async {
    // This toggle switch button is only available in the bitcoin receive screen
    if (state.type == ReceiveType.bitcoin) {
      emit(state.copyWith(isAddressOnly: event.isAddressOnly));
    }
  }

  Future<void> _onNewAddressGenerated(
    ReceiveNewAddressGenerated event,
    Emitter<ReceiveState> emit,
  ) async {
    emit(
      state.copyWith(bitcoinAddress: null, liquidAddress: null, payjoin: null),
    );

    try {
      if (state.wallet == null) {
        throw Exception('No wallet found');
      }
      final walletId = state.wallet!.id;

      final address = await _getNewReceiveAddressUsecase.execute(
        walletId: walletId,
      );

      switch (state.type) {
        case ReceiveType.bitcoin:
          PayjoinReceiver? payjoin;
          Object? error;
          // If a new address is generated, we need to update the payjoin receiver as well,
          // but only if the wallet is not watch only.
          if (state.wallet!.signsLocally) {
            try {
              payjoin = await _receiveWithPayjoinUsecase.execute(
                walletId: walletId,
                address: address.address,
              );
              // The payjoin receiver is created, now we can watch it for updates
              _watchPayjoin(payjoin.id);
            } catch (e) {
              log.severe('Payjoin receiver creation failed: $e');
              error = e;
            }
          }

          emit(
            state.copyWith(
              bitcoinAddress: address,
              payjoin: payjoin,
              error: error,
            ),
          );

        case ReceiveType.liquid:
          emit(state.copyWith(liquidAddress: address));
        default:
          break;
      }

      // We have to start listening for transactions to this new address now
      _watchWalletTransactionToAddress(
        walletId: walletId,
        address: address.address,
      );
    } catch (e) {
      emit(state.copyWith(error: e));
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
      emit(state.copyWith(payjoin: updatedPayjoin));
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

  Future<void> _onReceiveTransactionReceived(
    ReceiveTransactionReceived event,
    Emitter<ReceiveState> emit,
  ) async {
    final tx = event.tx;

    emit(state.copyWith(tx: tx));
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

      if (updatedSwap.status == SwapStatus.completed) {
        // Sync the wallets now that the swap is completed
        await _getWalletsUsecase.execute(sync: true);
      }
    }
  }

  void _watchPayjoin(String payjoinId) {
    // Cancel the previous subscription if it exists
    _payjoinSubscription?.cancel();
    _payjoinSubscription = _watchPayjoinUsecase.execute(ids: [payjoinId]).listen((
      updatedPayjoin,
    ) {
      log.info(
        '[ReceiveBloc] Watched payjoin ${updatedPayjoin.id} updated: ${updatedPayjoin.status}',
      );
      add(ReceivePayjoinUpdated(updatedPayjoin));
    });
  }

  void _watchWalletTransactionToAddress({
    required String walletId,
    required String address,
  }) {
    // Cancel the previous subscription if it exists
    _walletTransactionSubscription?.cancel();
    _walletTransactionSubscription = _watchWalletTransactionByAddressUsecase
        .execute(walletId: walletId, toAddress: address)
        .listen((tx) {
          log.info(
            '[ReceiveBloc] Watched transaction ${tx.txId} updated: ${tx.status}',
          );
          add(ReceiveTransactionReceived(tx));
        });
  }

  void _watchLnReceiveSwap(String swapId) {
    // Cancel the previous subscription if it exists
    _swapSubscription?.cancel();
    _swapSubscription = _watchSwapUsecase.execute(swapId).listen((updatedSwap) {
      log.info(
        '[ReceiveBloc] Watched swap ${updatedSwap.id} updated: ${updatedSwap.status}',
      );
      if (updatedSwap is LnReceiveSwap) {
        add(ReceiveLightningSwapUpdated(updatedSwap));
      }
    });
  }
}
