import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';
import '../repositories/ark_repository.dart';

final class ConfirmArkOperationUsecase {
  final ArkRepository _repository;
  final ArkPreferencesRepository _preferences;
  final DateTime Function() _now;
  ConfirmArkOperationUsecase(
    this._repository,
    this._preferences, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<Result<ArkOperation, ArkFailure>> execute(
    ArkAccountId account,
    ArkQuote reviewedQuote,
    String operationId,
  ) async {
    if (reviewedQuote.account != account || operationId.trim().isEmpty) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (!_now().isBefore(reviewedQuote.validUntil)) {
      return const Err(ArkReviewExpiredFailure());
    }
    if (!NetworkCapabilities.supports(account.network, NetworkCapability.ark)) {
      return const Err(ArkNetworkUnavailableFailure());
    }
    if (reviewedQuote.kind == ArkOperationKind.board) {
      // Boarding must go through the host's atomic source-wallet funding flow.
      return const Err(ArkServiceUnavailableFailure());
    }
    if (reviewedQuote.kind == ArkOperationKind.payment) {
      switch (await _preferences.isEnabled(account)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: false):
          return const Err(ArkDisabledFailure());
        case Ok():
          break;
      }
    }
    return _repository.submit(
      account,
      ArkSubmission.confirmQuote(
        quoteId: reviewedQuote.id,
        operationId: operationId,
      ),
    );
  }
}
