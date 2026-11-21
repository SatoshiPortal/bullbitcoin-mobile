import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// The environment every recipients call is scoped to.
class GetRecipientsEnvironmentUsecase {
  final Preferences _settingsRepository;

  const GetRecipientsEnvironmentUsecase(this._settingsRepository);

  @useResult
  Future<Result<Environment, RecipientsFailure>> execute() async {
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      return Ok(settings.environment);
    } on Object catch (e, st) {
      log.warning('Could not read the environment', error: e, trace: st);
      return const Err(RecipientsUnexpectedFailure());
    }
  }
}
