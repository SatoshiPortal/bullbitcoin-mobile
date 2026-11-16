import 'dart:math';

import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:bull_ui/src/theme/bull_keypad_colors.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Digit keypad for PIN entry.
///
/// The bottom-left key toggles a scrambled layout, off by default and never
/// persisted: while it is on, the ten digits are shuffled again after every
/// tap, so the position of a finger, a smudge or a screen recording tells an
/// onlooker nothing about the PIN. The keypad owns that state, so every PIN
/// screen gets the same policy without repeating it.
///
/// Keys never splash nor fade: even in the plain layout a lingering highlight
/// would mark the digit just pressed for a camera.
class BullPinPad extends StatefulWidget {
  /// Called with the digit of the tapped key, 0 to 9.
  final ValueChanged<int> onDigit;

  final VoidCallback onBackspace;

  /// Tooltip of the scramble key. Passed in so the kit stays free of the app's
  /// localization.
  final String scrambleHint;

  /// When false, every key ignores taps and sinks into the panel. Callers lock the pad
  /// this way during a failed-attempt timeout or while a PIN is verified.
  final bool enabled;

  const BullPinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.scrambleHint,
    this.enabled = true,
  });

  /// The plain layout: 1 to 9 in three rows, then 0 under 8.
  static const digits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];

  /// Three columns, four rows. Keys are wider than tall, grow with the width up
  /// to a desktop-sized cap, and keep a usable height in a short landscape
  /// window.
  static const grid = BullKeypadGrid(
    columns: 3,
    rows: 4,
    aspectRatio: 0.6,
    minKeyHeight: 40,
    maxKeyHeight: 72,
    maxKeyWidth: 120,
    gap: 8,
    screenShare: 0.42,
  );

  /// A reshuffle keeps at most this many of the ten digits in place.
  static const maxUnmovedDigits = 2;

  @override
  State<BullPinPad> createState() => _BullPinPadState();
}

class _BullPinPadState extends State<BullPinPad> {
  final Random _random = Random.secure();
  bool _scrambled = false;
  List<int> _layout = BullPinPad.digits;

  void _toggleScramble() {
    setState(() {
      _scrambled = !_scrambled;
      // Enabling shuffles at once, so the very first digit is already in a
      // random place.
      _layout = _scrambled ? _reshuffled() : BullPinPad.digits;
    });
  }

  List<int> _reshuffled() => BullKeyScramble.next(
    BullPinPad.digits,
    previous: _layout,
    maxUnmoved: BullPinPad.maxUnmovedDigits,
    random: _random,
  );

  void _reshuffleIfScrambled() {
    if (_scrambled) setState(() => _layout = _reshuffled());
  }

  void _onDigit(int digit) {
    widget.onDigit(digit);
    _reshuffleIfScrambled();
  }

  void _onBackspace() {
    widget.onBackspace();
    _reshuffleIfScrambled();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The panel shows a gap of itself around the keys; each row already starts with one.
        final gap = BullPinPad.grid.gap;
        final panelPadding = EdgeInsets.fromLTRB(gap, 0, gap, gap);
        final metrics = BullPinPad.grid.resolve(
          constraints.deflate(panelPadding),
          MediaQuery.sizeOf(context),
        );
        Widget digitKey(int slot) => _DigitKey(
          digit: _layout[slot],
          enabled: widget.enabled,
          metrics: metrics,
          onTap: _onDigit,
        );
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.bullKeypad.panel,
              borderRadius: BorderRadius.circular(context.bullShapes.key),
            ),
            child: Padding(
              padding: panelPadding,
              child: SizedBox(
                width: metrics.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < 3; row++)
                      _PadRow(
                        metrics: metrics,
                        keys: [
                          for (var col = 0; col < 3; col++)
                            digitKey(row * 3 + col),
                        ],
                      ),
                    _PadRow(
                      metrics: metrics,
                      keys: [
                        _ScrambleKey(
                          active: _scrambled,
                          enabled: widget.enabled,
                          hint: widget.scrambleHint,
                          metrics: metrics,
                          onTap: _toggleScramble,
                        ),
                        digitKey(9),
                        _BackspaceKey(
                          enabled: widget.enabled,
                          metrics: metrics,
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PadRow extends StatelessWidget {
  final BullKeypadMetrics metrics;
  final List<Widget> keys;

  const _PadRow({required this.metrics, required this.keys});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: metrics.gap),
      child: Row(
        children: [
          for (final (index, key) in keys.indexed) ...[
            if (index > 0) SizedBox(width: metrics.gap),
            Expanded(child: key),
          ],
        ],
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  final int digit;
  final bool enabled;
  final BullKeypadMetrics metrics;
  final ValueChanged<int> onTap;

  const _DigitKey({
    required this.digit,
    required this.enabled,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BullKeyCap(
      enabled: enabled,
      onTap: () => onTap(digit),
      height: metrics.keyHeight,
      suppressAnimation: true,
      child: BullKeyGlyph(
        '$digit',
        size: metrics.glyphSize,
        color: enabled
            ? context.bullKeypad.onKey
            : context.bullKeypad.disabledGlyph,
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
      suppressAnimation: true,
      child: Icon(
        Icons.backspace_outlined,
        size: metrics.glyphSize,
        color: enabled
            ? context.bullKeypad.onKey
            : context.bullKeypad.disabledGlyph,
      ),
    );
  }
}

/// Toggles the scrambled layout. Accent-coloured while active.
class _ScrambleKey extends StatelessWidget {
  final bool active;
  final bool enabled;
  final String hint;
  final BullKeypadMetrics metrics;
  final VoidCallback onTap;

  const _ScrambleKey({
    required this.active,
    required this.enabled,
    required this.hint,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final keypad = context.bullKeypad;
    return Tooltip(
      message: hint,
      child: BullKeyCap(
        key: const Key('pinPadScrambleToggle'),
        enabled: enabled,
        onTap: onTap,
        height: metrics.keyHeight,
        suppressAnimation: true,
        child: Icon(
          Icons.shuffle,
          size: metrics.glyphSize,
          color: !enabled
              ? keypad.disabledGlyph
              : active
              ? context.bull.primary
              : keypad.onKey,
        ),
      ),
    );
  }
}
