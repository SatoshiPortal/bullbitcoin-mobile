import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

class GetRecipientsParams {
  final bool fiatOnly;
  final int page;
  final int pageSize;
  final List<RecipientType>? recipientTypes;
  final bool? isOwner;
  final String? search;

  GetRecipientsParams({
    this.fiatOnly = true,
    this.page = 1,
    this.pageSize = 50,
    this.recipientTypes,
    this.isOwner,
    this.search,
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
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  GetRecipientsUsecase({
    required this._recipientsGateway,
    required this._getRecipientsEnvironmentUsecase,
  });

  @useResult
  Future<Result<GetRecipientsResult, RecipientsFailure>> execute(
    GetRecipientsParams params,
  ) async {
    final bool isTestnet;
    switch (await _getRecipientsEnvironmentUsecase.execute()) {
      case Ok(:final value):
        isTestnet = value.isTestnet;
      case Err(:final failure):
        return Err(failure);
    }

    // Orchestration only: the gateway already mapped its own failure, so
    // this forwards it untouched rather than re-wrapping it.
    return (await _recipientsGateway.listRecipients(
      isTestnet: isTestnet,
      fiatOnly: params.fiatOnly,
      page: params.page,
      pageSize: params.pageSize,
      recipientTypes: params.recipientTypes,
      isOwner: params.isOwner,
      search: params.search,
    )).map(
      (value) => GetRecipientsResult(
        recipients: value.recipients
            .map((e) => RecipientDto.fromDomain(e))
            .toList(),
        totalRecipients: value.totalRecipients,
      ),
    );
  }
}
