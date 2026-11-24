import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import '../enums/receive_network_type.dart';
import '../receive_display_preferences.dart';
import '../receive_failure.dart';

/// Admits a receive mode against the captured network or active environment.
class GetReceiveSettingsUsecase {
  final Preferences _getSettingsUsecase;

  const GetReceiveSettingsUsecase(this._getSettingsUsecase);

  @useResult
  Future<Result<ReceiveDisplayPreferences, ReceiveFailure>> execute({
    ReceiveNetworkType? mode,
    Network? selectedNetwork,
  }) async {
    try {
      // Not final: Dart 3.14.0 AOT crashes on a switch-assigned final captured by a closure (dart-lang/sdk#64917).
      SettingsEntity settings;
      switch (await _getSettingsUsecase.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          log.warning(
            'Receive preferences unavailable: ${failure.runtimeType}',
          );
          return const Err(ReceiveUnexpectedFailure('Preferences read failed'));
      }
      final network =
          selectedNetwork ??
          BitcoinNetwork.values.firstWhere(
            (network) => network.env == settings.activeNetwork,
          );
      if (mode != null && !mode.supportsNetwork(network)) {
        return const Err(ReceiveUnsupportedNetworkFailure());
      }
      return Ok(
        ReceiveDisplayPreferences(
          bitcoinUnit: settings.bitcoinUnit,
          currencyCode: settings.currencyCode,
        ),
      );
    } on Exception catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to read settings for receive',
        error: e.runtimeType,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
