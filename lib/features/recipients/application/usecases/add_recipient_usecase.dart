import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class AddRecipientParams {
  final RecipientDetailsDto recipientDetails;

  AddRecipientParams({required this.recipientDetails});
}

class AddRecipientResult {
  final RecipientDto recipient;

  AddRecipientResult({required this.recipient});
}

class AddRecipientUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  // TODO: The settings repository should not be used directly here, since it is
  // from another domain. We should use a settings port that gets the settings
  // facade injected so no business logic is skipped from the settings domain.
  final SettingsRepository _settingsRepository;

  AddRecipientUsecase({
    required RecipientsGatewayPort recipientsGateway,
    required SettingsRepository settingsRepository,
  }) : _recipientsGateway = recipientsGateway,
       _settingsRepository = settingsRepository;

  Future<AddRecipientResult> execute(AddRecipientParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final recipient = await _recipientsGateway.saveRecipient(
      params.recipientDetails.toDomain(),
      isTestnet: isTestnet,
    );

    return AddRecipientResult(recipient: RecipientDto.fromDomain(recipient));
  }
}
