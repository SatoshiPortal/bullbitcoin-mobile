import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show StepNext;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/secure_file_upload.dart';
import '../domain/exchange_settings_failure.dart';
import '../domain/usecases/upload_exchange_document_usecase.dart';

/// Status for the secure file upload UI (matches BB-Exchange DocStatus).
enum SecureUploadStatus {
  upload,
  inReview,
  accepted,
  rejected,

  /// The exchange reported a status this build doesn't know: no upload is
  /// offered until it reports a known one.
  unknown,
}

/// The UI status of a document status read from the account. No status
/// (never uploaded) offers an upload.
SecureUploadStatus secureUploadStatusOf(KycDocumentStatus? status) =>
    switch (status) {
      KycDocumentStatus.accepted => SecureUploadStatus.accepted,
      KycDocumentStatus.underReview => SecureUploadStatus.inReview,
      KycDocumentStatus.notUploaded || null => SecureUploadStatus.upload,
      KycDocumentStatus.rejected => SecureUploadStatus.rejected,
      KycDocumentStatus.unknown => SecureUploadStatus.unknown,
    };

@immutable
sealed class SecureUploadState {
  const SecureUploadState();
}

final class UploadStatusLoading extends SecureUploadState {
  final int attempt;

  const UploadStatusLoading(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is UploadStatusLoading && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(UploadStatusLoading, attempt);
}

/// The status could not be read: no upload is offered (SET-1).
final class UploadStatusFailed extends SecureUploadState {
  final int attempt;
  final ExchangeSettingsFailure failure;

  const UploadStatusFailed(this.attempt, this.failure);

  @override
  bool operator ==(Object other) =>
      other is UploadStatusFailed &&
      other.attempt == attempt &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(UploadStatusFailed, attempt, failure);
}

/// An upload is allowed (nothing uploaded yet, or the last one was
/// rejected). [problem] is the last pick or upload failure.
final class UploadReady extends SecureUploadState {
  final SecureFileUpload account;
  final int attempts;
  final ExchangeSettingsFailure? problem;

  const UploadReady(this.account, this.attempts, {this.problem});

  SecureUploadStatus get status => secureUploadStatusOf(account.status);

  @override
  bool operator ==(Object other) =>
      other is UploadReady &&
      other.account.userId == account.userId &&
      other.account.status == account.status &&
      other.attempts == attempts &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(
    UploadReady,
    account.userId,
    account.status,
    attempts,
    problem,
  );
}

/// The document is in review, accepted, or in a status this build doesn't
/// know: nothing to upload.
final class UploadBlocked extends SecureUploadState {
  final SecureUploadStatus status;

  const UploadBlocked(this.status);

  @override
  bool operator ==(Object other) =>
      other is UploadBlocked && other.status == status;

  @override
  int get hashCode => Object.hash(UploadBlocked, status);
}

/// The file picker is open (SET-5: its own state, not the upload's).
final class UploadPicking extends SecureUploadState {
  final SecureFileUpload account;
  final int attempts;

  const UploadPicking(this.account, this.attempts);

  @override
  bool operator ==(Object other) =>
      other is UploadPicking &&
      other.account.userId == account.userId &&
      other.account.status == account.status &&
      other.attempts == attempts;

  @override
  int get hashCode =>
      Object.hash(UploadPicking, account.userId, account.status, attempts);
}

final class UploadSending extends SecureUploadState {
  final SecureFileUpload account;
  final int attempt;

  const UploadSending(this.account, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is UploadSending &&
      other.account.userId == account.userId &&
      other.account.status == account.status &&
      other.attempt == attempt;

  @override
  int get hashCode =>
      Object.hash(UploadSending, account.userId, account.status, attempt);
}

/// The document reached the exchange; the status is read again. Entered on
/// every upload, so each one is confirmed (SET-4).
final class UploadDone extends SecureUploadState {
  final int attempt;

  const UploadDone(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is UploadDone && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(UploadDone, attempt);
}

@immutable
sealed class SecureUploadEvent {
  const SecureUploadEvent();
}

final class UploadStatusLoaded extends SecureUploadEvent {
  final int attempt;
  final Result<SecureFileUpload, ExchangeSettingsFailure> result;

  const UploadStatusLoaded(this.attempt, this.result);
}

final class UploadRetryPressed extends SecureUploadEvent {
  const UploadRetryPressed();
}

final class UploadPressed extends SecureUploadEvent {
  const UploadPressed();
}

/// `null` means the picker was dismissed.
final class UploadPicked extends SecureUploadEvent {
  final Result<ExchangeDocumentToUpload?, ExchangeSettingsFailure> result;

  const UploadPicked(this.result);
}

final class UploadAnswered extends SecureUploadEvent {
  final int attempt;
  final Result<void, ExchangeSettingsFailure> result;

  const UploadAnswered(this.attempt, this.result);
}

final class UploadProblemDismissed extends SecureUploadEvent {
  const UploadProblemDismissed();
}

@immutable
sealed class SecureUploadEffect {
  const SecureUploadEffect();
}

final class FetchUploadStatus extends SecureUploadEffect {
  final int attempt;

  const FetchUploadStatus(this.attempt);

  @override
  bool operator ==(Object other) =>
      other is FetchUploadStatus && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(FetchUploadStatus, attempt);
}

final class PickUploadDocument extends SecureUploadEffect {
  final String? userId;

  const PickUploadDocument(this.userId);

  @override
  bool operator ==(Object other) =>
      other is PickUploadDocument && other.userId == userId;

  @override
  int get hashCode => Object.hash(PickUploadDocument, userId);
}

final class SendUploadDocument extends SecureUploadEffect {
  final int attempt;
  final ExchangeDocumentToUpload document;

  const SendUploadDocument(this.attempt, this.document);

  @override
  bool operator ==(Object other) =>
      other is SendUploadDocument &&
      other.attempt == attempt &&
      identical(other.document, document);

  @override
  int get hashCode => Object.hash(SendUploadDocument, attempt, document);
}

typedef SecureUploadNext = StepNext<SecureUploadState, SecureUploadEffect>;

SecureUploadNext secureUploadStart() =>
    StepNext(const UploadStatusLoading(1), const [FetchUploadStatus(1)]);

SecureUploadState _fromAccount(SecureFileUpload account, int attempts) =>
    switch (secureUploadStatusOf(account.status)) {
      SecureUploadStatus.upload ||
      SecureUploadStatus.rejected => UploadReady(account, attempts),
      final status &&
          (SecureUploadStatus.inReview ||
              SecureUploadStatus.accepted ||
              SecureUploadStatus.unknown) =>
        UploadBlocked(status),
    };

SecureUploadNext transitionSecureUpload(
  SecureUploadState state,
  SecureUploadEvent event,
) => switch ((state, event)) {
  (
    UploadStatusLoading(:final attempt) || UploadDone(:final attempt),
    UploadStatusLoaded loaded,
  )
      when loaded.attempt == attempt =>
    StepNext(switch (loaded.result) {
      Ok(:final value) => _fromAccount(value, attempt),
      Err(:final failure) => UploadStatusFailed(attempt, failure),
    }),
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadStatusFailed() ||
        UploadReady() ||
        UploadBlocked() ||
        UploadPicking() ||
        UploadSending(),
    UploadStatusLoaded(),
  ) =>
    StepNext.stay(state),
  (UploadStatusFailed(:final attempt), UploadRetryPressed()) => StepNext(
    UploadStatusLoading(attempt + 1),
    [FetchUploadStatus(attempt + 1)],
  ),
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadReady() ||
        UploadBlocked() ||
        UploadPicking() ||
        UploadSending(),
    UploadRetryPressed(),
  ) =>
    StepNext.stay(state),
  (UploadReady(:final account, :final attempts), UploadPressed()) => StepNext(
    UploadPicking(account, attempts),
    [PickUploadDocument(account.userId)],
  ),
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadStatusFailed() ||
        UploadBlocked() ||
        UploadPicking() ||
        UploadSending(),
    UploadPressed(),
  ) =>
    StepNext.stay(state),
  (
    UploadPicking(:final account, :final attempts),
    UploadPicked(:final result),
  ) =>
    switch (result) {
      Ok(value: null) => StepNext(UploadReady(account, attempts)),
      Ok(value: final ExchangeDocumentToUpload document) => StepNext(
        UploadSending(account, attempts + 1),
        [SendUploadDocument(attempts + 1, document)],
      ),
      Err(:final failure) => StepNext(
        UploadReady(account, attempts, problem: failure),
      ),
    },
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadStatusFailed() ||
        UploadReady() ||
        UploadBlocked() ||
        UploadSending(),
    UploadPicked(),
  ) =>
    StepNext.stay(state),
  (UploadSending(:final account, :final attempt), UploadAnswered answered)
      when answered.attempt == attempt =>
    switch (answered.result) {
      Ok() => StepNext(UploadDone(attempt + 1), [
        FetchUploadStatus(attempt + 1),
      ]),
      Err(:final failure) => StepNext(
        UploadReady(account, attempt, problem: failure),
      ),
    },
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadStatusFailed() ||
        UploadReady() ||
        UploadBlocked() ||
        UploadPicking() ||
        UploadSending(),
    UploadAnswered(),
  ) =>
    StepNext.stay(state),
  (
    UploadReady(:final account, :final attempts, problem: _?),
    UploadProblemDismissed(),
  ) =>
    StepNext(UploadReady(account, attempts)),
  (
    UploadStatusLoading() ||
        UploadDone() ||
        UploadStatusFailed() ||
        UploadReady() ||
        UploadBlocked() ||
        UploadPicking() ||
        UploadSending(),
    UploadProblemDismissed(),
  ) =>
    StepNext.stay(state),
};
