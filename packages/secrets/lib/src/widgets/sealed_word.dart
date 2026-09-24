import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// One word of a mnemonic, as a widget the host can place but not read.
///
/// What `MnemonicView.wordBuilder` and `MnemonicTile.word` hand out. The string is a private field with no accessor, so a host that wants the word has to walk its own element tree for the inner `Text` — a deliberate act that reads as one in review, rather than a parameter it was given. Not exported: this type is the seal, not part of the surface.
final class SealedWord extends StatelessWidget {
  final String _word;
  final TextStyle? _style;

  @internal
  const SealedWord(this._word, {this._style, super.key});

  @override
  Widget build(BuildContext context) => Text(_word, style: _style);
}
