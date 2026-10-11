import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class GetExchangeWebSettingsUsecase {
  final SettingsRepository _settingsRepository;

  GetExchangeWebSettingsUsecase({required this._settingsRepository});

  @useResult
  Future<Result<SettingsEntity, ExchangeFailure>> execute() async {
    try {
      return Ok(await _settingsRepository.fetch());
    } on Exception catch (exception, trace) {
      log.warning(
        'Could not load exchange web settings: ${exception.runtimeType}',
        trace: trace,
      );
      return const Err(ExchangeUnexpectedFailure());
    }
  }
}
