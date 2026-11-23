import 'package:bb_mobile/features/exchange_settings/domain/entities/file_upload.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:file_system/file_system.dart';
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
/// an explicit short-circuit and translates failures at the feature boundary.
class UploadExchangeDocumentUsecase {
  final FileSystem _fileSystem;
  final Exchange _exchange;

  const UploadExchangeDocumentUsecase({
    required this._fileSystem,
    required this._exchange,
  });

  @useResult
  Future<Result<UploadExchangeDocumentOutcome, ExchangeSettingsFailure>>
  execute({String? userId}) async {
    final picked = await _fileSystem.pick(
      allowedExtensions: FileToUpload.allowedExtensions,
    );

    final PickedDocument? document;
    switch (picked) {
      case Err(:final failure):
        log.warning('Document picker failed', error: failure.logMessage);
        return Err(
          ExchangeSettingsUnexpectedFailure(
            'pickFiles failed: ${failure.logMessage}',
          ),
        );
      case Ok(:final value):
        document = value;
    }

    if (document == null) {
      return const Ok(ExchangeDocumentPickCancelled());
    }

    final List<int> bytes;
    switch (await _fileSystem.read(
      document,
      maxBytes: FileToUpload.maxFileSizeBytes,
    )) {
      case Err(:final failure):
        if (failure is FileSystemTooLargeFailure) {
          return const Err(ExchangeSettingsDocumentTooLargeFailure());
        }
        log.warning(
          'Selected document could not be read',
          error: failure.logMessage,
        );
        return const Err(ExchangeSettingsDocumentUnreadableFailure());
      case Ok(:final value):
        bytes = value;
    }
    if (bytes.isEmpty) {
      return const Err(ExchangeSettingsDocumentEmptyFailure());
    }
    final extension = document.extension?.toLowerCase() ?? '';
    if (!FileToUpload.allowedExtensions.contains(extension)) {
      return const Err(ExchangeSettingsDocumentTypeNotAllowedFailure());
    }

    // Mirrors the filename BB-Exchange expects for a secure upload.
    final fileName = userId != null ? 'doc-$userId-ID' : document.name;

    return switch (await _exchange.uploadKycDocument(
      fileBytes: bytes,
      fileName: fileName,
    )) {
      Ok() => const Ok(ExchangeDocumentUploaded()),
      Err() => const Err(ExchangeSettingsDocumentUploadFailure()),
    };
  }
}
