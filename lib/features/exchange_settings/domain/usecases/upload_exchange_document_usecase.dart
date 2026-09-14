import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/document_picker_port.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// What a completed run of [UploadExchangeDocumentUsecase] produced.
sealed class UploadExchangeDocumentOutcome {
  const UploadExchangeDocumentOutcome();
}

/// The user dismissed the picker; nothing was uploaded and nothing is wrong.
final class ExchangeDocumentPickCancelled
    extends UploadExchangeDocumentOutcome {
  const ExchangeDocumentPickCancelled();
}

/// The document reached the exchange.
final class ExchangeDocumentUploaded extends UploadExchangeDocumentOutcome {
  const ExchangeDocumentUploaded();
}

/// Picks a document, checks it against the exchange's limits, and uploads it.
///
/// Every step that can fail is already a `Result`, so this composes them with
/// an explicit short-circuit and holds no `try/catch` of its own except around
/// the shared upload use-case, which still throws.
class UploadExchangeDocumentUsecase {
  final DocumentPickerPort _documentPicker;
  final UploadKycDocumentUsecase _uploadKycDocumentUsecase;

  const UploadExchangeDocumentUsecase({
    required this._documentPicker,
    required this._uploadKycDocumentUsecase,
  });

  @useResult
  Future<Result<UploadExchangeDocumentOutcome, ExchangeSettingsFailure>>
  execute({String? userId}) async {
    final picked = await _documentPicker.pick(
      allowedExtensions: FileToUpload.allowedExtensions,
    );

    final PickedDocument? document;
    switch (picked) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        document = value;
    }

    if (document == null) {
      return const Ok(ExchangeDocumentPickCancelled());
    }

    final rejection = _reject(document);
    if (rejection != null) {
      return Err(rejection);
    }

    // Mirrors the filename BB-Exchange expects for a secure upload.
    final fileName = userId != null ? 'doc-$userId-ID' : document.name;

    try {
      final result = await _uploadKycDocumentUsecase.execute(
        fileBytes: document.bytes!,
        fileName: fileName,
      );

      if (!result.isSuccess) {
        // `errorMessage` is the exchange's own sentence. It is diagnosis
        // material only and must not be rendered, so it is logged here and
        // carried in `logMessage` for equality/debug.
        final reason =
            result.errorMessage ?? 'upload rejected without a reason';
        log.warning('uploadKycDocument rejected: $reason');
        return Err(ExchangeSettingsDocumentUploadFailure(reason));
      }

      return const Ok(ExchangeDocumentUploaded());
    } catch (e, st) {
      log.severe(message: 'uploadKycDocument failed', error: e, trace: st);
      return Err(
        ExchangeSettingsDocumentUploadFailure(
          'uploadKycDocument failed: ${e.runtimeType}',
        ),
      );
    }
  }

  /// The exchange's own limits, expressed as sanitized failures the
  /// presentation layer translates.
  ExchangeSettingsFailure? _reject(PickedDocument document) {
    final bytes = document.bytes;
    // No bytes at all means the picker could not read the file; an empty
    // byte list means the file itself is empty. Different user advice.
    if (bytes == null) {
      return const ExchangeSettingsDocumentUnreadableFailure();
    }
    if (bytes.isEmpty) {
      return const ExchangeSettingsDocumentEmptyFailure();
    }

    if (document.sizeBytes > FileToUpload.maxFileSizeBytes) {
      return const ExchangeSettingsDocumentTooLargeFailure();
    }

    // Lowercased here rather than trusting the adapter, so the rule holds for
    // any DocumentPickerPort implementation.
    final extension = document.extension?.toLowerCase() ?? '';
    if (!FileToUpload.allowedExtensions.contains(extension)) {
      return const ExchangeSettingsDocumentTypeNotAllowedFailure();
    }

    return null;
  }
}
