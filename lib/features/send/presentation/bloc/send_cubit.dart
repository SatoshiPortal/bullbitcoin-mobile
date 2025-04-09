import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/utxo/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/confirm_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/confirm_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendCubit extends Cubit<SendState> {
  SendCubit({
    required SelectBestWalletUsecase bestWalletUsecase,
    required DetectBitcoinStringUsecase detectBitcoinStringUsecase,
    required GetCurrencyUsecase getCurrencyUsecase,
    required GetBitcoinUnitUsecase getBitcoinUnitUseCase,
    required ConvertSatsToCurrencyAmountUsecase
        convertSatsToCurrencyAmountUsecase,
    required GetNetworkFeesUsecase getNetworkFeesUsecase,
    required GetUtxosUsecase getUtxosUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required PrepareBitcoinSendUsecase prepareBitcoinSendUsecase,
    // ignore: avoid_unused_constructor_parameters
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required ConfirmBitcoinSendUsecase confirmBitcoinSendUsecase,
    required ConfirmLiquidSendUsecase confirmLiquidSendUsecase,
  })  : _getCurrencyUsecase = getCurrencyUsecase,
        _getBitcoinUnitUseCase = getBitcoinUnitUseCase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _bestWalletUsecase = bestWalletUsecase,
        _detectBitcoinStringUsecase = detectBitcoinStringUsecase,
        _getNetworkFeesUsecase = getNetworkFeesUsecase,
        _getUtxosUsecase = getUtxosUsecase,
        _prepareBitcoinSendUsecase = prepareBitcoinSendUsecase,
        _confirmBitcoinSendUsecase = confirmBitcoinSendUsecase,
        _confirmLiquidSendUsecase = confirmLiquidSendUsecase,
        super(const SendState());

  // ignore: unused_field
  final SelectBestWalletUsecase _bestWalletUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final GetBitcoinUnitUsecase _getBitcoinUnitUseCase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetUtxosUsecase _getUtxosUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;

  // ignore: unused_field
  final ConfirmBitcoinSendUsecase _confirmBitcoinSendUsecase;
  final ConfirmLiquidSendUsecase _confirmLiquidSendUsecase;

  void backClicked() {
    if (state.step == SendStep.address) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.amount) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.confirm) {
      emit(state.copyWith(step: SendStep.amount));
    }
  }

  Future<void> addressChanged(String address) async {
    try {
      emit(state.copyWith(addressOrInvoice: address));
      final paymentRequest =
          await _detectBitcoinStringUsecase.execute(data: address);
      emit(
        state.copyWith(
          sendType: SendType.from(paymentRequest),
        ),
      );

      loadUtxos();
      loadFees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void continueOnAddressConfirmed() {
    emit(
      state.copyWith(
        step: SendStep.amount,
      ),
    );
  }
  // TODO: remove if not used
  // Future<void> amountCurrencyChanged(String currencyCode) async {
  //   try {
  //     double exchangeRate = state.exchangeRate;
  //     String fiatCurrencyCode = state.fiatCurrencyCode;

  //     if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
  //         .contains(currencyCode)) {
  //       fiatCurrencyCode = currencyCode;
  //     } else {
  //       final currencyValues = await Future.wait([
  //         _getCurrencyUsecase.execute(),
  //         _convertSatsToCurrencyAmountUsecase.execute(),
  //       ]);

  //       fiatCurrencyCode = currencyValues[0] as String;
  //       exchangeRate = currencyValues[1] as double;
  //     }

  //     emit(
  //       state.copyWith(
  //         fiatCurrencyCode: fiatCurrencyCode,
  //         exchangeRate: exchangeRate,
  //       ),
  //     );
  //   } catch (e) {
  //     emit(state.copyWith(error: e.toString()));
  //   }
  // }

  Future<void> getCurrencies() async {
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
        inputAmountCurrencyCode: bitcoinUnit.code,
      ),
    );
  }

  void amountChanged(String amount) {
    try {
      String validatedAmount;

      if (amount.isEmpty) {
        validatedAmount = amount;
      } else if (state.bitcoinUnit == BitcoinUnit.btc) {
        final amountBtc = double.tryParse(amount);
        final decimals =
            amount.contains('.') ? amount.split('.').last.length : 0;
        final isDecimalPoint = amount == '.';

        validatedAmount = (amountBtc == null && !isDecimalPoint) ||
                decimals > BitcoinUnit.btc.decimals
            ? state.amount
            : amount;
      } else if (state.bitcoinUnit == BitcoinUnit.sats) {
        final satoshis = BigInt.tryParse(amount);
        final hasDecimals = amount.contains('.');

        if (satoshis != null && !hasDecimals) {
          validatedAmount = satoshis.toString();
        } else {
          validatedAmount = state.amount;
        }
      } else {
        final amountFiat = double.tryParse(amount);
        final isDecimalPoint = amount == '.';

        validatedAmount =
            amountFiat == null && !isDecimalPoint ? state.amount : amount;
      }

      emit(state.copyWith(amount: validatedAmount));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onAmountConfirmed() async {
    final paymentRequest =
        await _detectBitcoinStringUsecase.execute(data: state.addressOrInvoice);
    final wallet = await _bestWalletUsecase.execute(
      request: paymentRequest,
      amountSat: state.inputAmountSat,
    );
    emit(
      state.copyWith(
        wallet: wallet,
        step: SendStep.confirm,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );
    await loadFees();
  }

  void onMaxPressed() {
    if (state.wallet == null) return;

    String maxAmount = '';

    if (state.selectedUtxos.isNotEmpty) {
      // Todo: utxo.value should be non-null again when the frozen utxo stuff is fixed
      // then we can remove the fallback to BigInt.zero on utxo.value
      final totalSats = state.selectedUtxos.fold<BigInt>(
        BigInt.zero,
        (sum, utxo) => sum + (utxo.value ?? BigInt.zero),
      );
      maxAmount = totalSats.toString();
    } else {
      maxAmount = state.wallet!.balanceSat.toString();
    }

    emit(state.copyWith(amount: maxAmount));
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  Future<void> loadUtxos() async {
    if (state.wallet == null) return;

    try {
      final utxos = await _getUtxosUsecase.execute(
        walletId: state.wallet!.id,
      );
      emit(state.copyWith(utxos: utxos));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void utxoSelected(Utxo utxo) {
    final selectedUtxos = List.of(state.selectedUtxos);
    if (selectedUtxos.contains(utxo)) {
      selectedUtxos.remove(utxo);
    } else {
      selectedUtxos.add(utxo);
    }
    emit(state.copyWith(selectedUtxos: selectedUtxos));
  }

  void replaceByFeeChanged(bool replaceByFee) {
    emit(state.copyWith(replaceByFee: replaceByFee));
  }

  Future<void> loadFees() async {
    if (state.wallet == null) return;
    try {
      final fees = await _getNetworkFeesUsecase.execute(
        network: state.wallet!.network,
      );
      emit(
        state.copyWith(
          feesList: fees,
          customFee: null,
          selectedFee: fees.fastest,
          selectedFeeOption: FeeSelection.fastest,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void feeSelected(NetworkFee fee) {
    emit(state.copyWith(selectedFee: fee, customFee: null));
  }

  void customFeesChanged(int feeRate) {
    emit(state.copyWith(customFee: feeRate, selectedFee: null));
  }

  Future<void> createTransaction() async {
    try {
      final psbt = await _prepareBitcoinSendUsecase.execute(
        walletId: state.wallet!.id,
        address: state.addressOrInvoice,
        networkFee: state.selectedFee!,
        amountSat: state.confirmedAmountSat!.toInt(),
        drain: state.sendMax,
      );
      emit(
        state.copyWith(
          unsignedPsbt: psbt,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> confirmTransaction() async {
    try {
      final txId = await _confirmLiquidSendUsecase.execute(
        psbt: state.unsignedPsbt!,
        walletId: state.wallet!.id,
        isTestnet: state.wallet!.network.isTestnet,
      );
      emit(
        state.copyWith(
          txId: txId,
          step: SendStep.sent,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    emit(
      state.copyWith(
        step: SendStep.sending,
      ),
    );
    await createTransaction();
    await confirmTransaction();
  }

  Future<void> currencyCodeChanged(String currencyCode) async {
    await getExchangeRate(currencyCode: currencyCode);
    emit(state.copyWith(fiatCurrencyCode: currencyCode));
    await updateFiatApproximatedAmount();
  }

  Future<void> getExchangeRate({String? currencyCode}) async {
    final exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
      currencyCode: currencyCode ?? state.fiatCurrencyCode,
    );

    emit(state.copyWith(exchangeRate: exchangeRate));
  }

  double approximateBtcFromSats(BigInt sats) {
    return BigInt.parse(state.amount) / BigInt.parse('100000000');
  }

  Future<void> updateFiatApproximatedAmount() async {
    double btcAmount;
    switch (state.bitcoinUnit) {
      case BitcoinUnit.btc:
        btcAmount = double.parse(state.amount);
      case BitcoinUnit.sats:
        btcAmount = approximateBtcFromSats(BigInt.parse(state.amount));
    }

    final approximatedValue = btcAmount * state.exchangeRate;
    emit(state.copyWith(fiatApproximatedAmount: approximatedValue.toString()));
  }

  void approximateBalance() {
    if (state.wallet == null) return;

    final satsBalance = state.wallet!.balanceSat;
    final btcBalance = approximateBtcFromSats(satsBalance);
    final approximatedBalance = (btcBalance * state.exchangeRate).toString();
    emit(state.copyWith(balanceApproximatedAmount: approximatedBalance));
  }

  void onNumberPressed(String n) {
    amountChanged(state.amount + n);
    updateFiatApproximatedAmount();
  }

  void onBackspacePressed() {
    if (state.amount.isEmpty) return;

    final newAmount = state.amount.substring(0, state.amount.length - 1);
    emit(state.copyWith(amount: newAmount));

    updateFiatApproximatedAmount();
  }
}
