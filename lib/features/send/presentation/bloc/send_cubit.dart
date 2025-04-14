import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/utxo/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/confirm_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/confirm_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/create_send_swap_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/select_best_wallet_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/update_paid_send_swap_usecase.dart';
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
    required PrepareLiquidSendUsecase prepareLiquidSendUsecase,
    required ConfirmBitcoinSendUsecase confirmBitcoinSendUsecase,
    required ConfirmLiquidSendUsecase confirmLiquidSendUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required CreateSendSwapUsecase createSendSwapUsecase,
    required UpdatePaidSendSwapUsecase updatePaidSendSwapUsecase,
    required GetSwapLimitsUsecase getSwapLimitsUsecase,
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
        _prepareLiquidSendUsecase = prepareLiquidSendUsecase,
        _confirmBitcoinSendUsecase = confirmBitcoinSendUsecase,
        _confirmLiquidSendUsecase = confirmLiquidSendUsecase,
        _getWalletsUsecase = getWalletsUsecase,
        _createSendSwapUsecase = createSendSwapUsecase,
        _updatePaidSendSwapUsecase = updatePaidSendSwapUsecase,
        _getSwapLimitsUsecase = getSwapLimitsUsecase,
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
  final GetWalletsUsecase _getWalletsUsecase;
  final PrepareBitcoinSendUsecase _prepareBitcoinSendUsecase;
  final PrepareLiquidSendUsecase _prepareLiquidSendUsecase;
  final CreateSendSwapUsecase _createSendSwapUsecase;
  final ConfirmBitcoinSendUsecase _confirmBitcoinSendUsecase;
  final ConfirmLiquidSendUsecase _confirmLiquidSendUsecase;
  final UpdatePaidSendSwapUsecase _updatePaidSendSwapUsecase;
  final GetSwapLimitsUsecase _getSwapLimitsUsecase;

  void backClicked() {
    if (state.step == SendStep.address) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.amount) {
      emit(state.copyWith(step: SendStep.address));
    } else if (state.step == SendStep.confirm) {
      emit(state.copyWith(step: SendStep.amount));
    }
  }

  Future<void> loadWalletWithRatesAndFees() async {
    try {
      final wallets = await _getWalletsUsecase.execute();
      emit(state.copyWith(wallets: wallets));
      await getCurrencies();
      await getExchangeRate();
      await loadFees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> addressChanged(String address) async {
    try {
      emit(state.copyWith(addressOrInvoice: address.trim()));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> continueOnAddressConfirmed() async {
    try {
      emit(
        state.copyWith(loadingBestWallet: true),
      );
      final paymentRequest = await _detectBitcoinStringUsecase.execute(
        data: state.addressOrInvoice,
      );

      final wallet = await _bestWalletUsecase.execute(
        wallets: state.wallets,
        request: paymentRequest,
        amountSat: state.inputAmountSat,
      );
      final sendType = SendType.from(paymentRequest);
      emit(
        state.copyWith(
          selectedWallet: wallet,
          sendType: sendType,
        ),
      );
      final loadSwapLimits =
          paymentRequest.isBolt11 || paymentRequest.isLnAddress;

      final swapType = wallet.isLiquid
          ? SwapType.liquidToLightning
          : SwapType.bitcoinToLightning;

      if (loadSwapLimits) {
        final swapLimits = await _getSwapLimitsUsecase.execute(
          isTestnet: wallet.network.isTestnet,
          type: swapType,
        );
        emit(state.copyWith(swapLimits: swapLimits));
      }
      if (paymentRequest.isBolt11) {
        // for bolt12 or lnaddress we need to redirect to the amount page and only create a swap after amount is set
        final swap = await _createSendSwapUsecase.execute(
          walletId: wallet.id,
          type: swapType,
          invoice: state.addressOrInvoice,
        );
        await loadFees();
        await loadUtxos();
        emit(
          state.copyWith(
            step: SendStep.confirm,
            lightningSwap: swap,
            confirmedAmountSat:
                (paymentRequest as Bolt11PaymentRequest).amountSat,
          ),
        );
      } else {
        await loadFees();
        await loadUtxos();
        emit(
          state.copyWith(
            step: SendStep.amount,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          error: e,
        ),
      );
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

      emit(
        state.copyWith(
          amount: validatedAmount,
          sendMax: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onAmountConfirmed() async {
    emit(
      state.copyWith(
        amountConfirmedClicked: true,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );
    if (state.sendType == SendType.lightning) {
      final swapType = state.selectedWallet!.isLiquid
          ? SwapType.liquidToLightning
          : SwapType.bitcoinToLightning;
      final swap = await _createSendSwapUsecase.execute(
        walletId: state.selectedWallet!.id,
        type: swapType,
        lnAddress: state.addressOrInvoice,
        amountSat: state.confirmedAmountSat,
      );
      emit(
        state.copyWith(
          amountConfirmedClicked: true,
          step: SendStep.confirm,
          lightningSwap: swap,
        ),
      );
    }
    emit(
      state.copyWith(
        step: SendStep.confirm,
        confirmedAmountSat: state.inputAmountSat,
      ),
    );
  }

  void onMaxPressed() {
    if (state.selectedWallet == null) return;

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
      maxAmount = state.selectedWallet!.balanceSat.toString();
    }
    if (state.bitcoinUnit == BitcoinUnit.btc) {
      final btcAmount =
          ConvertAmount.satsToBtc(state.selectedWallet!.balanceSat.toInt());
      maxAmount = btcAmount.toString();
    }
    emit(
      state.copyWith(
        amount: maxAmount,
        sendMax: true,
      ),
    );
  }

  void noteChanged(String note) => emit(state.copyWith(label: note));

  Future<void> loadUtxos() async {
    if (state.selectedWallet == null) return;

    try {
      final utxos = await _getUtxosUsecase.execute(
        walletId: state.selectedWallet!.id,
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
    if (state.selectedWallet == null) return;
    try {
      final fees = await _getNetworkFeesUsecase.execute(
        network: state.selectedWallet!.network,
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
      final address = state.lightningSwap != null
          ? state.lightningSwap!.paymentAddress
          : state.addressOrInvoice;
      final amount = state.lightningSwap != null
          ? state.lightningSwap!.paymentAmount
          : state.confirmedAmountSat;
      // Fees can be selectedFee as it defaults to Fastest
      if (state.selectedWallet!.network.isLiquid) {
        final psbt = await _prepareLiquidSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );
        emit(
          state.copyWith(
            unsignedPsbt: psbt,
          ),
        );
      } else {
        final psbt = await _prepareBitcoinSendUsecase.execute(
          walletId: state.selectedWallet!.id,
          address: address,
          networkFee: state.selectedFee!,
          amountSat: amount,
          // ignore: avoid_bool_literals_in_conditional_expressions
          drain: state.lightningSwap != null ? false : state.sendMax,
        );
        emit(
          state.copyWith(
            unsignedPsbt: psbt,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> confirmTransaction() async {
    try {
      String txId;
      if (state.selectedWallet!.network.isLiquid) {
        txId = await _confirmLiquidSendUsecase.execute(
          psbt: state.unsignedPsbt!,
          walletId: state.selectedWallet!.id,
          isTestnet: state.selectedWallet!.network.isTestnet,
        );
      } else {
        txId = await _confirmBitcoinSendUsecase.execute(
          psbt: state.unsignedPsbt!,
          walletId: state.selectedWallet!.id,
        );
      }

      if (state.lightningSwap != null) {
        await _updatePaidSendSwapUsecase.execute(
          txid: txId,
          swapId: state.lightningSwap!.id,
          network: state.selectedWallet!.network,
        );
      }
      emit(
        state.copyWith(
          txId: txId,
          step: SendStep.success,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> onConfirmTransactionClicked() async {
    await createTransaction();
    emit(
      state.copyWith(
        step: SendStep.sending,
      ),
    );
    await confirmTransaction();
  }

  Future<void> currencyCodeChanged(String currencyCode) async {
    if (currencyCode == BitcoinUnit.btc.code ||
        currencyCode == BitcoinUnit.sats.code) {
      emit(
        state.copyWith(
          bitcoinUnit: BitcoinUnit.fromCode(currencyCode),
          inputAmountCurrencyCode: currencyCode,
          fiatCurrencyCode: 'CAD',
          amount: '0',
        ),
      );
      return;
    }
    await getExchangeRate(currencyCode: currencyCode);
    emit(
      state.copyWith(
        fiatCurrencyCode: currencyCode,
        inputAmountCurrencyCode: currencyCode,
        amount: '0',
      ),
    );
    // await updateFiatApproximatedAmount();
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

  // Future<void> updateFiatApproximatedAmount() async {
  //   double btcAmount;
  //   switch (state.bitcoinUnit) {
  //     case BitcoinUnit.btc:
  //       btcAmount = double.parse(state.amount);
  //     case BitcoinUnit.sats:
  //       btcAmount = approximateBtcFromSats(BigInt.parse(state.amount));
  //   }

  //   final approximatedValue = btcAmount * state.exchangeRate;
  //   emit(state.copyWith(fiatApproximatedAmount: approximatedValue.toString()));
  // }

  void onNumberPressed(String n) {
    amountChanged(state.amount + n);
    // updateFiatApproximatedAmount();
  }

  void onBackspacePressed() {
    if (state.amount.isEmpty) return;

    final newAmount = state.amount.substring(0, state.amount.length - 1);
    emit(state.copyWith(amount: newAmount));

    // updateFiatApproximatedAmount();
  }
}
