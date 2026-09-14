import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// A document the user chose from their device.
class PickedDocument {
  final String name;
  final String? extension;
  final int sizeBytes;
  final List<int>? bytes;

  const PickedDocument({
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.bytes,
  });
}

/// Chooses a document from the device. The implementation owns the platform
/// call and is the `try/catch` boundary for it.
abstract interface class DocumentPickerPort {
  /// Returns `Ok(null)` when the user dismissed the picker without choosing —
  /// a cancellation is not a failure.
  @useResult
  Future<Result<PickedDocument?, ExchangeSettingsFailure>> pick({
    required List<String> allowedExtensions,
  });
}
