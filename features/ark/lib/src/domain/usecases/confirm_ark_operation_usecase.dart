import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';
import '../repositories/ark_preferences_repository.dart';
import '../repositories/ark_repository.dart';

final class ConfirmArkOperationUsecase {
  final ArkRepository _repository;
  final ArkPreferencesRepository _preferences;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// Ark's writer lock is held briefly by its own background checks; a busy
  /// refusal is retried this many times before it is reported.
  static const busyRetries = 5;
  static const busyDelay = Duration(seconds: 1);

  ConfirmArkOperationUsecase(
    this._repository,
    this._preferences, {
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  }) : _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

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
    for (var attempt = 0; ; attempt++) {
      final result = await _repository.submit(
        account,
        ArkSubmission.confirmQuote(
          quoteId: reviewedQuote.id,
          operationId: operationId,
        ),
      );
      // Busy is usually Ark's own background check holding the writer lock
      // for a moment: wait it out. Each retry reuses [operationId], so an
      // attempt that did take effect is returned, never run twice; busy that
      // persists falls through to the unknown outcome below, like any other.
      if (result case Err(failure: ArkOperationBusyFailure())
          when attempt < busyRetries) {
        await _wait(busyDelay);
        continue;
      }
      switch (result) {
        case Ok():
          return result;
        case Err(:final failure):
          return Err(await _settled(account, operationId, failure));
      }
    }
  }

  /// A typed failure does not by itself prove nothing was sent. The client
  /// records an operation before sending it, so an attempt that left no
  /// record was refused before anything left (a stale quote, busy, invalid):
  /// its real reason is shown and the user may simply retry. A recorded
  /// attempt, an unreadable record, or a storage or unexpected failure
  /// keeps the original attempt as an unknown outcome.
  Future<ArkFailure> _settled(
    ArkAccountId account,
    String operationId,
    ArkFailure failure,
  ) async {
    final uncertain = ArkSubmissionUncertainFailure(operationId);
    if (failure is ArkSubmissionUncertainFailure ||
        failure is ArkFeatureStorageFailure ||
        failure is ArkUnexpectedFailure) {
      return uncertain;
    }
    return switch (await _repository.read(account)) {
      Ok(:final value)
          when !value.operations.any((op) => op.id == operationId) =>
        failure,
      _ => uncertain,
    };
  }
}
