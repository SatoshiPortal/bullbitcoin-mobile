import '../buttons/bull_field_action.dart';

import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:material_ui/material_ui.dart';

/// A controlled payment destination field. Parsing and address verification are
/// owned by the caller; [validAddress] is its interactive verified-value view.
class BullPaymentDestinationInput extends StatefulWidget {
  const BullPaymentDestinationInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.onCommitted,
    this.label,
    required this.hint,
    required this.pasteLabel,
    required this.scanLabel,
    required this.clearLabel,
    required this.onPaste,
    required this.onScan,
    required this.onClear,
    this.validAddress,
    this.kind,
    this.error,
    this.helper,
    this.onRemove,
    this.removeLabel,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  }) : assert(onRemove == null || removeLabel != null);

  final String value;
  final ValueChanged<String> onChanged;

  /// When set, typing stays in the field and the text is reported here once
  /// the user leaves the field or submits it, instead of to [onChanged] on
  /// every keystroke. Paste, scan and clear still report at once.
  final ValueChanged<String>? onCommitted;
  final String? label;
  final String hint;
  final String pasteLabel;
  final String scanLabel;
  final String clearLabel;
  final VoidCallback onPaste;
  final VoidCallback onScan;
  final VoidCallback onClear;
  final Widget? validAddress;
  final String? kind;
  final String? error;
  final String? helper;
  final VoidCallback? onRemove;
  final String? removeLabel;
  final TextInputType keyboardType;
  final bool enabled;

  @override
  State<BullPaymentDestinationInput> createState() =>
      _BullPaymentDestinationInputState();
}

class _BullPaymentDestinationInputState
    extends State<BullPaymentDestinationInput> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  String? _committed;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (!_focus.hasFocus) _commit();
    setState(() {});
  }

  void _commit() {
    final onCommitted = widget.onCommitted;
    final text = _controller.text;
    if (onCommitted == null || text == (_committed ?? widget.value)) return;
    _committed = text;
    onCommitted(text);
  }

  VoidCallback _replacing(VoidCallback action) => () {
    _committed = _controller.text;
    _focus.unfocus();
    action();
  };

  @override
  void didUpdateWidget(covariant BullPaymentDestinationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _committed = null;
    if (_focus.hasFocus && widget.onCommitted != null) return;
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    // While the user types, a prefix that already parses (ishi@w) must not
    // replace the field; the recognised destination shows once they leave it.
    final valid =
        widget.validAddress != null && widget.error == null && !_focus.hasFocus;
    final error = widget.onCommitted != null && _focus.hasFocus
        ? null
        : widget.error;
    final messageStyle = context.bullType.label.copyWith(
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null || widget.onRemove != null) ...[
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  excluding: !valid,
                  child: Text(
                    widget.label ?? '',
                    style: context.bullType.body.copyWith(color: colors.text),
                  ),
                ),
              ),
              if (widget.onRemove != null)
                BullFieldAction(
                  label: widget.removeLabel ?? widget.clearLabel,
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: Icons.close,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.input),
            border: Border.all(
              color: error == null ? colors.border : colors.error,
            ),
          ),
          child: valid
              ? Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DefaultTextStyle(
                              style: context.bullType.body.copyWith(
                                color: colors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: IgnorePointer(
                                ignoring: !widget.enabled,
                                child: widget.validAddress ?? const SizedBox(),
                              ),
                            ),
                            if (widget.kind case final kind?)
                              Text(
                                kind,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: messageStyle.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    BullFieldAction(
                      label: widget.clearLabel,
                      onPressed: widget.enabled
                          ? _replacing(widget.onClear)
                          : null,
                      icon: Icons.close,
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : Semantics(
                  label: widget.label ?? widget.hint,
                  hint: widget.label == null || widget.label == widget.hint
                      ? null
                      : widget.hint,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    onChanged: widget.onCommitted == null
                        ? widget.onChanged
                        : null,
                    onSubmitted: widget.onCommitted == null
                        ? null
                        : (_) => _focus.unfocus(),
                    keyboardType: widget.keyboardType,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartQuotesType: SmartQuotesType.disabled,
                    smartDashesType: SmartDashesType.disabled,
                    textCapitalization: TextCapitalization.none,
                    maxLines: 1,
                    style: context.bullType.body.copyWith(color: colors.text),
                    decoration: InputDecoration(
                      hint: ExcludeSemantics(
                        child: Text(
                          widget.hint,
                          style: context.bullType.body.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
        ),
        if (error case final error?) ...[
          const SizedBox(height: 8),
          Text(error, style: messageStyle.copyWith(color: colors.error)),
        ] else if (!valid) ...[
          if (widget.helper case final helper?) ...[
            const SizedBox(height: 8),
            Text(helper, style: messageStyle.copyWith(color: colors.textMuted)),
          ],
        ],
        if (!valid) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BullButton.secondary(
                  label: widget.pasteLabel,
                  onPressed: (!widget.enabled)
                      ? null
                      : _replacing(widget.onPaste),
                  iconData: Icons.paste_sharp,
                  iconFirst: true,
                  height: 44,
                  textStyle: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BullButton.secondary(
                  label: widget.scanLabel,
                  onPressed: (!widget.enabled)
                      ? null
                      : _replacing(widget.onScan),
                  iconData: Icons.qr_code_scanner,
                  iconFirst: true,
                  height: 44,
                  textStyle: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
