import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class GetRecipientsParams {
  final bool isTestnet;

  GetRecipientsParams({required this.isTestnet});
}

class GetRecipientsResult {
  final List<RecipientDto> recipients;

  GetRecipientsResult({required this.recipients});
}

class GetRecipientsUsecase {
  final RecipientsGatewayPort _recipientsGateway;

  GetRecipientsUsecase({required RecipientsGatewayPort recipientsGateway})
    : _recipientsGateway = recipientsGateway;

  Future<GetRecipientsResult> call(GetRecipientsParams params) async {
    final recipients = await _recipientsGateway.listRecipients(
      isTestnet: params.isTestnet,
    );
    return GetRecipientsResult(
      recipients: recipients.map((e) => RecipientDto.fromDomain(e)).toList(),
    );
  }
}
