import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:primitives/primitives.dart';

/// Captures setup's network without exposing settings storage to presentation.
class GetSpActiveNetworkUsecase {
  final SettingsRepository _settingsRepository;

  GetSpActiveNetworkUsecase({required this._settingsRepository});

  Future<Result<BitcoinNetwork, SpFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final network = BitcoinNetwork.values.firstWhere(
        (network) => network.env == settings.environment.networkEnv,
      );
      if (!NetworkCapabilities.supports(
        network,
        NetworkCapability.silentPayments,
      )) {
        return const Err(SpUnsupportedNetwork());
      }
      return Ok(network);
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP active network read failed'));
    }
  }
}
