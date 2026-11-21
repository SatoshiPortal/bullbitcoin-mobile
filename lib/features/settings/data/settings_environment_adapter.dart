import 'package:primitives/primitives.dart';
import 'package:mempool/mempool.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';

class SettingsEnvironmentAdapter {
  final SettingsRepository _settingsRepository;

  SettingsEnvironmentAdapter({required this._settingsRepository});

  Future<Result<BitcoinNetwork, MempoolFailure>> getEnvironment() async {
    try {
      final settings = await _settingsRepository.fetch();
      final network = BitcoinNetwork.fromName(settings.environment.name);
      if (!NetworkCapabilities.supports(
        network,
        NetworkCapability.publicExplorer,
      )) {
        return Err(MempoolUnsupportedNetworkFailure(network));
      }
      return Ok(network);
    } catch (e, st) {
      log.severe(
        message: 'Failed to fetch environment for mempool',
        error: e,
        trace: st,
      );
      return Err(MempoolUnexpectedFailure(e.toString()));
    }
  }
}
