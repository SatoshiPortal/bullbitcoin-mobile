import 'dart:math' as math;

import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:bull_ui/src/theme/bull_keypad_colors.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A wordlist the language key offers: a short [code] drawn on the key and
/// the [name] listed in its popup.
@immutable
class BullKeyboardLanguage {
  final String code;
  final String name;

  const BullKeyboardLanguage({required this.code, required this.name});
}

/// Letters-only keyboard for mnemonic entry.
///
/// It exists to keep the recovery phrase off the platform IME: on the seed
/// entry screen the word fields are read-only, and this widget is the only
/// path from a tap to a character. A third-party keyboard, the OS
/// autocorrect cache, and any accessibility keylogger therefore never see a
/// keystroke of the seed.
///
/// Deliberately dumb: it knows nothing about BIP39. The owner passes the keys
/// ([layout] split into [rows], or a [scrollable] grid for other scripts),
/// which of them may extend the word ([enabledLetters]), the accented letters
/// of a second page ([accents]) and of a long press ([variants]), and the
/// [suggestions]. Taps come back through [onLetter], [onBackspace], [onEnter],
/// [onSuggestion] and [onLanguage]. A key emits its value unchanged, so the
/// owner passes values in the form its matcher compares.
///
/// The panel, suggestions and bottom safe area included, takes
/// [screenShare] of the screen or window height, and the keys fill it; a
/// floor keeps them usable in a short landscape window, and a width cap
/// centres them in a wide one.
///
/// [layout] is just the display order: the owner passes a national layout,
/// or the same keys shuffled for the scramble mode, where randomised key
/// positions defeat shoulder-surfing and tap-position inference.
class BullMnemonicKeyboard extends StatefulWidget {
  /// A familiar QWERTY order, split 10 / 9 / 7 across the three rows.
  static const List<String> qwerty = [
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', //
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', //
    'z', 'x', 'c', 'v', 'b', 'n', 'm', //
  ];

  /// Share of the screen or window height the whole panel takes.
  static const double screenShare = 0.35;

  /// Height of the suggestion strip above the keys.
  static const double suggestionHeight = 42;

  /// Space between two rows of keys.
  static const double rowGap = 6;

  /// Space between two keys of a row.
  static const double keyGap = 4;

  /// Margin on each side of the keys.
  static const double sidePadding = 3;

  /// Margin under the keys where the system leaves no inset.
  static const double minBottomPadding = 8;

  /// A key stays a usable tap target in a short landscape window.
  static const double minKeyHeight = 30;

  /// A wide window centres the keys instead of stretching them.
  static const double maxKeyWidth = 72;

  /// Key widths across a row: ten letters.
  static const int columns = 10;

  /// Three rows of letters and the bottom row.
  static const int keyRows = 4;

  /// Columns of the grid used by [scrollable] keyboards.
  static const int gridColumns = 8;

  /// What a key shows for [value]; the key still inserts [value] itself.
  ///
  /// Wordlists are compared in NFKD, so some keys carry a character that
  /// cannot stand alone: a combining mark (Japanese voicing marks) or a
  /// conjoining Korean jamo. A combining mark is drawn on a dotted circle, a
  /// jamo as its standalone compatibility form, and a final consonant on a
  /// dotted circle too, so it never looks like the initial consonant offered
  /// next to it. A letter with its accent (`e` + U+0301) renders as one glyph
  /// and is shown unchanged.
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

  static const _dottedCircle = '◌';

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

  /// The bottom margin: the system inset, or [minBottomPadding] without one.
  static double bottomPaddingFor(double safeBottom) =>
      math.max(safeBottom, minBottomPadding);

  /// Height of the whole panel on a [screen] whose bottom inset is
  /// [safeBottom]: [screenShare] of it, never below the [minKeyHeight] floor.
  static double panelHeightFor(Size screen, double safeBottom) {
    final floor =
        suggestionHeight +
        keyRows * minKeyHeight +
        (keyRows - 1) * rowGap +
        bottomPaddingFor(safeBottom);
    return math.max(screen.height * screenShare, floor);
  }

  /// Height of one key in a panel of [panelHeight].
  static double keyHeightFor(double panelHeight, double safeBottom) =>
      (panelHeight -
          suggestionHeight -
          (keyRows - 1) * rowGap -
          bottomPaddingFor(safeBottom)) /
      keyRows;

  /// Keys in display order: the letter rows one after the other, or the
  /// grid of a [scrollable] keyboard.
  final List<String> layout;

  /// Key count of each letter row, top to bottom. The last row ends with
  /// backspace, so it holds at most eight keys.
  final List<int> rows;

  /// Other scripts use a scrolling grid of characters instead of letter
  /// rows, with backspace in a column of its own.
  final bool scrollable;

  /// The accented letters of the second page, opened by the page key. Empty:
  /// no page key.
  final List<String> accents;

  /// The accented letters a long press on a base letter offers. The owner
  /// lists only those that can extend the word.
  final Map<String, List<String>> variants;

  /// The keys a tap may currently produce. A key outside this set keeps its
  /// place and fill but shows a muted glyph and ignores taps: the owner has
  /// determined it cannot extend the word.
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

  /// Scramble mode toggle, the key in the middle of the bottom row.
  final bool shuffleActive;
  final VoidCallback onToggleShuffle;

  /// Tooltip for the shuffle key. Passed in so this widget stays free of
  /// localization.
  final String shuffleHint;

  /// Up to three words, best first: the best is drawn in the middle, in bold,
  /// the next two on either side. The owner shuffles them in scramble mode.
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  /// Shown in the strip while there is no suggestion, when not null.
  final String? suggestionNotice;

  /// The wordlists of the language key's popup, and the current one.
  final List<BullKeyboardLanguage> languages;
  final int selectedLanguage;

  /// Called with the index of the chosen language. Null hides the language
  /// key, for an owner that accepts a single wordlist.
  final ValueChanged<int>? onLanguage;

  /// Tooltip of the language key.
  final String languageHint;

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
    this.rows = const [10, 9, 7],
    this.scrollable = false,
    this.accents = const [],
    this.variants = const {},
    this.suggestions = const [],
    this.onSuggestion = _ignoreSuggestion,
    this.suggestionNotice,
    this.languages = const [],
    this.selectedLanguage = 0,
    this.onLanguage,
    this.languageHint = '',
  });

  static void _ignoreSuggestion(String _) {}

  @override
  State<BullMnemonicKeyboard> createState() => _BullMnemonicKeyboardState();
}

/// What the popup above the keys currently shows, anchored to a key whose
/// rectangle is in the overlay's coordinates.
sealed class _Popup {
  final Rect anchor;

  const _Popup(this.anchor);
}

final class _LanguagePopup extends _Popup {
  const _LanguagePopup(super.anchor);
}

final class _VariantPopup extends _Popup {
  final List<String> variants;

  const _VariantPopup(super.anchor, this.variants);
}

class _BullMnemonicKeyboardState extends State<BullMnemonicKeyboard> {
  final _popupController = OverlayPortalController();
  _Popup? _popup;

  /// The long-press popup's highlighted variant, and whether the finger has
  /// slid since it opened: releasing after a slide types the highlighted
  /// variant, releasing in place leaves the popup open for a tap.
  int _selectedVariant = 0;
  bool _dragged = false;

  /// The second page lists the accented letters.
  bool _accentPage = false;

  static const _popupGap = 6.0;
  static const _popupMargin = 8.0;
  static const _popupPadding = 4.0;
  static const _minVariantWidth = 38.0;
  static const _languageRowHeight = 40.0;
  static const _languageWidth = 200.0;

  @override
  void didUpdateWidget(BullMnemonicKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accents.isEmpty) _accentPage = false;
    // A reshuffle or a new wordlist moves the keys: a popup anchored to the
    // old position would point at another key.
    if (!listEquals(oldWidget.layout, widget.layout) ||
        oldWidget.selectedLanguage != widget.selectedLanguage) {
      _popup = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final height = BullMnemonicKeyboard.panelHeightFor(screen, safeBottom);
    final keyHeight = BullMnemonicKeyboard.keyHeightFor(height, safeBottom);
    return OverlayPortal(
      controller: _popupController,
      overlayChildBuilder: _buildPopup,
      child: Material(
        color: context.bullKeypad.panel,
        child: SizedBox(
          height: height,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                BullMnemonicKeyboard.sidePadding,
                0,
                BullMnemonicKeyboard.sidePadding,
                BullMnemonicKeyboard.bottomPaddingFor(safeBottom),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = BullMnemonicKeyboard.columns;
                  const gap = BullMnemonicKeyboard.keyGap;
                  final width = math.min(
                    constraints.maxWidth,
                    columns * BullMnemonicKeyboard.maxKeyWidth +
                        (columns - 1) * gap,
                  );
                  final metrics = BullKeypadMetrics(
                    keyWidth: math.max(
                      0.0,
                      (width - (columns - 1) * gap) / columns,
                    ),
                    keyHeight: keyHeight,
                    gap: gap,
                    width: width,
                  );
                  return Center(
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          SizedBox(
                            height: BullMnemonicKeyboard.suggestionHeight,
                            // ExcludeSemantics: the suggestions are plain-text
                            // word candidates; an accessibility service must
                            // not read them any more than the keys.
                            child: ExcludeSemantics(
                              child: _SuggestionStrip(
                                suggestions: widget.suggestions,
                                notice: widget.suggestionNotice,
                                onTap: widget.onSuggestion,
                              ),
                            ),
                          ),
                          if (widget.scrollable)
                            ..._gridRows(metrics)
                          else
                            ..._letterRows(metrics),
                          const SizedBox(height: BullMnemonicKeyboard.rowGap),
                          _row(metrics, _bottomRow(metrics)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A slot [units] key widths wide, gaps between those keys included.
  static double _slotWidth(BullKeypadMetrics metrics, double units) =>
      units * (metrics.keyWidth + metrics.gap) - metrics.gap;

  /// One row of slots, a null slot being empty space. The last slot takes
  /// what is left, so rounding never overflows the row.
  Widget _row(BullKeypadMetrics metrics, List<(double, Widget?)> slots) {
    final kept = [
      for (final slot in slots)
        if (slot.$1 > 0) slot,
    ];
    return SizedBox(
      height: metrics.keyHeight,
      child: Row(
        children: [
          for (final (index, (units, child)) in kept.indexed) ...[
            if (index > 0) SizedBox(width: metrics.gap),
            if (index == kept.length - 1)
              Expanded(child: child ?? const SizedBox.shrink())
            else
              SizedBox(
                width: _slotWidth(metrics, units),
                child: child ?? const SizedBox.shrink(),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _letterRows(BullKeypadMetrics metrics) {
    const columns = BullMnemonicKeyboard.columns;
    const backspaceUnits = 1.5;
    final rows = <List<String>>[];
    if (_accentPage) {
      // Two rows of accents at most; the third keeps backspace in place.
      final accents = widget.accents;
      for (var start = 0; rows.length < 2; start += columns) {
        rows.add(
          start < accents.length
              ? accents.sublist(
                  start,
                  math.min(start + columns, accents.length),
                )
              : const [],
        );
      }
      rows.add(const []);
    } else {
      var start = 0;
      for (final count in widget.rows) {
        rows.add(widget.layout.sublist(start, start + count));
        start += count;
      }
    }
    return [
      for (final (index, letters) in rows.indexed) ...[
        if (index > 0) const SizedBox(height: BullMnemonicKeyboard.rowGap),
        if (index == rows.length - 1)
          _row(metrics, [
            (columns - letters.length - backspaceUnits, null),
            for (final letter in letters) (1, _letterKey(letter, metrics)),
            (backspaceUnits, _backspaceKey(metrics)),
          ])
        else
          _row(metrics, [
            ((columns - letters.length) / 2, null),
            for (final letter in letters) (1, _letterKey(letter, metrics)),
            ((columns - letters.length) / 2, null),
          ]),
      ],
    ];
  }

  List<Widget> _gridRows(BullKeypadMetrics metrics) {
    const visibleRows = 3;
    const gap = BullMnemonicKeyboard.rowGap;
    final layout = widget.layout;
    return [
      SizedBox(
        height: metrics.keyHeight * visibleRows + gap * (visibleRows - 1),
        child: Row(
          children: [
            // ExcludeSemantics: a scrollable grid publishes its child count
            // and extent, and the number of keys left after a prefix narrows
            // down the word being typed. Its height is fixed for the same
            // reason.
            Expanded(
              child: ExcludeSemantics(
                child: GridView.builder(
                  key: ValueKey(Object.hashAll(layout)),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: BullMnemonicKeyboard.gridColumns,
                    mainAxisExtent: metrics.keyHeight,
                    crossAxisSpacing: metrics.gap,
                    mainAxisSpacing: gap,
                  ),
                  itemCount: layout.length,
                  itemBuilder: (context, index) =>
                      _letterKey(layout[index], metrics),
                ),
              ),
            ),
            SizedBox(width: metrics.gap),
            // Backspace stays in a column of its own, level with the last
            // visible row, however far the grid scrolls.
            SizedBox(
              width: _slotWidth(metrics, 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: metrics.keyHeight,
                    child: _backspaceKey(metrics),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Language, page, scramble in the middle and enter on the right; an
  /// absent key leaves its slot empty so the others never move.
  List<(double, Widget?)> _bottomRow(BullKeypadMetrics metrics) {
    final hasPage = !widget.scrollable && widget.accents.isNotEmpty;
    return [
      (1.5, widget.onLanguage == null ? null : _languageKey(metrics)),
      (1.5, hasPage ? _pageKey(metrics) : null),
      (1.25, null),
      (1.5, _scrambleKey(metrics)),
      (2.75, null),
      (1.5, _enterKey(metrics)),
    ];
  }

  Widget _letterKey(String value, BullKeypadMetrics metrics) {
    final keypad = context.bullKeypad;
    final enabled = widget.enabledLetters.contains(value);
    final variants = _accentPage
        ? const <String>[]
        : widget.variants[value] ?? const <String>[];
    // ExcludeSemantics: the key's letter must not reach the accessibility
    // tree, where a malicious accessibility service would read the seed
    // letter by letter as it is typed. This makes the keyboard unusable with a
    // screen reader by design — the recovery phrase is too sensitive to
    // narrate.
    final key = ExcludeSemantics(
      child: BullKeyCap(
        enabled: enabled,
        onTap: () => _type(value),
        height: metrics.keyHeight,
        suppressAnimation: widget.shuffleActive,
        // A letter that cannot continue the word loses its key: no fill, so
        // it sinks into the panel, and a faint glyph.
        fill: enabled ? keypad.key : context.bull.transparent,
        child: BullKeyGlyph(
          BullMnemonicKeyboard.keyLabel(value),
          size: metrics.glyphSize,
          color: enabled ? keypad.onKey : keypad.disabledGlyph,
        ),
      ),
    );
    if (variants.isEmpty) return key;
    return Builder(
      builder: (keyContext) => GestureDetector(
        // Which keys have variants depends on the prefix typed: a long press
        // action that comes and goes would describe the word.
        excludeFromSemantics: true,
        onLongPressStart: (_) => _openVariants(keyContext, variants),
        onLongPressMoveUpdate: _slideOverVariants,
        onLongPressEnd: (_) => _releaseVariants(),
        child: key,
      ),
    );
  }

  Widget _backspaceKey(BullKeypadMetrics metrics) => _FunctionKey(
    enabled: widget.canBackspace,
    onTap: widget.onBackspace,
    metrics: metrics,
    child: (color) =>
        Icon(Icons.backspace_outlined, size: metrics.glyphSize, color: color),
  );

  /// Moves to the next field, and nothing else.
  ///
  /// It must never accept a suggestion: the suggestions are shuffled in
  /// scramble mode, so the middle one is arbitrary, and no shortcut is worth
  /// writing a word the user did not choose into a recovery phrase.
  Widget _enterKey(BullKeypadMetrics metrics) => _FunctionKey(
    key: const Key('mnemonicEnterKey'),
    enabled: widget.canAdvance,
    onTap: widget.onEnter,
    metrics: metrics,
    child: (color) =>
        Icon(Icons.keyboard_return, size: metrics.glyphSize, color: color),
  );

  /// Toggles the scramble mode. Accent-coloured while active.
  Widget _scrambleKey(BullKeypadMetrics metrics) => Tooltip(
    message: widget.shuffleHint,
    child: _FunctionKey(
      key: const Key('mnemonicParanoidToggle'),
      enabled: true,
      active: widget.shuffleActive,
      onTap: widget.onToggleShuffle,
      metrics: metrics,
      child: (color) =>
          Icon(Icons.shuffle, size: metrics.glyphSize, color: color),
    ),
  );

  /// Opens the accent page, or returns from it. Labelled with what it opens:
  /// the first two accents, or the first letters of the alphabet.
  Widget _pageKey(BullKeypadMetrics metrics) {
    final label = _accentPage
        ? (widget.layout.where((key) => key.length == 1).toList()..sort())
              .take(3)
              .join()
        : widget.accents.take(2).join();
    return _FunctionKey(
      key: const Key('mnemonicPageKey'),
      enabled: true,
      onTap: () => setState(() => _accentPage = !_accentPage),
      metrics: metrics,
      child: (color) => BullKeyGlyph(
        label,
        size: _secondarySize(metrics, 0.75),
        color: color,
      ),
    );
  }

  /// A label smaller than the glyph, [share] of its size, but never below the caption role.
  double _secondarySize(BullKeypadMetrics metrics, double share) => math.max(
    metrics.glyphSize * share,
    context.bullType.caption.fontSize ?? 0,
  );

  Widget _languageKey(BullKeypadMetrics metrics) {
    final languages = widget.languages;
    final index = widget.selectedLanguage;
    final code = index >= 0 && index < languages.length
        ? languages[index].code
        : '';
    return Builder(
      builder: (keyContext) => Tooltip(
        message: widget.languageHint,
        child: _FunctionKey(
          key: const Key('mnemonicLanguageKey'),
          enabled: languages.isNotEmpty,
          active: _popup is _LanguagePopup,
          onTap: () => _toggleLanguages(keyContext),
          metrics: metrics,
          child: (color) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language,
                size: metrics.glyphSize * 0.75,
                color: color,
              ),
              const SizedBox(width: 4),
              BullKeyGlyph(
                code,
                size: _secondarySize(metrics, 0.65),
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Types [value]. A letter of the accent page returns to the letters: an
  /// accent is a single letter inside a word.
  void _type(String value) {
    if (_accentPage && widget.accents.contains(value)) {
      setState(() => _accentPage = false);
    }
    widget.onLetter(value);
  }

  Rect? _anchorOf(BuildContext keyContext) {
    final box = keyContext.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  void _open(_Popup popup) {
    setState(() => _popup = popup);
    _popupController.show();
  }

  void _close() {
    if (_popup == null) return;
    setState(() => _popup = null);
    _popupController.hide();
  }

  void _toggleLanguages(BuildContext keyContext) {
    if (_popup is _LanguagePopup) return _close();
    final anchor = _anchorOf(keyContext);
    if (anchor != null) _open(_LanguagePopup(anchor));
  }

  void _chooseLanguage(int index) {
    _close();
    widget.onLanguage?.call(index);
  }

  void _openVariants(BuildContext keyContext, List<String> variants) {
    final anchor = _anchorOf(keyContext);
    if (anchor == null) return;
    _selectedVariant = 0;
    _dragged = false;
    _open(_VariantPopup(anchor, variants));
  }

  void _slideOverVariants(LongPressMoveUpdateDetails details) {
    final popup = _popup;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (popup is! _VariantPopup || overlay is! RenderBox) return;
    if (details.offsetFromOrigin.distance > 8) _dragged = true;
    final local = overlay.globalToLocal(details.globalPosition);
    final rect = _variantRect(popup, overlay.size);
    final cell = _variantCellWidth(popup);
    final index =
        ((local.dx - rect.left - _popupPadding) / (cell + _popupPadding))
            .floor()
            .clamp(0, popup.variants.length - 1);
    if (index != _selectedVariant) setState(() => _selectedVariant = index);
  }

  void _releaseVariants() {
    final popup = _popup;
    if (popup is! _VariantPopup || !_dragged) return;
    _chooseVariant(popup.variants[_selectedVariant]);
  }

  void _chooseVariant(String value) {
    _close();
    widget.onLetter(value);
  }

  static double _variantCellWidth(_VariantPopup popup) =>
      math.max(popup.anchor.width, _minVariantWidth);

  /// The variant popup sits above its key, centred on it but kept inside the
  /// overlay.
  static Rect _variantRect(_VariantPopup popup, Size overlay) {
    final count = popup.variants.length;
    final width =
        count * _variantCellWidth(popup) + (count + 1) * _popupPadding;
    final height = popup.anchor.height + 2 * _popupPadding;
    final left = (popup.anchor.center.dx - width / 2)
        .clamp(
          _popupMargin,
          math.max(_popupMargin, overlay.width - width - _popupMargin),
        )
        .toDouble();
    final top = math.max(_popupMargin, popup.anchor.top - _popupGap - height);
    return Rect.fromLTWH(left, top, width, height);
  }

  Widget _buildPopup(BuildContext context) {
    final popup = _popup;
    if (popup == null) return const SizedBox.shrink();
    // The popup belongs to the keyboard: tapping it must neither move focus
    // out of the word field nor count as a tap outside it.
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final overlay = constraints.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                  ),
                ),
                switch (popup) {
                  _VariantPopup() => Positioned.fromRect(
                    rect: _variantRect(popup, overlay),
                    child: _variantPanel(popup),
                  ),
                  _LanguagePopup() => _languagePanel(popup, overlay),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _popupDecoration() {
    final colors = context.bull;
    return BoxDecoration(
      color: colors.surfaceBright,
      borderRadius: BorderRadius.circular(context.bullShapes.card),
      border: Border.all(color: colors.border),
      boxShadow: [BoxShadow(color: colors.scrim, blurRadius: 12)],
    );
  }

  Widget _variantPanel(_VariantPopup popup) {
    final colors = context.bull;
    final cell = _variantCellWidth(popup);
    final glyph = (popup.anchor.height * 0.4).clamp(16.0, 28.0);
    // ExcludeSemantics, no splash and no fade: the variants are letters of
    // the seed, like the keys.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: _popupDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(_popupPadding),
          child: Row(
            children: [
              for (final (index, variant) in popup.variants.indexed) ...[
                if (index > 0) const SizedBox(width: _popupPadding),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _chooseVariant(variant),
                  child: Container(
                    width: cell,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == _selectedVariant
                          ? colors.primary
                          : colors.transparent,
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.key,
                      ),
                    ),
                    child: BullKeyGlyph(
                      BullMnemonicKeyboard.keyLabel(variant),
                      size: glyph,
                      color: index == _selectedVariant
                          ? colors.onPrimary
                          : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _languagePanel(_LanguagePopup popup, Size overlay) {
    const padding = 6.0;
    final languages = widget.languages;
    final available = popup.anchor.top - _popupGap - _popupMargin;
    final height = math.min(
      languages.length * _languageRowHeight + 2 * padding,
      math.max(_languageRowHeight + 2 * padding, available),
    );
    final left = popup.anchor.left
        .clamp(
          _popupMargin,
          math.max(_popupMargin, overlay.width - _languageWidth - _popupMargin),
        )
        .toDouble();
    return Positioned(
      left: left,
      top: math.max(_popupMargin, popup.anchor.top - _popupGap - height),
      width: _languageWidth,
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: _popupDecoration(),
          child: ListView(
            padding: const EdgeInsets.all(padding),
            children: [
              for (final (index, language) in languages.indexed)
                _languageOption(
                  index,
                  language,
                  selected: index == widget.selectedLanguage,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageOption(
    int index,
    BullKeyboardLanguage language, {
    required bool selected,
  }) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.key);
    return InkWell(
      key: ValueKey('mnemonicLanguageOption$index'),
      canRequestFocus: false,
      borderRadius: radius,
      onTap: () => _chooseLanguage(index),
      child: Container(
        height: _languageRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.transparent,
          borderRadius: radius,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: BullText(
                language.code,
                role: BullTextRole.caption,
                fontWeight: FontWeight.w700,
                color: selected ? colors.onPrimary : colors.textMuted,
              ),
            ),
            Expanded(
              child: BullText(
                language.name,
                role: BullTextRole.body,
                color: selected ? colors.onPrimary : colors.onSurface,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backspace, enter, scramble, page and language share one look, distinct
/// from the letters: the function key fill, or the accent while [active].
class _FunctionKey extends StatelessWidget {
  final bool enabled;
  final bool active;
  final VoidCallback onTap;
  final BullKeypadMetrics metrics;
  final Widget Function(Color glyph) child;

  const _FunctionKey({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.metrics,
    required this.child,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final keypad = context.bullKeypad;
    return BullKeyCap(
      enabled: enabled,
      onTap: onTap,
      height: metrics.keyHeight,
      fill: active ? colors.primary : keypad.functionKey,
      child: child(
        !enabled
            ? keypad.onFunctionKeyDisabled
            : active
            ? colors.onPrimary
            : keypad.onFunctionKey,
      ),
    );
  }
}

/// Three suggestions across the panel, separated by thin rules: the first,
/// the best, in the middle and in bold, the next two on either side.
class _SuggestionStrip extends StatelessWidget {
  final List<String> suggestions;
  final String? notice;
  final ValueChanged<String> onTap;

  const _SuggestionStrip({
    required this.suggestions,
    required this.notice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final notice = this.notice;
    if (suggestions.isEmpty) {
      if (notice == null) return const SizedBox.expand();
      return Center(
        child: BullText(
          notice,
          role: BullTextRole.label,
          color: colors.textMuted,
        ),
      );
    }
    String? at(int index) =>
        index < suggestions.length ? suggestions[index] : null;
    final slots = [at(1), at(0), at(2)];
    return Row(
      children: [
        for (final (index, word) in slots.indexed) ...[
          if (index > 0)
            FractionallySizedBox(
              heightFactor: 0.6,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: colors.outline,
              ),
            ),
          Expanded(
            child: word == null
                ? const SizedBox.shrink()
                : InkWell(
                    // A suggestion must never take focus from the word field
                    // being typed into.
                    canRequestFocus: false,
                    onTap: () => onTap(word),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: BullText(
                          word,
                          role: BullTextRole.body,
                          fontWeight: index == 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: colors.onSurface,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
