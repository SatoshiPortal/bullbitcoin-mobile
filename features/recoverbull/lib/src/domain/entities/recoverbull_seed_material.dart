import 'package:meta/meta.dart';

/// Secret-bearing seed material. Never log or otherwise expose its contents.
@immutable
final class RecoverBullSeedMaterial {
  final List<int> bytes;
  final List<String> mnemonicWords;

  RecoverBullSeedMaterial({
    required List<int> bytes,
    required List<String> mnemonicWords,
  }) : bytes = List.unmodifiable(bytes),
       mnemonicWords = List.unmodifiable(mnemonicWords);
}
