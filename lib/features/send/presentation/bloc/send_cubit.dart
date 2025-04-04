import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
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
    required GetWalletUtxosUsecase getWalletUtxosUsecase,
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
  })  : _getCurrencyUsecase = getCurrencyUsecase,
        _getBitcoinUnitUseCase = getBitcoinUnitUseCase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _bestWalletUsecase = bestWalletUsecase,
        _detectBitcoinStringUsecase = detectBitcoinStringUsecase,
        _getNetworkFeesUsecase = getNetworkFeesUsecase,
        _getWalletUtxosUsecase = getWalletUtxosUsecase,
        super(const SendState());

  final SelectBestWalletUsecase _bestWalletUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final GetBitcoinUnitUsecase _getBitcoinUnitUseCase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

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
      final wallet = await _bestWalletUsecase.execute(request: paymentRequest);
      final network = state.sendTypeFromRequest(paymentRequest);
      emit(
        state.copyWith(
          wallet: wallet,
          sendType: network,
          step: SendStep.amount,
        ),
      );

      loadUtxos();
      loadFees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> amountCurrencyChanged(String currencyCode) async {
    try {
      double exchangeRate = state.exchangeRate;
      String fiatCurrencyCode = state.fiatCurrencyCode;

      if (![BitcoinUnit.btc.code, BitcoinUnit.sats.code]
          .contains(currencyCode)) {
        fiatCurrencyCode = currencyCode;
        exchangeRate = await _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currencyCode,
        );
      } else {
        final currencyValues = await Future.wait([
          _getCurrencyUsecase.execute(),
          _convertSatsToCurrencyAmountUsecase.execute(),
        ]);

        fiatCurrencyCode = currencyValues[0] as String;
        exchangeRate = currencyValues[1] as double;
      }

      emit(
        state.copyWith(
          fiatCurrencyCode: fiatCurrencyCode,
          exchangeRate: exchangeRate,
          amount: '',
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

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
        final amountSats = BigInt.tryParse(amount);
        final hasDecimals = amount.contains('.');

        validatedAmount =
            amountSats == null || hasDecimals ? state.amount : amount;
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

  void maxAmountChanged() {
    if (state.wallet == null) return;

    String maxAmount = '';

    if (state.selectedUtxos.isNotEmpty) {
      final totalSats = state.selectedUtxos.fold<BigInt>(
        BigInt.zero,
        (sum, utxo) => sum + utxo.value,
      );
      maxAmount = totalSats.toString();
    } else {
      maxAmount = state.wallet!.balanceSat.toString();
    }

    emit(state.copyWith(amount: maxAmount));
  }

  void noteChanged(String note) {
    emit(state.copyWith(label: note));
  }

  Future<void> loadUtxos() async {
    if (state.wallet == null) return;

    try {
      final utxos = await _getWalletUtxosUsecase.execute(
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
          selectedFee: fees.economic,
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

  void createTransaction() {}

  void confirmTransaction() {}
}
