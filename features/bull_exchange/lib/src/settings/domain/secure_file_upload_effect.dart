import 'package:meta/meta.dart';

import 'entities/exchange_document_to_upload.dart';

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
