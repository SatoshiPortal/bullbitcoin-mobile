import 'package:preferences/preferences.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:primitives/primitives.dart';

/// Captures setup's network without exposing settings storage to presentation.
class GetSpActiveNetworkUsecase {
  final Preferences _settingsRepository;

  GetSpActiveNetworkUsecase({required this._settingsRepository});

  Future<Result<BitcoinNetwork, SilentFailure>> execute() async {
    try {
      final result = await _settingsRepository.fetch();
      final settings = result.fold((value) => value, (_) => null);
      if (settings == null) {
        return const Err(SilentUnexpected('SP active network read failed'));
      }
      final network = BitcoinNetwork.values.firstWhere(
        (network) => network.env == settings.environment.networkEnv,
      );
      if (!NetworkCapabilities.supports(
        network,
        NetworkCapability.silentPayments,
      )) {
        return const Err(SilentUnsupportedNetwork());
      }
      return Ok(network);
    } on Exception catch (_) {
      return const Err(SilentUnexpected('SP active network read failed'));
    }
  }
}
