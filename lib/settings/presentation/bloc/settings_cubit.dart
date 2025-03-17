import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_language_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<Settings?> {
  SettingsCubit({
    required SetEnvironmentUseCase setEnvironmentUseCase,
    required GetEnvironmentUseCase getEnvironmentUseCase,
    required SetBitcoinUnitUseCase setBitcoinUnitUseCase,
    required GetBitcoinUnitUseCase getBitcoinUnitUseCase,
    required SetLanguageUseCase setLanguageUseCase,
    required GetLanguageUseCase getLanguageUseCase,
    required SetCurrencyUseCase setCurrencyUseCase,
    required GetCurrencyUseCase getCurrencyUseCase,
  })  : _setEnvironmentUseCase = setEnvironmentUseCase,
        _getEnvironmentUseCase = getEnvironmentUseCase,
        _setBitcoinUnitUseCase = setBitcoinUnitUseCase,
        _getBitcoinUnitUseCase = getBitcoinUnitUseCase,
        _setLanguageUseCase = setLanguageUseCase,
        _getLanguageUseCase = getLanguageUseCase,
        _setCurrencyUseCase = setCurrencyUseCase,
        _getCurrencyUseCase = getCurrencyUseCase,
        super(null);

  final SetEnvironmentUseCase _setEnvironmentUseCase;
  final GetEnvironmentUseCase _getEnvironmentUseCase;
  final SetBitcoinUnitUseCase _setBitcoinUnitUseCase;
  final GetBitcoinUnitUseCase _getBitcoinUnitUseCase;
  final SetLanguageUseCase _setLanguageUseCase;
  final GetLanguageUseCase _getLanguageUseCase;
  final SetCurrencyUseCase _setCurrencyUseCase;
  final GetCurrencyUseCase _getCurrencyUseCase;

  Future<void> init() async {
    final environment = await _getEnvironmentUseCase.execute();
    final bitcoinUnit = await _getBitcoinUnitUseCase.execute();
    final language = await _getLanguageUseCase.execute();
    final currency = await _getCurrencyUseCase.execute();

    emit(
      Settings(
        environment: environment,
        bitcoinUnit: bitcoinUnit,
        language: language,
        currencyCode: currency,
      ),
    );
  }

  Future<void> toggleTestnetMode(bool active) async {
    final environment = active ? Environment.testnet : Environment.mainnet;
    await _setEnvironmentUseCase.execute(environment);
    emit(
      state?.copyWith(environment: environment),
    );
  }

  Future<void> toggleSatsUnit(bool active) async {
    final unit = active ? BitcoinUnit.sats : BitcoinUnit.btc;
    await _setBitcoinUnitUseCase.execute(unit);
    emit(
      state?.copyWith(bitcoinUnit: unit),
    );
  }

  Future<void> changeLanguage(Language language) async {
    await _setLanguageUseCase.execute(language);
    emit(state?.copyWith(language: language));
  }

  Future<void> changeCurrency(String currencyCode) async {
    await _setCurrencyUseCase.execute(currencyCode);
    emit(state?.copyWith(currencyCode: currencyCode));
  }
}
