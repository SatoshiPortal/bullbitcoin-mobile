import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../swap_failure.dart';

typedef TransferPreferences = ({
  BitcoinUnit bitcoinUnit,
  String currencyCode,
  NetworkEnv activeNetwork,
});

class LoadTransferPreferencesUsecase {
  final Preferences _preferences;

  const LoadTransferPreferencesUsecase(this._preferences);

  Future<Result<TransferPreferences, SwapFailure>> execute() async =>
      (await _preferences.fetch())
          .map(
            (settings) => (
              bitcoinUnit: settings.bitcoinUnit,
              currencyCode: settings.currencyCode,
              activeNetwork: settings.activeNetwork,
            ),
          )
          .mapErr((failure) => SwapStorageFailure(failure.logMessage));
}
