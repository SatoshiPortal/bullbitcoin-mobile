import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Square selection box (the design's `SelectBox`). **New.** 22×22, 2px radius,
/// 2px border — red when checked, muted otherwise, and a faint border when
/// [disabled]. Shows a red-filled check when checked.
///
/// The drawn box stays 22px; the touch target around it is 48×48. The widget is
/// a checkable node for assistive technologies ([Semantics.checked] and
/// [Semantics.enabled], no button role) that Tab reaches and Enter or Space
/// activates. It carries no visible label of its own: name it with
/// [semanticLabel] when the box stands alone, or merge it with the visible
/// label of its row (`MergeSemantics`) instead.
class BullCheckbox extends StatefulWidget {
  const BullCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.disabled = false,
    this.semanticLabel,
  });

  /// Whether the box is checked.
  final bool checked;

  /// Fired with the new value on tap. Null also renders the box inert.
  final ValueChanged<bool>? onChanged;

  /// When true, renders the disabled-styled border (still tappable if
  /// [onChanged] is non-null — frozen tiles allow unfreeze selection).
  final bool disabled;

  /// Name announced by assistive technologies (TalkBack/VoiceOver). Null when
  /// the caller merges the box with its visible label (`MergeSemantics`), so
  /// the label is not read twice.
  final String? semanticLabel;

  @override
  State<BullCheckbox> createState() => _BullCheckboxState();
}

class _BullCheckboxState extends State<BullCheckbox> {
  bool _focused = false;

  /// Enter and Space activate a focused box, as for any focusable control.
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        _toggle();
        return null;
      },
    ),
  };

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    onChanged(!widget.checked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final interactive = widget.onChanged != null;
    final borderColor = widget.checked
        ? colors.primary
        : widget.disabled
        ? colors.border
        : colors.textMuted;
    final box = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: widget.checked ? colors.primary : null,
        borderRadius: BorderRadius.circular(context.bullShapes.checkbox),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: widget.checked
          ? BullIcon(BullIcons.check, size: 16, color: colors.onPrimary)
          : null,
    );

    return Semantics(
      label: widget.semanticLabel,
      checked: widget.checked,
      enabled: interactive,
      child: FocusableActionDetector(
        enabled: interactive,
        actions: _actions,
        onShowFocusHighlight: (focused) {
          if (_focused == focused) return;
          setState(() => _focused = focused);
        },
        // The pointer action lives here only; the node's semantic tap is this
        // same gesture, so activating it once fires [onChanged] once.
        child: GestureDetector(
          excludeFromSemantics: !interactive,
          onTap: interactive ? _toggle : null,
          behavior: HitTestBehavior.opaque,
          // 22px box centered in a 48px tap target.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: _focused
                  // Drawn only while keyboard-focused, so the box itself is
                  // unchanged at rest, checked, and disabled.
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.text, width: 2),
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.checkbox,
                        ),
                      ),
                      child: box,
                    )
                  : box,
            ),
          ),
        ),
      ),
    );
  }
}
