import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/mnemonic_keyboard.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class PassphraseInput extends StatefulWidget {
  final String showLabel;
  final String hideLabel;
  final String lettersLabel;
  final String symbolsLabel;
  final String spaceLabel;

  const PassphraseInput({
    super.key,
    required this.showLabel,
    required this.hideLabel,
    required this.lettersLabel,
    required this.symbolsLabel,
    required this.spaceLabel,
  });

  @override
  State<PassphraseInput> createState() => PassphraseInputState();
}

class PassphraseInputState extends State<PassphraseInput> {
  static final _printableAscii = {
    for (var codeUnit = 0x20; codeUnit <= 0x7e; codeUnit++)
      String.fromCharCode(codeUnit),
  };

  final List<int> _value = [];
  var _obscured = false;

  String takeValue() {
    final result = String.fromCharCodes(_value);
    clear();
    return result;
  }

  void clear() {
    if (mounted) {
      setState(_clearValue);
    } else {
      _clearValue();
    }
  }

  void _clearValue() {
    _value.fillRange(0, _value.length, 0);
    _value.clear();
  }

  @override
  void dispose() {
    _clearValue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: context.appColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: BBText(
                    _obscured
                        ? '•' * _value.length
                        : String.fromCharCodes(_value),
                    style: context.font.bodyLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: _obscured ? widget.showLabel : widget.hideLabel,
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        MnemonicKeyboard(
          allowAllPrintableAscii: true,
          enabledLetters: _printableAscii,
          canBackspace: _value.isNotEmpty,
          canAdvance: false,
          onLetter: _append,
          onBackspace: () => setState(_value.removeLast),
          onEnter: () {},
          shuffleActive: false,
          onToggleShuffle: () {},
          shuffleHint: '',
          lettersLabel: widget.lettersLabel,
          symbolsLabel: widget.symbolsLabel,
          spaceLabel: widget.spaceLabel,
        ),
      ],
    );
  }

  void _append(String character) {
    setState(() => _value.add(character.codeUnitAt(0)));
  }
}
