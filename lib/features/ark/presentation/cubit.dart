import 'dart:async';

import 'package:bb_mobile/core_deprecated/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core_deprecated/ark/errors.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkCubit extends Cubit<ArkState> {
  final ArkWalletEntity wallet;
  final ConvertSatsToCurrencyAmountUsecase convertSatsToCurrencyAmountUsecase;
  final GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  final GetSettingsUsecase getSettingsUsecase;

  final WalletBloc walletBloc;

  ArkCubit({
    required this.wallet,
    required this.convertSatsToCurrencyAmountUsecase,
    required this.getAvailableCurrenciesUsecase,
    required this.getSettingsUsecase,
    required this.walletBloc,
  }) : super(const ArkState());

  Future<void> load() async {
    try {
      emit(state.copyWith(isLoading: true));
      final (arkTransactions, balance, fiatCurrencyCodes, settings) =
          await (
            wallet.transactions,
            wallet.balance,
            getAvailableCurrenciesUsecase.execute(),
            getSettingsUsecase.execute(),
          ).wait;
      emit(
        state.copyWith(
          transactions: arkTransactions,
          arkBalance: balance,
          exchangeRate: await convertSatsToCurrencyAmountUsecase.execute(
            currencyCode: settings.currencyCode,
          ),
          preferredBitcoinUnit: settings.bitcoinUnit,
          // Default to bitcoin input
          currencyCode: settings.bitcoinUnit.code,
          preferrredFiatCurrencyCode: settings.currencyCode,
          fiatCurrencyCodes: fiatCurrencyCodes,
        ),
      );
      // TODO: We should not do this, a BLoC/Cubit shouldn't call another
      //  BLoC/Cubit, but for now since it was already done like this, we keep it.
      walletBloc.add(RefreshArkWalletBalance(amount: balance.completeTotal));
    } catch (e) {
      log.warning(e.toString());
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void receiveMethodChanged(bool isOffchain) {
    final receiveMethod =
        isOffchain ? ArkReceiveMethod.offchain : ArkReceiveMethod.boarding;
    emit(state.copyWith(receiveMethod: receiveMethod));
  }

  Future<void> settle(bool selectRecoverableVtxos) async {
    try {
      emit(state.copyWith(isLoading: true));
      await wallet.settle(selectRecoverableVtxos);
      unawaited(load());
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> onSendCurrencyCodeChanged(String code) async {
    try {
      emit(
        state.copyWith(
          isLoading: true,
          error: null,
          amountSat: null,
          exchangeRate: 0,
        ),
      );
      double exchangeRate = 0;
      if (BitcoinUnit.values.map((e) => e.code).contains(code)) {
        exchangeRate = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: state.preferrredFiatCurrencyCode,
        );
      } else {
        exchangeRate = await convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: code,
        );
      }

      emit(state.copyWith(currencyCode: code, exchangeRate: exchangeRate));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> updateAmount({
    required String amount,
    required String currencyCode,
  }) async {
    emit(state.copyWith(amountSat: null, isLoading: true, error: null));
    try {
      int amountSat = 0;
      if (currencyCode == BitcoinUnit.sats.code) {
        amountSat = int.parse(amount);
      } else if (currencyCode == BitcoinUnit.btc.code) {
        amountSat = (double.parse(amount) * 1e8).toInt();
      } else {
        final satsAmountDouble = await convertSatsToCurrencyAmountUsecase
            .execute(currencyCode: currencyCode);
        amountSat = (double.parse(amount) / satsAmountDouble * 1e8).toInt();
      }

      emit(state.copyWith(amountSat: amountSat));
    } catch (e) {
      emit(state.copyWith(error: ArkError('Invalid amount')));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> updateSendAddress(String value) async {
    final trimmedValue = value.trim();
    emit(state.copyWith(sendAddress: null, error: null, isLoading: true));
    try {
      AddressType? type;
      if (await ArkWalletEntity.isBtcAddress(trimmedValue)) {
        type = AddressType.btc;
      } else if (ArkWalletEntity.isArkAddress(trimmedValue)) {
        type = AddressType.ark;
      } else {
        throw ArkError('Invalid address');
      }

      emit(state.copyWith(sendAddress: (address: trimmedValue, type: type)));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> onSendConfirmed() async {
    final amount = state.amountSat!;
    if (!await state.hasValidAddress) throw ArkError('Invalid address');
    if (amount > state.confirmedBalance) throw ArkError('Insufficient balance');

    try {
      emit(state.copyWith(isLoading: true, txid: ''));
      final address = state.sendAddress!.address;
      String txid = '';
      switch (state.sendAddress!.type) {
        case AddressType.ark:
          txid = await wallet.sendOffchain(amount: amount, address: address);
        case AddressType.btc:
          txid = await wallet.collaborativeRedeem(
            amount: amount,
            address: address,
            selectRecoverableVtxos: state.withRecoverableVtxos,
          );
      }
      emit(state.copyWith(txid: txid));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
      unawaited(load());
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  void onChangedSelectRecoverableVtxos(bool value) {
    emit(state.copyWith(withRecoverableVtxos: !state.withRecoverableVtxos));
  }
}
