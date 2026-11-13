import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import '../feedback/bull_snack_bar.dart';
import 'bull_amount_preferences.dart';
export 'bull_amount_preferences.dart' show BullAmountUnit;
import 'package:flutter/material.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';

/// An amount whose unit override lasts only while this element is mounted.
/// Callers supply already localized, privacy-safe representations.
class BullAmount extends StatefulWidget {
  const BullAmount({
    super.key,
    required this.satsText,
    required this.btcText,
    required this.defaultUnit,
    required this.switchToBtcLabel,
    required this.switchToSatsLabel,
    this.style,
    this.color,
    this.textAlign,
    this.onLongPress,
    this.longPressLabel,
    this.tooltip,
  });

  final String satsText;
  final String btcText;
  final BullAmountUnit defaultUnit;
  final String switchToBtcLabel;
  final String switchToSatsLabel;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final VoidCallback? onLongPress;
  final String? longPressLabel;
  final String? tooltip;

  @override
  State<BullAmount> createState() => _BullAmountState();
}

class _BullAmountState extends State<BullAmount> {
  BullAmountUnit? _override;
  int? _revision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = BullAmountPreferencesScope.revisionOf(context);
    if (_revision != revision) _override = null;
    _revision = revision;
  }

  @override
  void didUpdateWidget(BullAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultUnit != widget.defaultUnit) _override = null;
  }

  @override
  Widget build(BuildContext context) {
    final unit =
        _override ??
        BullAmountPreferencesScope.maybeOf(context)?.defaultUnit ??
        widget.defaultUnit;
    final isSats = unit == BullAmountUnit.sats;
    return BullAmountUnitToggle(
      text: isSats ? widget.satsText : widget.btcText,
      unit: unit,
      actionLabel: isSats ? widget.switchToBtcLabel : widget.switchToSatsLabel,
      style: widget.style,
      color: widget.color,
      textAlign: widget.textAlign,
      onLongPress: widget.onLongPress,
      longPressLabel: widget.longPressLabel,
      tooltip: widget.tooltip,
      onPressed: () => setState(() {
        _override = isSats ? BullAmountUnit.btc : BullAmountUnit.sats;
      }),
    );
  }
}

/// Shared tap/keyboard affordance used by amounts and editable unit labels.
/// The value is a live region; never pass an unmasked private amount here.
class BullAmountUnitToggle extends StatelessWidget {
  const BullAmountUnitToggle({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onPressed,
    this.style,
    this.color,
    this.textAlign,
    this.liveRegion = true,
    this.semanticValue,
    this.unit,
    this.onLongPress,
    this.longPressLabel,
    this.tooltip,
  });

  final String text;
  final String actionLabel;
  final VoidCallback? onPressed;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final bool liveRegion;
  final String? semanticValue;
  final BullAmountUnit? unit;
  final VoidCallback? onLongPress;
  final String? longPressLabel;
  final String? tooltip;

  Future<void> _changeGlobalDefault(
    BuildContext context,
    BullAmountPreferences preferences,
    BullAmountUnit displayedUnit,
  ) async {
    final previous = preferences.defaultUnit;
    final next = displayedUnit == BullAmountUnit.sats
        ? BullAmountUnit.btc
        : BullAmountUnit.sats;
    final reset = BullAmountPreferencesScope.resetterOf(context);
    final changed = await preferences.changeDefaultUnit(next);
    if (changed) reset?.call();
    if (!context.mounted) return;
    if (!changed) {
      BullSnackBar.show(context, message: preferences.failureMessage);
      return;
    }
    BullSnackBar.show(
      context,
      message: next == BullAmountUnit.sats
          ? preferences.satsEverywhereMessage
          : preferences.btcEverywhereMessage,
      actionLabel: preferences.undoLabel,
      onAction: () async {
        final restored = await preferences.changeDefaultUnit(previous);
        if (restored) reset?.call();
        if (!restored && context.mounted) {
          BullSnackBar.show(context, message: preferences.failureMessage);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: color);
    final preferences = BullAmountPreferencesScope.maybeOf(context);
    final displayedUnit = unit;
    final VoidCallback? longPress = preferences != null && displayedUnit != null
        ? () => _changeGlobalDefault(context, preferences, displayedUnit)
        : onLongPress;
    final label = preferences?.globalActionLabel ?? longPressLabel;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null || longPress != null,
      liveRegion: liveRegion,
      label: actionLabel,
      value: semanticValue ?? text,
      onTap: onPressed,
      onLongPress: longPress,
      customSemanticsActions: longPress != null && label != null
          ? {CustomSemanticsAction(label: label): longPress}
          : null,
      excludeSemantics: true,
      child: Tooltip(
        message: preferences?.tooltip ?? tooltip ?? actionLabel,
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: onPressed,
          onLongPress: longPress,
          style: TextButton.styleFrom(
            minimumSize: const Size(BullSpacing.xxl, BullSpacing.xxl),
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xxs),
            foregroundColor: color ?? effectiveStyle?.color,
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          child: Text(text, style: effectiveStyle, textAlign: textAlign),
        ),
      ),
    );
  }
}
