import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

class SettingsEnvironmentAdapter implements MempoolEnvironmentPort {
  final SettingsRepository _settingsRepository;

  SettingsEnvironmentAdapter({
    required this._settingsRepository,
  });

  @override
  Future<Result<Environment, MempoolFailure>> getEnvironment() async {
    try {
      final settings = await _settingsRepository.fetch();
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
