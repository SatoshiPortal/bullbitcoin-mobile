import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<SettingsEntity?> {
  SettingsCubit({
    required GetSettingsUsecase getSettingsUsecase,
    required SetEnvironmentUsecase setEnvironmentUsecase,
    required SetBitcoinUnitUsecase setBitcoinUnitUsecase,
    required SetLanguageUsecase setLanguageUsecase,
    required SetCurrencyUsecase setCurrencyUsecase,
    required SetHideAmountsUsecase setHideAmountsUsecase,
    required SetIsSuperuserUsecase setIsSuperuserUsecase,
  }) : _setEnvironmentUsecase = setEnvironmentUsecase,
       _setBitcoinUnitUsecase = setBitcoinUnitUsecase,
       _getSettingsUsecase = getSettingsUsecase,
       _setLanguageUsecase = setLanguageUsecase,
       _setCurrencyUsecase = setCurrencyUsecase,
       _setHideAmountsUsecase = setHideAmountsUsecase,
       _setIsSuperuserUsecase = setIsSuperuserUsecase,
       super(null);

  final SetEnvironmentUsecase _setEnvironmentUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final SetBitcoinUnitUsecase _setBitcoinUnitUsecase;
  final SetLanguageUsecase _setLanguageUsecase;
  final SetCurrencyUsecase _setCurrencyUsecase;
  final SetHideAmountsUsecase _setHideAmountsUsecase;
  final SetIsSuperuserUsecase _setIsSuperuserUsecase;

  Future<void> init() async {
    final settings = await _getSettingsUsecase.execute();

    emit(settings);
  }

  Future<void> toggleTestnetMode(bool active) async {
    final environment = active ? Environment.testnet : Environment.mainnet;
    await _setEnvironmentUsecase.execute(environment);
    emit(state?.copyWith(environment: environment));
  }

  Future<void> toggleSatsUnit(bool active) async {
    final unit = active ? BitcoinUnit.sats : BitcoinUnit.btc;
    await _setBitcoinUnitUsecase.execute(unit);
    emit(state?.copyWith(bitcoinUnit: unit));
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

  Future<void> toggleSuperuserMode(bool active) async {
    await _setIsSuperuserUsecase.execute(active);
    emit(state?.copyWith(isSuperuser: active));
  }
}
