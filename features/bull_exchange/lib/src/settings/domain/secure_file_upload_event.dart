import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/exchange_document_to_upload.dart';
import 'entities/secure_file_upload.dart';

@immutable
sealed class SecureUploadEvent {
  const SecureUploadEvent();
}

final class UploadStatusLoaded extends SecureUploadEvent {
  final int attempt;
  final Result<SecureFileUpload, ExchangeFailure> result;

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
  final Result<ExchangeDocumentToUpload?, ExchangeFailure> result;

  const UploadPicked(this.result);
}

final class UploadAnswered extends SecureUploadEvent {
  final int attempt;
  final Result<void, ExchangeFailure> result;

  const UploadAnswered(this.attempt, this.result);
}

final class UploadProblemDismissed extends SecureUploadEvent {
  const UploadProblemDismissed();
}
