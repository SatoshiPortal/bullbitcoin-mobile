import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';

class AddRecipientParams {
  final bool isTestnet;
  final RecipientDetailsDto recipientDetails;

  AddRecipientParams({required this.isTestnet, required this.recipientDetails});
}

class AddRecipientResult {
  final RecipientDto recipient;

  AddRecipientResult({required this.recipient});
}

class AddRecipientUsecase {
  final RecipientsGatewayPort _recipientsGateway;

  AddRecipientUsecase({required RecipientsGatewayPort recipientsGateway})
    : _recipientsGateway = recipientsGateway;

  Future<AddRecipientResult> execute(AddRecipientParams params) async {
    final recipient = await _recipientsGateway.saveRecipient(
      params.recipientDetails.toDomain(),
      isTestnet: params.isTestnet,
    );

    return AddRecipientResult(recipient: RecipientDto.fromDomain(recipient));
  }
}
