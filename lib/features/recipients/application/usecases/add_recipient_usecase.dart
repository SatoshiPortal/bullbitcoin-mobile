import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class AddRecipientParams {
  final RecipientDetailsDto recipientDetails;

  AddRecipientParams({required this.recipientDetails});
}

class AddRecipientResult {
  final Recipient recipient;

  AddRecipientResult({required this.recipient});
}

class AddRecipientUsecase {
  final RecipientsGatewayPort _recipientsGateway;
  final SepaVirtualPayeeRepository _sepaVirtualPayeeRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  AddRecipientUsecase({
    required this._recipientsGateway,
    required this._sepaVirtualPayeeRepository,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<AddRecipientResult, RecipientsFailure>> execute(
    AddRecipientParams params,
  ) async {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        return Err(failure);
    }

    // toDomain() throws: it raises StateError for a missing required field,
    //  and the value-object create() constructors raise ArgumentError for an
    //  empty or invalid one. The form is supposed to have caught both, so a
    //  throw here means form validation and domain validation have drifted
    //  apart — but that is user-reachable, and this method's signature
    //  promises a Result. Left unguarded it would escape into a bloc that no
    //  longer has a catch, hanging the Continue button on a spinner with
    //  nothing shown.
    final RecipientDetails details;
    try {
      details = params.recipientDetails.toDomain();
    } on Object catch (e, st) {
      log.warning(
        'Recipient details rejected by the domain',
        error: e,
        trace: st,
      );
      return const Err(RecipientsSaveFailure());
    }

    final Recipient recipient;
    switch (await _recipientsGateway.saveRecipient(
      details,
      isTestnet: isTestnet,
    )) {
      case Ok(:final value):
        recipient = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (details is! SepaEurDetails || !details.isConfidential) {
      return Ok(AddRecipientResult(recipient: recipient));
    }

    // The API saves a Confidential SEPA recipient as a regular one; its
    // virtual payee is activated separately. An activation failure does not
    // fail the save: the activation screen retries it before any payout.
    final activation = await _sepaVirtualPayeeRepository.activate(
      recipientId: recipient.recipientId,
      isTestnet: isTestnet,
    );
    if (activation case Err(:final failure)) {
      log.warning(
        'Saved a Confidential SEPA recipient, but could not activate it: '
        '${failure.runtimeType}',
      );
    }
    final savedDetails = recipient.details;
    return Ok(
      AddRecipientResult(
        recipient: savedDetails is SepaEurDetails
            ? recipient.withDetails(savedDetails.asConfidential())
            : recipient,
      ),
    );
  }
}
