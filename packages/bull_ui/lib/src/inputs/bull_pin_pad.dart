import 'dart:async';
import 'dart:math';

import 'package:bull_ui/src/inputs/bull_keypad.dart';
import 'package:bull_ui/src/theme/bull_keypad_colors.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Digit keypad for PIN entry.
///
/// The bottom-left key toggles a scrambled layout, off by default and never
/// persisted: while it is on, the ten digits are shuffled again after every
/// tap, so the position of a finger, a smudge or a screen recording tells an
/// onlooker nothing about the PIN. The keypad owns that state, so every PIN
/// screen gets the same policy without repeating it.
///
/// Medium-weight digits in rounded keys outlined in [BullTheme.text], with no fill or
/// panel; scramble and backspace are bare icons in the bottom corners.
///
/// A digit key fills while held, like a phone's passcode keys, which shows an
/// onlooker the digit pressed, scrambled or not. The fill never splashes and
/// vanishes at once on a reshuffle, so it never lands on another digit. Every
/// tap also gives a light vibration.
class BullPinPad extends StatefulWidget {
  /// Called with the digit of the tapped key, 0 to 9.
  final ValueChanged<int> onDigit;

  final VoidCallback onBackspace;

  /// Tooltip of the scramble key. Passed in so the kit stays free of the app's
  /// localization.
  final String scrambleHint;

  /// When false, every key ignores taps and turns grey. Callers lock the pad
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

  /// Three columns, four rows of outlined keys across the full width, wider
  /// than tall: up to 56 tall, and at least 48 in a short window.
  static const grid = BullKeypadGrid(
    columns: 3,
    rows: 4,
    aspectRatio: 0.5,
    minKeyHeight: 48,
    maxKeyHeight: 56,
    maxKeyWidth: 160,
    gap: 8,
    screenShare: 0.3,
  );

  /// A reshuffle keeps at most this many of the ten digits in place.
  static const maxUnmovedDigits = 2;

  @override
  State<BullPinPad> createState() => _BullPinPadState();
}

/// Size of the bare scramble and backspace icons.
const double _iconSize = 22;

class _BullPinPadState extends State<BullPinPad> {
  final Random _random = Random.secure();
  bool _scrambled = false;
  List<int> _layout = BullPinPad.digits;

  /// Bumped on every layout change. Keys are rebuilt fresh, so a held key's
  /// fill vanishes at once instead of fading over the digit now in its slot.
  int _layouts = 0;

  void _toggleScramble() {
    _click();
    setState(() {
      _scrambled = !_scrambled;
      // Enabling shuffles at once, so the very first digit is already in a
      // random place.
      _layout = _scrambled ? _reshuffled() : BullPinPad.digits;
      _layouts++;
    });
  }

  List<int> _reshuffled() => BullKeyScramble.next(
    BullPinPad.digits,
    previous: _layout,
    maxUnmoved: BullPinPad.maxUnmovedDigits,
    random: _random,
  );

  void _reshuffleIfScrambled() {
    if (!_scrambled) return;
    setState(() {
      _layout = _reshuffled();
      _layouts++;
    });
  }

  void _click() => unawaited(HapticFeedback.selectionClick());

  void _onDigit(int digit) {
    _click();
    widget.onDigit(digit);
    _reshuffleIfScrambled();
  }

  void _onBackspace() {
    _click();
    widget.onBackspace();
    _reshuffleIfScrambled();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = BullPinPad.grid.resolve(
          constraints,
          MediaQuery.sizeOf(context),
        );
        Widget digitKey(int slot) => _DigitKey(
          key: ValueKey((_layouts, slot)),
          digit: _layout[slot],
          enabled: widget.enabled,
          metrics: metrics,
          onTap: _onDigit,
        );
        return Center(
          child: SizedBox(
            width: metrics.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < 3; row++)
                  _PadRow(
                    metrics: metrics,
                    keys: [
                      for (var col = 0; col < 3; col++) digitKey(row * 3 + col),
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
    super.key,
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
      semanticLabel: '$digit',
      height: metrics.keyHeight,
      fill: context.bull.transparent,
      borderColor: enabled
          ? context.bull.text
          : context.bullKeypad.disabledGlyph,
      pressedColor: context.bull.surfaceContainerHighest,
      child: BullKeyGlyph(
        '$digit',
        size: metrics.glyphSize,
        weight: FontWeight.w500,
        color: enabled ? context.bull.text : context.bullKeypad.disabledGlyph,
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
      semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
      height: metrics.keyHeight,
      fill: context.bull.transparent,
      suppressAnimation: true,
      child: Icon(
        Icons.backspace_outlined,
        size: _iconSize,
        color: enabled ? context.bull.text : context.bullKeypad.disabledGlyph,
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
      excludeFromSemantics: true,
      child: BullKeyCap(
        key: const Key('pinPadScrambleToggle'),
        enabled: enabled,
        onTap: onTap,
        semanticLabel: hint,
        toggled: active,
        height: metrics.keyHeight,
        fill: context.bull.transparent,
        suppressAnimation: true,
        child: Icon(
          Icons.shuffle,
          size: _iconSize,
          color: !enabled
              ? keypad.disabledGlyph
              : active
              ? context.bull.primary
              : context.bull.text,
        ),
      ),
    );
  }
}
