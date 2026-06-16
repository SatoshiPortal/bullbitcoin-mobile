import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';

/// Numeric dial pad for PIN / amount entry — duplicated from
/// `core/widgets/dialpad/dial_pad.dart`.
///
/// Renders 0–9, a decimal point (hidden when [onlyDigits]) and a backspace.
/// [onNumberPressed] receives the tapped glyph; [onBackspacePressed] handles
/// delete.
class BullDialPad extends StatelessWidget {
  const BullDialPad({
    super.key,
    required this.onNumberPressed,
    required this.onBackspacePressed,
    this.disableFeedback = false,
    this.onlyDigits = false,
  });

  /// Called with the tapped digit or decimal point (`'0'`–`'9'`, `'.'`).
  final void Function(String) onNumberPressed;

  /// Called when backspace is tapped.
  final void Function() onBackspacePressed;

  /// Suppresses the tap ripple / highlight when true.
  final bool disableFeedback;

  /// Hides the decimal-point key, leaving an empty slot.
  final bool onlyDigits;

  Widget _numPadButton(BuildContext context, String num) {
    final colors = context.bull;
    return Expanded(
      child: InkWell(
        onTap: () => onNumberPressed(num),
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: BullText(
              num,
              style: BullTextStyles.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              color: colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton(BuildContext context) {
    final colors = context.bull;
    return Expanded(
      child: InkWell(
        onTap: onBackspacePressed,
        splashFactory: disableFeedback ? NoSplash.splashFactory : null,
        highlightColor: disableFeedback ? Colors.transparent : null,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Icon(Icons.backspace_outlined, color: colors.onSurface),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _numPadButton(context, '1'),
              _numPadButton(context, '2'),
              _numPadButton(context, '3'),
            ],
          ),
          Row(
            children: [
              _numPadButton(context, '4'),
              _numPadButton(context, '5'),
              _numPadButton(context, '6'),
            ],
          ),
          Row(
            children: [
              _numPadButton(context, '7'),
              _numPadButton(context, '8'),
              _numPadButton(context, '9'),
            ],
          ),
          Row(
            children: [
              if (onlyDigits)
                const Expanded(child: SizedBox(height: 64))
              else
                _numPadButton(context, '.'),
              _numPadButton(context, '0'),
              _backspaceButton(context),
            ],
          ),
        ],
      ),
    );
  }
}
