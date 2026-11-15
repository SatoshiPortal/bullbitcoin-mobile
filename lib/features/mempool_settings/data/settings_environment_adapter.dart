import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';

class SettingsEnvironmentAdapter implements MempoolEnvironmentPort {
  final SettingsRepository _settingsRepository;

  SettingsEnvironmentAdapter({required this._settingsRepository});

  @override
  Future<Result<Environment, MempoolFailure>> getEnvironment() async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.publicExplorer,
      )) {
        return const Err(MempoolLoadFailure('network unsupported'));
      }
      return Ok(settings.environment);
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
