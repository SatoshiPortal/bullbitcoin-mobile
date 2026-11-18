import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The rounded search bar: a filled, borderless card holding a magnifier and
/// a muted hint, shaped after AOSP's `search_bar.xml`.
///
/// Two modes share the look:
/// - [BullSearchBar.button] is an entry point. Its label is static text and
///   tapping it opens a search screen, so no keyboard rises where it sits.
/// - [BullSearchBar.new] is a field: typing searches in place, and a clear
///   button appears while there is a query.
class BullSearchBar extends StatefulWidget {
  /// A field that reports every change of its text through [onChanged].
  const BullSearchBar({
    super.key,
    required String this.hint,
    required String this.value,
    required ValueChanged<String> this.onChanged,
    required VoidCallback this.onCleared,
    required String this.clearTooltip,
    this.focusNode,
    this.fieldKey,
  }) : label = null,
       onTap = null;

  /// An entry point that opens search elsewhere.
  ///
  /// The icon is decorative and [label] already names the action, so the bar
  /// reports itself as a single button rather than as an icon plus a string.
  const BullSearchBar.button({
    super.key,
    required String this.label,
    required VoidCallback this.onTap,
  }) : hint = null,
       value = null,
       onChanged = null,
       onCleared = null,
       clearTooltip = null,
       focusNode = null,
       fieldKey = null;

  /// The button's text.
  final String? label;

  /// Fired when the button is tapped.
  final VoidCallback? onTap;

  /// The field's placeholder.
  final String? hint;

  /// The field's text, owned by the caller; the field follows it when it
  /// changes elsewhere (cleared by a state change, for example).
  final String? value;

  final ValueChanged<String>? onChanged;

  /// Fired by the clear button.
  final VoidCallback? onCleared;

  /// Tooltip and accessible label of the clear button.
  final String? clearTooltip;
  final FocusNode? focusNode;

  /// Key of the inner text field, for tests.
  final Key? fieldKey;

  @override
  State<BullSearchBar> createState() => _BullSearchBarState();
}

class _BullSearchBarState extends State<BullSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void didUpdateWidget(BullSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onTap = widget.onTap;
    if (label != null && onTap != null) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: _Frame(
          onTap: onTap,
          trailing: const Gap(16),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _hintStyle(context),
          ),
        ),
      );
    }

    final colors = context.bull;
    final textStyle = context.bullType.body.copyWith(
      fontWeight: FontWeight.w500,
    );
    final hasQuery = (widget.value ?? '').isNotEmpty;
    final onCleared = widget.onCleared;
    return _Frame(
      trailing: hasQuery && onCleared != null
          ? IconButton(
              icon: BullIcon(BullIcons.close, color: colors.textMuted),
              tooltip: widget.clearTooltip,
              onPressed: onCleared,
            )
          : const Gap(16),
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: textStyle.copyWith(color: colors.text),
        cursorColor: colors.primary,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: _hintStyle(context),
          hintMaxLines: 1,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
        ),
      ),
    );
  }

  static TextStyle? _hintStyle(BuildContext context) => context.bullType.body
      .copyWith(fontWeight: FontWeight.w500)
      .copyWith(color: context.bull.textMuted);
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, required this.trailing, this.onTap});

  final Widget child;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final content = SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 8),
        child: Row(
          children: [
            BullIcon(BullIcons.search, color: colors.onSurface),
            const Gap(8),
            Expanded(child: child),
            trailing,
          ],
        ),
      ),
    );
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(context.bullShapes.input),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
