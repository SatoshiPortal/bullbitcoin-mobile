import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// The environment every recipients call is scoped to.
class GetRecipientsEnvironmentUsecase {
  final Preferences _settingsRepository;

  const GetRecipientsEnvironmentUsecase(this._settingsRepository);

  @useResult
  Future<Result<Environment, RecipientsFailure>> execute() async {
    try {
      return switch (await _settingsRepository.fetch()) {
        Ok(value: final settings)
            when settings.environment != Environment.regtest =>
          Ok(settings.environment),
        Ok() => const Err(RecipientsUnsupportedNetworkFailure()),
        Err() => const Err(RecipientsUnexpectedFailure()),
      };
    } on Exception {
      return const Err(RecipientsUnexpectedFailure());
    }
  }
}
