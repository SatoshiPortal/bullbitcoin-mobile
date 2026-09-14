import 'package:bb_mobile/features/exchange_settings/domain/document_picker_port.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// `file_picker`-backed [DocumentPickerPort].
///
/// This is the one `try/catch` boundary for choosing a document: the platform
/// channel is awaited here, so a rejected or crashing picker becomes a
/// `Result` rather than an exception reaching the cubit.
class FilePickerDocumentAdapter implements DocumentPickerPort {
  const FilePickerDocumentAdapter();

  @override
  @useResult
  Future<Result<PickedDocument?, ExchangeSettingsFailure>> pick({
    required List<String> allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        // Dismissed without choosing.
        return const Ok(null);
      }

      final file = result.files.first;

      return Ok(
        PickedDocument(
          name: file.name,
          extension: file.extension?.toLowerCase(),
          sizeBytes: file.size,
          bytes: file.bytes,
        ),
      );
    } catch (e, st) {
      // The picker itself failed, so no file was ever chosen — "that file
      // could not be read" would be misleading. This is the catch-all case.
      log.severe(message: 'Document picker failed', error: e, trace: st);
      return Err(
        ExchangeSettingsUnexpectedFailure('pickFiles failed: ${e.runtimeType}'),
      );
    }
  }
}
