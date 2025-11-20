import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class GetRecipientsParams {
  final bool fiatOnly;
  final int page;
  final int pageSize;

  GetRecipientsParams({
    this.fiatOnly = true,
    this.page = 1,
    this.pageSize = 50,
  });
}

class GetRecipientsResult {
  final List<RecipientDto> recipients;
  final int totalRecipients;

  GetRecipientsResult({
    required this.recipients,
    required this.totalRecipients,
  });
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

  Future<GetRecipientsResult> execute(GetRecipientsParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final recipientsResult = await _recipientsGateway.listRecipients(
      isTestnet: isTestnet,
      fiatOnly: params.fiatOnly,
      page: params.page,
      pageSize: params.pageSize,
    );
    return GetRecipientsResult(
      recipients:
          recipientsResult.recipients
              .map((e) => RecipientDto.fromDomain(e))
              .toList(),
      totalRecipients: recipientsResult.totalRecipients,
    );
  }
}
