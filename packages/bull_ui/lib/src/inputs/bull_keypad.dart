import 'package:bull_ui/src/theme/bull_typography.dart';

import 'dart:math' as math;

import 'package:bull_ui/src/theme/bull_keypad_colors.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// How the keys of an on-screen keypad grow with the space they are given.
///
/// Tokens never scale with the screen, so key size is a layout decision: each
/// keypad resolves it from its own constraints, on a phone as in a desktop
/// window.
@immutable
class BullKeypadGrid {
  /// Keys across the widest row.
  final int columns;

  /// Rows of keys.
  final int rows;

  /// Key height over key width while both budgets allow it.
  final double aspectRatio;

  /// Floor for a cramped space, such as a phone in landscape: a key stays a
  /// usable tap target.
  final double minKeyHeight;

  /// Ceiling for a roomy space, such as a desktop window.
  final double maxKeyHeight;

  /// Keeps a wide window from stretching keys into bars; the keypad then
  /// centres at its natural width.
  final double maxKeyWidth;

  /// Space between two keys, across and down.
  final double gap;

  /// Share of the screen or window height the rows may take. A [Column]
  /// leaves its children's height unbounded, so this is the height budget.
  final double screenShare;

  /// Glyph and icon size as a share of the key height, up to [maxGlyphSize].
  final double glyphScale;
  final double maxGlyphSize;

  const BullKeypadGrid({
    required this.columns,
    required this.rows,
    required this.aspectRatio,
    required this.minKeyHeight,
    required this.maxKeyHeight,
    required this.maxKeyWidth,
    required this.gap,
    required this.screenShare,
    this.glyphScale = 0.4,
    this.maxGlyphSize = 28,
  });

  /// Sizes the keys for [constraints] on a [screen] of the given size.
  ///
  /// The width is shared by [columns] keys, capped at [maxKeyWidth]. The
  /// height follows [aspectRatio] unless the budget for [rows] is smaller,
  /// then is clamped to [minKeyHeight]..[maxKeyHeight].
  BullKeypadMetrics resolve(BoxConstraints constraints, Size screen) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : screen.width;
    final heightBudget = math.min(
      constraints.maxHeight,
      screen.height * screenShare,
    );
    final keyWidth = math.max(
      0.0,
      math.min((width - gap * (columns - 1)) / columns, maxKeyWidth),
    );
    final keyHeight = math
        .min(keyWidth * aspectRatio, (heightBudget - gap * (rows - 1)) / rows)
        .clamp(minKeyHeight, maxKeyHeight);
    return BullKeypadMetrics(
      keyWidth: keyWidth,
      keyHeight: keyHeight,
      gap: gap,
      width: keyWidth * columns + gap * (columns - 1),
      glyphScale: glyphScale,
      maxGlyphSize: maxGlyphSize,
    );
  }
}

/// Key sizes resolved by [BullKeypadGrid.resolve].
@immutable
class BullKeypadMetrics {
  final double keyWidth;
  final double keyHeight;
  final double gap;

  /// Width of the widest row, gaps included.
  final double width;

  final double glyphScale;
  final double maxGlyphSize;

  const BullKeypadMetrics({
    required this.keyWidth,
    required this.keyHeight,
    required this.gap,
    required this.width,
    this.glyphScale = 0.4,
    this.maxGlyphSize = 28,
  });

  /// Glyph and icon size for a key of this height.
  double get glyphSize => (keyHeight * glyphScale).clamp(16.0, maxGlyphSize);
}

/// The shared key shell: colour, corner, tap surface and height. A disabled
/// key has no tap handler at all, so it cannot fire even through automation.
class BullKeyCap extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final double height;
  final Widget child;

  /// The key colour whatever its state. Null keeps the PIN pad look: the key colour when enabled, no fill when not, so a disabled key sinks into the panel.
  final Color? fill;

  /// When true, the key changes appearance as an instant cut with no ink
  /// splash. Used while the layout is reshuffling on every tap: an animated
  /// colour fade or a splash that outlives the reshuffle would mark, for a
  /// frame, which slot was just pressed — letting an observer follow a key
  /// across the shuffle and defeating it.
  final bool suppressAnimation;

  const BullKeyCap({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.height,
    required this.child,
    this.suppressAnimation = false,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.key);
    return Material(
      // Zero duration: even in basic mode an enable/disable colour tween is an
      // extra frame of state history for a camera; there is no reason to
      // animate a key cap.
      animationDuration: Duration.zero,
      color: fill ?? (enabled ? context.bullKeypad.key : colors.transparent),
      borderRadius: radius,
      child: InkWell(
        // A key must never take focus from the field being typed into.
        canRequestFocus: false,
        borderRadius: radius,
        splashFactory: suppressAnimation ? NoSplash.splashFactory : null,
        highlightColor: suppressAnimation ? colors.transparent : null,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: height,
          child: Center(
            // Scales a glyph down rather than overflowing a cramped key.
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
  }
}

/// The character a key carries, sized by the caller from the key height.
///
/// It ignores the system text size: the key already grows with the screen, and scaling the glyph again would only push it out of the key.
class BullKeyGlyph extends StatelessWidget {
  final String text;
  final double size;
  final Color color;

  const BullKeyGlyph(
    this.text, {
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.bullType.subtitle
          .copyWith(fontWeight: FontWeight.w700)
          .copyWith(fontSize: size, color: color),
      textScaler: TextScaler.noScaling,
    );
  }
}

/// The reshuffle policy shared by every scrambling keypad.
abstract final class BullKeyScramble {
  /// A random arrangement of [keys] that leaves at most [maxUnmoved] of them
  /// where [previous] had them. A shuffle that leaves most keys in place looks
  /// like nothing changed and invites a mistap from muscle memory.
  ///
  /// Pass a `Random.secure()`: a predictable layout defeats the scramble.
  static List<T> next<T>(
    List<T> keys, {
    required List<T> previous,
    required int maxUnmoved,
    required math.Random random,
  }) {
    assert(keys.length == previous.length, 'Both layouts hold the same keys');
    List<T> next;
    do {
      next = List.of(keys)..shuffle(random);
    } while (_unmoved(next, previous) > maxUnmoved);
    return next;
  }

  static int _unmoved<T>(List<T> a, List<T> b) {
    var same = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] == b[i]) same++;
    }
    return same;
  }
}
