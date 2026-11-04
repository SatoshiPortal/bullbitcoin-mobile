import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';

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
  final List<Recipient> recipients;
  final int totalRecipients;

  GetRecipientsResult({
    required this.recipients,
    required this.totalRecipients,
  });
}

class GetRecipientsUsecase {
  final RecipientsRepository _recipientsRepository;
  final GetRecipientsEnvironmentUsecase _getRecipientsEnvironmentUsecase;

  GetRecipientsUsecase({
    required this._recipientsRepository,
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

    // Orchestration only: the repository already mapped its own failure, so
    // this forwards it untouched rather than re-wrapping it.
    return (await _recipientsRepository.listRecipients(
      isTestnet: isTestnet,
      fiatOnly: params.fiatOnly,
      page: params.page,
      pageSize: params.pageSize,
      recipientTypes: params.recipientTypes,
      isOwner: params.isOwner,
      search: params.search,
    )).map(
      (value) => GetRecipientsResult(
        recipients: value.recipients,
        totalRecipients: value.totalRecipients,
      ),
    );
  }
}
