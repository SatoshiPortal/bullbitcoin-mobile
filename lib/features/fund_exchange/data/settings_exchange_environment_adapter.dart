import 'package:primitives/primitives.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/fund_exchange/domain/exchange_environment_port.dart';

class SettingsExchangeEnvironmentAdapter implements ExchangeEnvironmentPort {
  // TODO: Once the settings feature is re-arch'ed,
  // use the defined public API/facade instead of the usecase directly
  final Preferences _getSettingsUsecase;

  SettingsExchangeEnvironmentAdapter({required this._getSettingsUsecase});

  @override
  Future<bool> get isTestnet async {
    final settings = (await _getSettingsUsecase.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    if (!NetworkCapabilities.supports(
      BitcoinNetwork.fromName(settings.activeNetwork.name),
      NetworkCapability.exchange,
    )) {
      throw const UnsupportedExchangeNetworkException();
    }
    return settings.environment.requireHistoricalTestnet();
  }
}
