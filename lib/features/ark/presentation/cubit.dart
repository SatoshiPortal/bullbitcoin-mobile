import 'dart:async';

import 'package:bb_mobile/core/ark/entities/ark_wallet.dart';
import 'package:bb_mobile/core/ark/errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkCubit extends Cubit<ArkState> {
  final ArkWalletEntity wallet;
  final ConvertSatsToCurrencyAmountUsecase convertSatsToCurrencyAmountUsecase;
  final GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase;
  final WalletBloc walletBloc;

  ArkCubit({
    required this.wallet,
    required this.convertSatsToCurrencyAmountUsecase,
    required this.getAvailableCurrenciesUsecase,
    required this.walletBloc,
  }) : super(const ArkState());

  Future<void> refresh() async {
    await loadBalance();
    await loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      emit(state.copyWith(isLoading: true));
      final arkTransactions = await wallet.transactions;
      emit(state.copyWith(transactions: arkTransactions));
    } catch (e) {
      log.warning(e.toString());
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> loadBalance() async {
    try {
      emit(state.copyWith(isLoading: true));
      final balance = await wallet.balance;

      walletBloc.add(RefreshArkWalletBalance(amount: balance.total));

      emit(
        state.copyWith(
          confirmedBalance: balance.confirmed,
          pendingBalance: balance.pending,
        ),
      );
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
      unawaited(refresh());
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
      log.warning(e.toString());
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> loadExchangeRate() async {
    try {
      emit(state.copyWith(isLoading: true));
      final exchangeRate = await convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: state.currencyCode,
      );
      emit(state.copyWith(exchangeRate: exchangeRate));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> loadCurrencies() async {
    try {
      emit(state.copyWith(isLoading: true));
      final fiatCurrencyCodes = await getAvailableCurrenciesUsecase.execute();
      emit(state.copyWith(fiatCurrencyCodes: fiatCurrencyCodes));
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void onSendCurrencyCodeChanged(String code) {
    emit(state.copyWith(currencyCode: code));
    unawaited(loadExchangeRate());
  }

  Future<void> updateSendAddress(String value) async {
    final trimmedValue = value.trim();
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
    }
  }

  Future<void> onSendConfirmed(int amount) async {
    if (!await state.hasValidAddress) throw ArkError('Invalid address');
    if (amount > state.confirmedBalance) throw ArkError('Insufficient balance');

    String txid = '';
    try {
      emit(state.copyWith(isLoading: true));
      final address = state.sendAddress.address;

      switch (state.sendAddress.type) {
        case AddressType.ark:
          txid = await wallet.sendOffchain(amount: amount, address: address);
        case AddressType.btc:
          txid = await wallet.collaborativeRedeem(
            amount: amount,
            address: address,
            selectRecoverableVtxos: state.withRecoverableVtxos,
          );
        default:
          throw ArkError('Invalid address type');
      }
    } catch (e) {
      emit(state.copyWith(error: ArkError(e.toString())));
    } finally {
      emit(state.copyWith(isLoading: false, txid: txid));
      unawaited(refresh());
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  void onChangedSelectRecoverableVtxos(bool value) {
    emit(state.copyWith(withRecoverableVtxos: !state.withRecoverableVtxos));
  }
}
