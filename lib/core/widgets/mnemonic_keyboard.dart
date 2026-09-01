import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/in_app_keyboard_key.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class MnemonicKeyboard extends StatefulWidget {
  static const List<String> qwerty = [
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
    'z',
    'x',
    'c',
    'v',
    'b',
    'n',
    'm',
  ];

  final List<String> layout;
  final Set<String> enabledLetters;
  final bool canBackspace;
  final bool canAdvance;
  final void Function(String letter) onLetter;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final bool shuffleActive;
  final VoidCallback onToggleShuffle;
  final String shuffleHint;
  final bool allowAllPrintableAscii;
  final String lettersLabel;
  final String symbolsLabel;
  final String spaceLabel;

  const MnemonicKeyboard({
    super.key,
    required this.enabledLetters,
    required this.canBackspace,
    required this.canAdvance,
    required this.onLetter,
    required this.onBackspace,
    required this.onEnter,
    required this.shuffleActive,
    required this.onToggleShuffle,
    required this.shuffleHint,
    this.layout = qwerty,
    this.allowAllPrintableAscii = false,
    this.lettersLabel = 'ABC',
    this.symbolsLabel = '#+=',
    this.spaceLabel = 'Space',
  }) : assert(layout.length == 26);

  @override
  State<MnemonicKeyboard> createState() => _MnemonicKeyboardState();
}

class _MnemonicKeyboardState extends State<MnemonicKeyboard> {
  static const _symbolRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['!', '@', '#', r'$', '%', '^', '&', '*', '(', ')'],
    ['-', '_', '=', '+', '[', ']', '{', '}', r'\', '|'],
    [';', ':', "'", '"', ',', '<', '.', '>', '/', '?', '`', '~'],
  ];

  var _upperCase = false;
  var _showSymbols = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: widget.allowAllPrintableAscii
              ? _buildAsciiKeyboard(context)
              : _buildMnemonicKeyboard(),
        ),
      ),
    );
  }

  Widget _buildMnemonicKeyboard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LetterRow(
          letters: widget.layout.sublist(0, 10),
          enabledLetters: widget.enabledLetters,
          onLetter: widget.onLetter,
          suppressAnimation: widget.shuffleActive,
        ),
        _LetterRow(
          letters: widget.layout.sublist(10, 19),
          enabledLetters: widget.enabledLetters,
          onLetter: widget.onLetter,
          suppressAnimation: widget.shuffleActive,
          trailing: _BackspaceKey(
            enabled: widget.canBackspace,
            onPressed: widget.onBackspace,
          ),
        ),
        _LetterRow(
          letters: widget.layout.sublist(19, 26),
          enabledLetters: widget.enabledLetters,
          onLetter: widget.onLetter,
          suppressAnimation: widget.shuffleActive,
          trailingKeys: 2,
          trailing: Row(
            children: [
              Expanded(
                child: _ShuffleKey(
                  active: widget.shuffleActive,
                  hint: widget.shuffleHint,
                  onPressed: widget.onToggleShuffle,
                ),
              ),
              Expanded(
                child: _EnterKey(
                  enabled: widget.canAdvance,
                  onPressed: widget.onEnter,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAsciiKeyboard(BuildContext context) {
    final rows = _showSymbols
        ? _symbolRows
        : [
            for (final row in [
              widget.layout.sublist(0, 10),
              widget.layout.sublist(10, 19),
              widget.layout.sublist(19, 26),
            ])
              _upperCase
                  ? row.map((character) => character.toUpperCase()).toList()
                  : row,
          ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          _LetterRow(
            letters: row,
            enabledLetters: widget.enabledLetters,
            onLetter: widget.onLetter,
            suppressAnimation: false,
          ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: InAppKeyboardKey(
                onPressed: () => setState(() {
                  _showSymbols = false;
                  _upperCase = !_upperCase;
                }),
                child: BBText(
                  _upperCase
                      ? widget.lettersLabel.toLowerCase()
                      : widget.lettersLabel,
                  style: context.font.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: InAppKeyboardKey(
                onPressed: () => setState(() => _showSymbols = !_showSymbols),
                child: BBText(
                  _showSymbols ? widget.lettersLabel : widget.symbolsLabel,
                  style: context.font.bodyMedium,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: InAppKeyboardKey(
                onPressed: widget.enabledLetters.contains(' ')
                    ? () => widget.onLetter(' ')
                    : null,
                child: BBText(
                  widget.spaceLabel,
                  style: context.font.bodyMedium,
                ),
              ),
            ),
            Expanded(
              child: _BackspaceKey(
                enabled: widget.canBackspace,
                onPressed: widget.onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LetterRow extends StatelessWidget {
  final List<String> letters;
  final Set<String> enabledLetters;
  final void Function(String letter) onLetter;
  final bool suppressAnimation;
  final Widget? trailing;
  final int trailingKeys;

  const _LetterRow({
    required this.letters,
    required this.enabledLetters,
    required this.onLetter,
    required this.suppressAnimation,
    this.trailing,
    this.trailingKeys = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          for (final letter in letters)
            Expanded(
              child: ExcludeSemantics(
                child: InAppKeyboardKey(
                  onPressed: enabledLetters.contains(letter)
                      ? () => onLetter(letter)
                      : null,
                  suppressAnimation: suppressAnimation,
                  child: BBText(
                    letter,
                    style: context.font.headlineLarge,
                    color: enabledLetters.contains(letter)
                        ? context.appColors.onSurface
                        : context.appColors.textMuted,
                  ),
                ),
              ),
            ),
          if (trailing != null) Expanded(flex: trailingKeys, child: trailing!),
        ],
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BackspaceKey({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InAppKeyboardKey(
      onPressed: enabled ? onPressed : null,
      child: Icon(
        Icons.backspace_outlined,
        size: 20,
        color: enabled
            ? context.appColors.onSurface
            : context.appColors.textMuted,
      ),
    );
  }
}

class _EnterKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _EnterKey({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InAppKeyboardKey(
      key: const Key('mnemonicEnterKey'),
      onPressed: enabled ? onPressed : null,
      child: Icon(
        Icons.keyboard_return,
        size: 20,
        color: enabled
            ? context.appColors.onSurface
            : context.appColors.textMuted,
      ),
    );
  }
}

class _ShuffleKey extends StatelessWidget {
  final bool active;
  final String hint;
  final VoidCallback onPressed;

  const _ShuffleKey({
    required this.active,
    required this.hint,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: InAppKeyboardKey(
        key: const Key('mnemonicParanoidToggle'),
        onPressed: onPressed,
        child: Icon(
          Icons.shuffle,
          size: 20,
          color: active
              ? context.appColors.primary
              : context.appColors.onSurface,
        ),
      ),
    );
  }
}
