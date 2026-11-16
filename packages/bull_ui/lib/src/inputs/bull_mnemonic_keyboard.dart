import 'dart:math' as math;

import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Letters-only keyboard for mnemonic entry.
///
/// It exists to keep the recovery phrase off the platform IME: on the seed
/// entry screen the word fields are read-only, and this widget is the only
/// path from a tap to a character. A third-party keyboard, the OS
/// autocorrect cache, and any accessibility keylogger therefore never see a
/// keystroke of the seed.
///
/// Deliberately dumb: it knows nothing about BIP39. It renders English in three
/// rows and other scripts in a scrollable grid, enabling a key only when it is in
/// [enabledLetters], and reports taps through [onLetter] / [onBackspace]. All
/// the wordlist intelligence — which letters keep a word possible, auto fill,
/// focus advance — stays with the owner that computes [enabledLetters].
///
/// [layout] is just the display order: pass [qwerty] for a familiar keyboard,
/// or a shuffled alphabet for the paranoid mode, where randomised key
/// positions defeat shoulder-surfing and tap-position inference.
class BullMnemonicKeyboard extends StatelessWidget {
  /// A familiar QWERTY order, split 10 / 9 / 7 across the three rows.
  static const List<String> qwerty = [
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', //
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', //
    'z', 'x', 'c', 'v', 'b', 'n', 'm', //
  ];

  /// What a key shows for [value]; the key still inserts [value] itself.
  ///
  /// Wordlists are compared in NFKD, so some keys carry a character that
  /// cannot stand alone: a combining mark (Spanish and French accents,
  /// Japanese voicing marks) or a conjoining Korean jamo. A combining mark is
  /// drawn on a dotted circle, a jamo as its standalone compatibility form,
  /// and a final consonant on a dotted circle too, so it never looks like the
  /// initial consonant offered next to it.
  static String keyLabel(String value) {
    final runes = value.runes.toList();
    if (runes.length != 1) return value;
    final code = runes.single;
    if ((code >= 0x0300 && code <= 0x036F) ||
        code == 0x3099 ||
        code == 0x309A) {
      return '$_dottedCircle$value';
    }
    if (code >= 0x1100 && code <= 0x1112) {
      return String.fromCharCode(_initialJamo[code - 0x1100]);
    }
    if (code >= 0x1161 && code <= 0x1175) {
      return String.fromCharCode(0x314F + code - 0x1161);
    }
    if (code >= 0x11A8 && code <= 0x11C2) {
      return '$_dottedCircle${String.fromCharCode(_finalJamo[code - 0x11A8])}';
    }
    return value;
  }

  static const _dottedCircle = '\u25CC';

  /// Hangul compatibility jamo for the initial consonants U+1100 to U+1112.
  static const _initialJamo = [
    0x3131, 0x3132, 0x3134, 0x3137, 0x3138, 0x3139, 0x3141, 0x3142, 0x3143, //
    0x3145, 0x3146, 0x3147, 0x3148, 0x3149, 0x314A, 0x314B, 0x314C, 0x314D, //
    0x314E,
  ];

  /// Hangul compatibility jamo for the final consonants U+11A8 to U+11C2.
  static const _finalJamo = [
    0x3131, 0x3132, 0x3133, 0x3134, 0x3135, 0x3136, 0x3137, 0x3139, 0x313A, //
    0x313B, 0x313C, 0x313D, 0x313E, 0x313F, 0x3140, 0x3141, 0x3142, 0x3144, //
    0x3145, 0x3146, 0x3147, 0x3148, 0x314A, 0x314B, 0x314C, 0x314D, 0x314E,
  ];

  /// Characters in display order. English is split 10 / 9 / 7 into rows.
  final List<String> layout;

  /// Other scripts use a bounded grid instead of the English three rows.
  final bool scrollable;

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

  const BullMnemonicKeyboard({
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
    this.scrollable = false,
  }) : assert(
         scrollable || layout.length == 26,
         'The keyboard lays out exactly 26 keys in three rows (10/9/7); '
         'any other length throws a RangeError at build time.',
       );

  /// Keys follow the QWERTY grid: ten across, three rows. The rows fill a
  /// quarter of the screen height, so with the suggestion bar the panel takes
  /// about a third of it, like the system keyboard; floors and caps keep keys
  /// usable in landscape and sane in a desktop window.
  static const grid = BullKeypadGrid(
    columns: 10,
    rows: 3,
    aspectRatio: 3,
    minKeyHeight: 40,
    maxKeyHeight: 80,
    maxKeyWidth: 72,
    gap: 4,
    screenShare: 0.25,
    maxGlyphSize: 30,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.bull.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = grid.resolve(
                constraints,
                MediaQuery.sizeOf(context),
              );
              return Center(
                child: SizedBox(
                  width: metrics.width,
                  child: scrollable ? _buildGrid(metrics) : _buildRows(metrics),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BullKeypadMetrics metrics) {
    final keyExtent = math.max(metrics.keyWidth, metrics.keyHeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ExcludeSemantics: a scrollable grid publishes its child count and
        // extent, and the number of keys left after a prefix narrows down the
        // word being typed. Its height is fixed for the same reason.
        ExcludeSemantics(
          child: SizedBox(
            height:
                metrics.keyHeight * grid.rows + metrics.gap * (grid.rows - 1),
            child: GridView.builder(
              key: ValueKey(Object.hashAll(layout)),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: keyExtent + metrics.gap,
                mainAxisExtent: metrics.keyHeight,
                crossAxisSpacing: metrics.gap,
                mainAxisSpacing: metrics.gap,
              ),
              itemCount: layout.length,
              itemBuilder: (context, index) => _LetterKey(
                letter: layout[index],
                enabled: enabledLetters.contains(layout[index]),
                paranoid: shuffleActive,
                metrics: metrics,
                onTap: () => onLetter(layout[index]),
              ),
            ),
          ),
        ),
        _KeyRow(
          gap: metrics.gap,
          keys: [
            (
              1,
              _BackspaceKey(
                enabled: canBackspace,
                metrics: metrics,
                onTap: onBackspace,
              ),
            ),
            (
              1,
              _ShuffleKey(
                active: shuffleActive,
                hint: shuffleHint,
                metrics: metrics,
                onTap: onToggleShuffle,
              ),
            ),
            (
              1,
              _EnterKey(enabled: canAdvance, metrics: metrics, onTap: onEnter),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRows(BullKeypadMetrics metrics) {
    List<(int, Widget)> letters(int start, int end) => [
      for (final letter in layout.sublist(start, end))
        (
          1,
          _LetterKey(
            letter: letter,
            enabled: enabledLetters.contains(letter),
            paranoid: shuffleActive,
            metrics: metrics,
            onTap: () => onLetter(letter),
          ),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyRow(gap: metrics.gap, keys: letters(0, 10)),
        _KeyRow(
          gap: metrics.gap,
          keys: [
            ...letters(10, 19),
            (
              1,
              _BackspaceKey(
                enabled: canBackspace,
                metrics: metrics,
                onTap: onBackspace,
              ),
            ),
          ],
        ),
        _KeyRow(
          gap: metrics.gap,
          keys: [
            ...letters(19, 26),
            // The shuffle toggle shares the last two slots with enter.
            (
              1,
              _ShuffleKey(
                active: shuffleActive,
                hint: shuffleHint,
                metrics: metrics,
                onTap: onToggleShuffle,
              ),
            ),
            (
              1,
              _EnterKey(enabled: canAdvance, metrics: metrics, onTap: onEnter),
            ),
          ],
        ),
      ],
    );
  }
}

/// One row of keys, each taking its flex share of the width, with a gap
/// between keys and below the row.
class _KeyRow extends StatelessWidget {
  final double gap;
  final List<(int, Widget)> keys;

  const _KeyRow({required this.gap, required this.keys});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Row(
        children: [
          for (final (index, (flex, key)) in keys.indexed) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(flex: flex, child: key),
          ],
        ],
      ),
    );
  }
}

class _LetterKey extends StatelessWidget {
  final String letter;
  final bool enabled;
  final bool paranoid;
  final BullKeypadMetrics metrics;
  final VoidCallback onTap;

  const _LetterKey({
    required this.letter,
    required this.enabled,
    required this.paranoid,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ExcludeSemantics: the key's letter must not reach the accessibility tree,
    // where a malicious accessibility service would read the seed letter by
    // letter as it is typed. This makes the keyboard unusable with a screen
    // reader by design — the recovery phrase is too sensitive to narrate.
    return ExcludeSemantics(
      child: BullKeyCap(
        enabled: enabled,
        onTap: onTap,
        height: metrics.keyHeight,
        suppressAnimation: paranoid,
        child: BullText(
          BullMnemonicKeyboard.keyLabel(letter),
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontSize: metrics.glyphSize),
          color: enabled ? context.bull.onSurface : context.bull.textMuted,
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final bool enabled;
  final BullKeypadMetrics metrics;
  final VoidCallback onTap;

  const _BackspaceKey({
    required this.enabled,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BullKeyCap(
      enabled: enabled,
      onTap: onTap,
      height: metrics.keyHeight,
      child: Icon(
        Icons.backspace_outlined,
        size: metrics.glyphSize,
        color: enabled ? context.bull.onSurface : context.bull.textMuted,
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
  final BullKeypadMetrics metrics;
  final VoidCallback onTap;

  const _EnterKey({
    required this.enabled,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BullKeyCap(
      key: const Key('mnemonicEnterKey'),
      enabled: enabled,
      onTap: onTap,
      height: metrics.keyHeight,
      child: Icon(
        Icons.keyboard_return,
        size: metrics.glyphSize,
        color: enabled ? context.bull.onSurface : context.bull.textMuted,
      ),
    );
  }
}

/// Toggles the paranoid, randomised-layout mode. Accent-coloured while active.
class _ShuffleKey extends StatelessWidget {
  final bool active;
  final String hint;
  final BullKeypadMetrics metrics;
  final VoidCallback onTap;

  const _ShuffleKey({
    required this.active,
    required this.hint,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: BullKeyCap(
        key: const Key('mnemonicParanoidToggle'),
        enabled: true,
        onTap: onTap,
        height: metrics.keyHeight,
        child: Icon(
          Icons.shuffle,
          size: metrics.glyphSize,
          color: active ? context.bull.primary : context.bull.onSurface,
        ),
      ),
    );
  }
}
