import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipient_update_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';

class UpdateRecipientParams {
  const UpdateRecipientParams({
    required this.recipientId,
    required this.recipientDetails,
  });

  final String recipientId;
  final RecipientDetails recipientDetails;
}

class UpdateRecipientUsecase {
  const UpdateRecipientUsecase(this._recipientRepository, this._settingsFacade);

  final RecipientUpdateRepository _recipientRepository;
  final SettingsFacade _settingsFacade;

  Future<Result<void, RecipientsFailure>> execute(
    UpdateRecipientParams params,
  ) async {
    final environment = await _settingsFacade.getTestnetMode();
    switch (environment) {
      case Ok(value: final isTestnet):
        return _recipientRepository.update(
          params.recipientId,
          params.recipientDetails,
          isTestnet: isTestnet,
        );
      case Err():
        return const Err(
          RecipientsUnexpectedFailure('Failed to read exchange environment'),
        );
    }
  }
}
