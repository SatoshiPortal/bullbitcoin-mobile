import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../send_failure.dart';

class LoadSendDisplayPreferencesUsecase {
  final Preferences _preferences;

  const LoadSendDisplayPreferencesUsecase(this._preferences);

  Future<Result<({BitcoinUnit bitcoinUnit, String currencyCode}), SendFailure>>
  execute() async => (await _preferences.fetch())
      .map(
        (settings) => (
          bitcoinUnit: settings.bitcoinUnit,
          currencyCode: settings.currencyCode,
        ),
      )
      .mapErr(
        (failure) => SendUnexpectedFailure(failure.runtimeType.toString()),
      );
}
