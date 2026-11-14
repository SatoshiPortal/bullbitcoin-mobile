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
  final FilePickerPlatform? _filePicker;

  const FilePickerDocumentAdapter({this._filePicker});

  @override
  @useResult
  Future<Result<PickedDocument?, ExchangeSettingsFailure>> pick({
    required List<String> allowedExtensions,
  }) async {
    try {
      final result = await (_filePicker ?? FilePickerPlatform.instance)
          .pickFile(
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
          );

      if (result == null) {
        // Dismissed without choosing.
        return const Ok(null);
      }

      final file = result;

      final List<int> bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e, st) {
        log.severe(
          message: 'Selected document could not be read',
          error: e,
          trace: st,
        );
        return const Err(ExchangeSettingsDocumentUnreadableFailure());
      }
      return Ok(
        PickedDocument(
          name: file.name,
          extension: file.extension?.toLowerCase(),
          sizeBytes: bytes.length,
          bytes: bytes,
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
