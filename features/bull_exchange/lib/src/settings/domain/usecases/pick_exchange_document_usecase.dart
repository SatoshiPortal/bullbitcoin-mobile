import 'package:exchange/exchange.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:file_system/file_system.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/exchange_document_to_upload.dart';
import '../entities/file_upload.dart';

/// Lets the user pick a document and checks it against the exchange's
/// limits, named as the exchange expects for a secure upload.
class PickExchangeDocumentUsecase {
  final FileSystem _fileSystem;

  const PickExchangeDocumentUsecase({required this._fileSystem});

  /// `null` means the picker was dismissed: nothing is wrong.
  @useResult
  Future<Result<ExchangeDocumentToUpload?, ExchangeFailure>> execute({
    String? userId,
  }) async {
    final picked = await _fileSystem.pick(
      allowedExtensions: FileToUpload.allowedExtensions,
    );

    final PickedDocument? document;
    switch (picked) {
      case Err(:final failure):
        log.warning('Document picker failed', error: failure.logMessage);
        return Err(
          ExchangeUnexpectedFailure('pickFiles failed: ${failure.logMessage}'),
        );
      case Ok(:final value):
        document = value;
    }

    if (document == null) {
      return const Ok(null);
    }

    final List<int> bytes;
    switch (await _fileSystem.read(
      document,
      maxBytes: FileToUpload.maxFileSizeBytes,
    )) {
      case Err(:final failure):
        if (failure is FileSystemTooLargeFailure) {
          return const Err(ExchangeDocumentTooLargeFailure());
        }
        log.warning(
          'Selected document could not be read',
          error: failure.logMessage,
        );
        return const Err(ExchangeDocumentUnreadableFailure());
      case Ok(:final value):
        bytes = value;
    }
    if (bytes.isEmpty) {
      return const Err(ExchangeDocumentEmptyFailure());
    }
    final extension = document.extension?.toLowerCase() ?? '';
    if (!FileToUpload.allowedExtensions.contains(extension)) {
      return const Err(ExchangeDocumentTypeNotAllowedFailure());
    }

    // Mirrors the filename BB-Exchange expects for a secure upload.
    final fileName = userId != null ? 'doc-$userId-ID' : document.name;
    return Ok(ExchangeDocumentToUpload(bytes: bytes, fileName: fileName));
  }
}
