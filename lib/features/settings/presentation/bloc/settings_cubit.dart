import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_hide_amounts_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<SettingsState?> {
  SettingsCubit({
    required SetEnvironmentUsecase setEnvironmentUsecase,
    required GetEnvironmentUsecase getEnvironmentUsecase,
    required SetBitcoinUnitUsecase setBitcoinUnitUsecase,
    required GetBitcoinUnitUsecase getBitcoinUnitUsecase,
    required SetLanguageUsecase setLanguageUsecase,
    required GetLanguageUsecase getLanguageUsecase,
    required SetCurrencyUsecase setCurrencyUsecase,
    required GetCurrencyUsecase getCurrencyUsecase,
    required SetHideAmountsUsecase setHideAmountsUsecase,
    required GetHideAmountsUsecase getHideAmountsUsecase,
  })  : _setEnvironmentUsecase = setEnvironmentUsecase,
        _getEnvironmentUsecase = getEnvironmentUsecase,
        _setBitcoinUnitUsecase = setBitcoinUnitUsecase,
        _getBitcoinUnitUsecase = getBitcoinUnitUsecase,
        _setLanguageUsecase = setLanguageUsecase,
        _getLanguageUsecase = getLanguageUsecase,
        _setCurrencyUsecase = setCurrencyUsecase,
        _getCurrencyUsecase = getCurrencyUsecase,
        _setHideAmountsUsecase = setHideAmountsUsecase,
        _getHideAmountsUsecase = getHideAmountsUsecase,
        super(null);

  final SetEnvironmentUsecase _setEnvironmentUsecase;
  final GetEnvironmentUsecase _getEnvironmentUsecase;
  final SetBitcoinUnitUsecase _setBitcoinUnitUsecase;
  final GetBitcoinUnitUsecase _getBitcoinUnitUsecase;
  final SetLanguageUsecase _setLanguageUsecase;
  final GetLanguageUsecase _getLanguageUsecase;
  final SetCurrencyUsecase _setCurrencyUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final SetHideAmountsUsecase _setHideAmountsUsecase;
  final GetHideAmountsUsecase _getHideAmountsUsecase;

  Future<void> init() async {
    final environment = await _getEnvironmentUsecase.execute();
    final bitcoinUnit = await _getBitcoinUnitUsecase.execute();
    final language = await _getLanguageUsecase.execute();
    final currency = await _getCurrencyUsecase.execute();
    final hideAmounts = await _getHideAmountsUsecase.execute();

    emit(
      SettingsState(
        environment: environment,
        bitcoinUnit: bitcoinUnit,
        language: language,
        currencyCode: currency,
        hideAmounts: hideAmounts,
      ),
    );
  }

  Future<void> toggleTestnetMode(bool active) async {
    final environment = active ? Environment.testnet : Environment.mainnet;
    await _setEnvironmentUsecase.execute(environment);
    emit(
      state?.copyWith(environment: environment),
    );
  }

  Future<void> toggleSatsUnit(bool active) async {
    final unit = active ? BitcoinUnit.sats : BitcoinUnit.btc;
    await _setBitcoinUnitUsecase.execute(unit);
    emit(
      state?.copyWith(bitcoinUnit: unit),
    );
  }

  Future<void> changeLanguage(Language language) async {
    await _setLanguageUsecase.execute(language);
    emit(state?.copyWith(language: language));
  }

  Future<void> changeCurrency(String currencyCode) async {
    await _setCurrencyUsecase.execute(currencyCode);
    emit(state?.copyWith(currencyCode: currencyCode));
  }

  Future<void> toggleHideAmounts(bool hide) async {
    await _setHideAmountsUsecase.execute(hide);
    emit(state?.copyWith(hideAmounts: hide));
  }
}
