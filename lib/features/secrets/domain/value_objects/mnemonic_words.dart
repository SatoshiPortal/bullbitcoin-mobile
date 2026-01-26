import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:meta/meta.dart';

@immutable
class MnemonicWords {
  final List<String> value;

  const MnemonicWords._(this.value);

  /// Creates a MnemonicWords instance with validation.
  ///
  /// Throws [InvalidMnemonicWordCountError] if the word count is not 12, 15, 18, 21, or 24.
  factory MnemonicWords(List<String> words) {
    if (words.isEmpty) {
      throw InvalidMnemonicWordCountError(
        'Mnemonic words cannot be empty',
        actualCount: words.length,
      );
    }

    const validCounts = [12, 15, 18, 21, 24];
    if (!validCounts.contains(words.length)) {
      throw InvalidMnemonicWordCountError(
        'Mnemonic must have 12, 15, 18, 21, or 24 words. Got ${words.length} words.',
        actualCount: words.length,
      );
    }

    return MnemonicWords._(List.unmodifiable(words));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MnemonicWords &&
          runtimeType == other.runtimeType &&
          _listEquals(value, other.value);

  @override
  int get hashCode => Object.hashAll(value);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
