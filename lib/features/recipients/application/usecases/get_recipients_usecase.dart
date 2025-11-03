import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class GetRecipientsParams {
  final bool fiatOnly;

  GetRecipientsParams({this.fiatOnly = true});
}

class GetRecipientsResult {
  final List<RecipientDto> recipients;

  GetRecipientsResult({required this.recipients});
}

class GetRecipientsUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  // TODO: The settings repository should not be used directly here, since it is
  // from another domain. We should use a settings port that gets the settings
  // facade injected so no business logic is skipped from the settings domain.
  final SettingsRepository _settingsRepository;

  GetRecipientsUsecase({
    required RecipientsGatewayPort recipientsGateway,
    required SettingsRepository settingsRepository,
  }) : _recipientsGateway = recipientsGateway,
       _settingsRepository = settingsRepository;

  Future<GetRecipientsResult> call(GetRecipientsParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final recipients = await _recipientsGateway.listRecipients(
      isTestnet: isTestnet,
      fiatOnly: params.fiatOnly,
    );
    return GetRecipientsResult(
      recipients: recipients.map((e) => RecipientDto.fromDomain(e)).toList(),
    );
  }
}
