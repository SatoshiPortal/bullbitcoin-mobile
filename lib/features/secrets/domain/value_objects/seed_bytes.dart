import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:meta/meta.dart';

@immutable
class SeedBytes {
  final List<int> value;

  const SeedBytes._(this.value);

  /// Creates a SeedBytes instance with validation.
  ///
  /// Throws [InvalidSeedBytesLengthError] if the byte length is not 16, 32, or 64.
  factory SeedBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw InvalidSeedBytesLengthError(
        'Seed bytes cannot be empty',
        actualLength: bytes.length,
      );
    }

    if (bytes.length != 16 && bytes.length != 32 && bytes.length != 64) {
      throw InvalidSeedBytesLengthError(
        'Seed bytes must be 16, 32, or 64 bytes (128, 256, or 512 bits). Got ${bytes.length} bytes.',
        actualLength: bytes.length,
      );
    }

    return SeedBytes._(List.unmodifiable(bytes));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeedBytes &&
          runtimeType == other.runtimeType &&
          _listEquals(value, other.value);

  @override
  int get hashCode => Object.hashAll(value);

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
