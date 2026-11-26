import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_document_to_upload.dart';
import '../exchange_settings_failure.dart';

/// Uploads a checked document to the exchange. Any failure is one sanitized
/// upload failure: the exchange's text never reaches the screen.
class UploadExchangeDocumentUsecase {
  final Exchange _exchange;

  const UploadExchangeDocumentUsecase({required this._exchange});

  @useResult
  Future<Result<void, ExchangeSettingsFailure>> execute(
    ExchangeDocumentToUpload document,
  ) async => switch (await _exchange.uploadKycDocument(
    fileBytes: document.bytes,
    fileName: document.fileName,
  )) {
    Ok() => const Ok(null),
    Err() => const Err(ExchangeSettingsDocumentUploadFailure()),
  };
}
