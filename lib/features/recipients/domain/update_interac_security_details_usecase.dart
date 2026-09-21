import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipient_update_repository.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';

class UpdateInteracSecurityDetailsUsecase {
  const UpdateInteracSecurityDetailsUsecase(
    this._repository,
    this._settingsFacade,
  );

  final RecipientUpdateRepository _repository;
  final SettingsFacade _settingsFacade;

  Future<Result<void, RecipientsFailure>> execute(
    InteracSecurityDetails details,
  ) async {
    final environment = await _settingsFacade.getTestnetMode();
    return switch (environment) {
      Ok(value: final isTestnet) => _repository.updateInteracSecurityDetails(
        details,
        isTestnet: isTestnet,
      ),
      Err() => const Err(
        RecipientsUnexpectedFailure('Failed to read exchange environment'),
      ),
    };
  }
}
