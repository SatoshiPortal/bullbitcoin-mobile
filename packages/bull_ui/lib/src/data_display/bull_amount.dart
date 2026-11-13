import 'package:flutter/material.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';

/// Local presentation unit, independent of application preferences.
enum BullAmountUnit { sats, btc }

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
  });

  final String satsText;
  final String btcText;
  final BullAmountUnit defaultUnit;
  final String switchToBtcLabel;
  final String switchToSatsLabel;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  @override
  State<BullAmount> createState() => _BullAmountState();
}

class _BullAmountState extends State<BullAmount> {
  BullAmountUnit? _override;

  @override
  Widget build(BuildContext context) {
    final unit = _override ?? widget.defaultUnit;
    final isSats = unit == BullAmountUnit.sats;
    return BullAmountUnitToggle(
      text: isSats ? widget.satsText : widget.btcText,
      actionLabel: isSats ? widget.switchToBtcLabel : widget.switchToSatsLabel,
      style: widget.style,
      color: widget.color,
      textAlign: widget.textAlign,
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
  });

  final String text;
  final String actionLabel;
  final VoidCallback? onPressed;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final bool liveRegion;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: color);
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      liveRegion: liveRegion,
      label: actionLabel,
      value: semanticValue ?? text,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: actionLabel,
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(BullSpacing.xxl, BullSpacing.xxl),
            padding: const EdgeInsets.symmetric(horizontal: BullSpacing.xxs),
            foregroundColor: color ?? effectiveStyle?.color,
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(text, style: effectiveStyle, textAlign: textAlign),
              ),
              const SizedBox(width: BullSpacing.xxs),
              Icon(Icons.swap_horiz, size: BullSpacing.md, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
