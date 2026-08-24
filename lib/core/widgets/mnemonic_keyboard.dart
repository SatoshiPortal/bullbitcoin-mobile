import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

/// Letters-only keyboard for mnemonic entry.
///
/// It exists to keep the recovery phrase off the platform IME: on the seed
/// entry screen the word fields are read-only, and this widget is the only
/// path from a tap to a character. A third-party keyboard, the OS
/// autocorrect cache, and any accessibility keylogger therefore never see a
/// keystroke of the seed.
///
/// Deliberately dumb: it knows nothing about BIP39. It renders the 26 letters
/// of [layout] in three rows, enables a key only when its letter is in
/// [enabledLetters], and reports taps through [onLetter] / [onBackspace]. All
/// the wordlist intelligence — which letters keep a word possible, auto fill,
/// focus advance — stays with the owner that computes [enabledLetters].
///
/// [layout] is just the display order: pass [qwerty] for a familiar keyboard,
/// or a shuffled alphabet for the paranoid mode, where randomised key
/// positions defeat shoulder-surfing and tap-position inference.
class MnemonicKeyboard extends StatelessWidget {
  /// A familiar QWERTY order, split 10 / 9 / 7 across the three rows.
  static const List<String> qwerty = [
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', //
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', //
    'z', 'x', 'c', 'v', 'b', 'n', 'm', //
  ];

  /// The 26 lowercase letters in display order. Split 10 / 9 / 7 into rows.
  final List<String> layout;

  /// The lowercase letters a tap may currently produce. A key outside this set
  /// is shown disabled: the owner has determined it cannot extend the word.
  final Set<String> enabledLetters;

  /// Whether the backspace key is active — false only when the focused field
  /// is already empty, so there is nothing to delete.
  final bool canBackspace;

  /// Whether the enter key is active. False on a half-typed prefix — only the
  /// owner knows whether the word has resolved.
  final bool canAdvance;

  final void Function(String letter) onLetter;
  final VoidCallback onBackspace;

  /// Moves to the next field. Never completes or chooses a word.
  final VoidCallback onEnter;

  /// Paranoid mode toggle, shown as a key next to backspace.
  final bool shuffleActive;
  final VoidCallback onToggleShuffle;

  /// Tooltip for the shuffle key. Passed in so this widget stays free of
  /// localization.
  final String shuffleHint;

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
  }) : assert(
         layout.length == 26,
         'The keyboard lays out exactly 26 keys in three rows (10/9/7); '
         'any other length throws a RangeError at build time.',
       );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LetterRow(
                letters: layout.sublist(0, 10),
                enabledLetters: enabledLetters,
                onLetter: onLetter,
                paranoid: shuffleActive,
              ),
              _LetterRow(
                letters: layout.sublist(10, 19),
                enabledLetters: enabledLetters,
                onLetter: onLetter,
                paranoid: shuffleActive,
                trailing: _BackspaceKey(
                  enabled: canBackspace,
                  onTap: onBackspace,
                ),
              ),
              _LetterRow(
                letters: layout.sublist(19, 26),
                enabledLetters: enabledLetters,
                onLetter: onLetter,
                paranoid: shuffleActive,
                trailingKeys: 2,
                // The shuffle toggle shares its slot with enter
                trailing: Row(
                  children: [
                    Expanded(
                      child: _ShuffleKey(
                        active: shuffleActive,
                        hint: shuffleHint,
                        onTap: onToggleShuffle,
                      ),
                    ),
                    Expanded(
                      child: _EnterKey(enabled: canAdvance, onTap: onEnter),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  final List<String> letters;
  final Set<String> enabledLetters;
  final void Function(String letter) onLetter;
  final bool paranoid;
  final Widget? trailing;

  /// How many keys [trailing] lays out, used to size its slot.
  final int trailingKeys;

  const _LetterRow({
    required this.letters,
    required this.enabledLetters,
    required this.onLetter,
    required this.paranoid,
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
              child: _LetterKey(
                letter: letter,
                enabled: enabledLetters.contains(letter),
                paranoid: paranoid,
                onTap: () => onLetter(letter),
              ),
            ),
          // One unit per key, so trailing keys stay a letter wide.
          if (trailing != null) Expanded(flex: trailingKeys, child: trailing!),
        ],
      ),
    );
  }
}

class _LetterKey extends StatelessWidget {
  final String letter;
  final bool enabled;
  final bool paranoid;
  final VoidCallback onTap;

  const _LetterKey({
    required this.letter,
    required this.enabled,
    required this.paranoid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ExcludeSemantics: the key's letter must not reach the accessibility tree,
    // where a malicious accessibility service would read the seed letter by
    // letter as it is typed. This makes the keyboard unusable with a screen
    // reader by design — the recovery phrase is too sensitive to narrate.
    return ExcludeSemantics(
      child: _KeyCap(
        enabled: enabled,
        onTap: onTap,
        suppressAnimation: paranoid,
        child: BBText(
          letter,
          style: context.font.headlineLarge,
          color: enabled
              ? context.appColors.onSurface
              : context.appColors.textMuted,
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BackspaceKey({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _KeyCap(
      enabled: enabled,
      onTap: onTap,
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

/// Moves to the next field, and nothing else.
///
/// It must never accept a suggestion: the chips are shuffled in paranoid mode,
/// so the first one is arbitrary, and no shortcut is worth writing a word the
/// user did not choose into a recovery phrase.
class _EnterKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _EnterKey({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _KeyCap(
      key: const Key('mnemonicEnterKey'),
      enabled: enabled,
      onTap: onTap,
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

/// Toggles the paranoid, randomised-layout mode. Accent-coloured while active.
class _ShuffleKey extends StatelessWidget {
  final bool active;
  final String hint;
  final VoidCallback onTap;

  const _ShuffleKey({
    required this.active,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: _KeyCap(
        key: const Key('mnemonicParanoidToggle'),
        enabled: true,
        onTap: onTap,
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

/// The shared key shell: sizing, colour, and tap surface. A disabled key has
/// no tap handler at all, so it cannot fire even through automation.
class _KeyCap extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  /// When true, the key changes appearance as an instant cut with no ink
  /// splash. Used while the layout is reshuffling on every tap: an animated
  /// colour fade or a splash that outlives the reshuffle would mark, for a
  /// frame, which slot was just pressed — letting an observer follow a letter
  /// across the shuffle and defeating it.
  final bool suppressAnimation;

  const _KeyCap({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.child,
    this.suppressAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        // Zero duration: even in basic mode an enable/disable colour tween is
        // an extra frame of state history for a camera; there is no reason to
        // animate a key cap.
        animationDuration: Duration.zero,
        color: enabled
            ? context.appColors.surface
            : context.appColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          // A key must never take focus from the word field being typed into.
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(6),
          splashFactory: suppressAnimation ? NoSplash.splashFactory : null,
          highlightColor: suppressAnimation ? Colors.transparent : null,
          onTap: enabled ? onTap : null,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
