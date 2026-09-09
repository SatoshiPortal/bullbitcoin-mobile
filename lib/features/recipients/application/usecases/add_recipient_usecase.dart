import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

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
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  AddRecipientUsecase({
    required this._recipientsGateway,
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

    return (await _recipientsGateway.saveRecipient(
      details,
      isTestnet: isTestnet,
    )).map(
      (recipient) =>
          AddRecipientResult(recipient: RecipientDto.fromDomain(recipient)),
    );
  }
}
