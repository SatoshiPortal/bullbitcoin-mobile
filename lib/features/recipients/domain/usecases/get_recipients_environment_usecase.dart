import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The environment every recipients call is scoped to.
class GetRecipientsEnvironmentUsecase {
  final SettingsRepository _settingsRepository;

  const GetRecipientsEnvironmentUsecase(this._settingsRepository);

  @useResult
  Future<Result<Environment, RecipientsFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      return Ok(settings.environment);
    } on Object catch (e, st) {
      log.warning('Could not read the environment', error: e, trace: st);
      return const Err(RecipientsUnexpectedFailure());
    }
  }
}
