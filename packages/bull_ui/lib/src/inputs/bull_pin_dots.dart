import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The PIN typed so far, the field above a [BullPinPad]: one small dot per
/// digit inside a box outlined in [BullTheme.text], a show/hide eye at its
/// end and an optional [hint] under it.
///
/// The dots only appear as digits are typed, so the field never suggests a
/// PIN length. Shown, each dot is replaced by its digit. The digits never
/// reach the semantics tree.
class BullPinDots extends StatelessWidget {
  const BullPinDots({
    super.key,
    required this.value,
    required this.obscure,
    required this.onToggleObscure,
    required this.showLabel,
    required this.hideLabel,
    this.hint,
    this.semanticLabel,
  });

  /// The PIN typed so far.
  final String value;

  /// Whether the digits are hidden behind dots.
  final bool obscure;

  final VoidCallback onToggleObscure;

  /// Accessible names of the eye, passed in so the kit stays free of the
  /// app's localization.
  final String showLabel;
  final String hideLabel;

  /// A line under the box, such as how many digits the PIN may have.
  final String? hint;

  /// Accessible name of the field.
  final String? semanticLabel;

  static const double _dot = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            // The same outline and corner as the keypad keys under it.
            border: Border.all(color: colors.text),
            borderRadius: BorderRadius.circular(context.bullShapes.key),
          ),
          child: Row(
            children: [
              // Balances the eye, so the dots stay centred in the box.
              const SizedBox(width: 48),
              Expanded(
                child: Semantics(
                  label: semanticLabel,
                  child: ExcludeSemantics(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 10,
                        children: [
                          for (final digit in value.split(''))
                            if (obscure)
                              Container(
                                width: _dot,
                                height: _dot,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.text,
                                ),
                              )
                            else
                              Text(
                                digit,
                                style: context.bullType.subtitle.copyWith(
                                  color: colors.text,
                                  height: 1,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: obscure ? showLabel : hideLabel,
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: context.bullType.caption.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
