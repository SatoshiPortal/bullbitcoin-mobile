import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

class AddRecipientParams {
  final RecipientDetailsDto recipientDetails;

  AddRecipientParams({required this.recipientDetails});
}

class AddRecipientResult {
  final RecipientDto recipient;
  final RecipientsFailure? activationFailure;

  AddRecipientResult({required this.recipient, this.activationFailure});
}

class AddRecipientUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  final SepaVirtualPayeeRepository _sepaVirtualPayeeRepository;
  // TODO: The settings repository should not be used directly here, since it is
  // from another domain. We should use a settings port that gets the settings
  // facade injected so no business logic is skipped from the settings domain.
  final SettingsRepository _settingsRepository;

  AddRecipientUsecase(
    this._sepaVirtualPayeeRepository, {
    required this._recipientsGateway,
    required this._settingsRepository,
  });

  Future<AddRecipientResult> execute(AddRecipientParams params) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    var recipient = await _recipientsGateway.saveRecipient(
      params.recipientDetails.toDomain(),
      isTestnet: isTestnet,
    );

    RecipientsFailure? activationFailure;
    if (params.recipientDetails.recipientType ==
        RecipientType.confidentialSepaEur) {
      recipient = _asConfidentialSepa(recipient);
      final activation = await _sepaVirtualPayeeRepository.activate(
        recipientId: recipient.recipientId,
        isTestnet: isTestnet,
      );
      if (activation case Ok(:final value)) {
        recipient = _asConfidentialSepa(value);
      } else if (activation case Err(:final failure)) {
        activationFailure = failure;
      }
    }

    return AddRecipientResult(
      recipient: RecipientDto.fromDomain(recipient),
      activationFailure: activationFailure,
    );
  }

  Recipient _asConfidentialSepa(Recipient recipient) {
    final details = recipient.details;
    if (details is! SepaEurDetails) {
      throw StateError(
        'Confidential SEPA creation returned a non-SEPA recipient',
      );
    }

    return Recipient.create(
      recipientId: recipient.recipientId,
      userId: recipient.userId,
      userNbr: recipient.userNbr,
      isArchived: recipient.isArchived,
      createdAt: recipient.createdAt,
      updatedAt: recipient.updatedAt,
      details: details.asConfidential(),
    );
  }
}
