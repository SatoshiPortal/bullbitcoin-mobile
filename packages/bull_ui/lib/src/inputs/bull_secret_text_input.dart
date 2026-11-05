import 'package:bull_ui/src/inputs/labeled_input_frame.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A labelled field for a secret the user has to type on the system keyboard,
/// such as a BIP39 passphrase.
///
/// Hardened by construction, with no option to loosen it:
/// - the IME gets no suggestions, autocorrect, personalised learning,
///   autofill or smart punctuation, so it neither learns nor rewrites the value
///   (iOS turning `'` into `’` would derive another wallet);
/// - the text is obscured until the user reveals it with the trailing toggle;
/// - no selection, so nothing can be copied out of the field;
/// - accessibility services see the [label] and the toggle, never the value or
///   its length.
///
/// The value is reported through [onChanged] only; the field never exposes it.
class BullSecretTextInput extends StatefulWidget {
  const BullSecretTextInput({
    super.key,
    required this.label,
    required this.onChanged,
    required this.showLabel,
    required this.hideLabel,
    this.hint = '',
  });

  /// Label shown above the field, and the field's only accessible name.
  final String label;

  /// Fired on every change.
  final ValueChanged<String> onChanged;

  /// Accessible name of the toggle while the value is hidden.
  final String showLabel;

  /// Accessible name of the toggle while the value is shown.
  final String hideLabel;

  /// Placeholder text.
  final String hint;

  @override
  State<BullSecretTextInput> createState() => _BullSecretTextInputState();
}

class _BullSecretTextInputState extends State<BullSecretTextInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// iOS maps `visiblePassword` to an ASCII-only keyboard, which would make a
  /// non-ASCII passphrase untypeable. Android keeps every keyboard, and the
  /// variation tells the IME the value is a password.
  TextInputType get _keyboardType => defaultTargetPlatform == .iOS
      ? TextInputType.text
      : TextInputType.visiblePassword;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return LabeledInputFrame(
      label: widget.label,
      child: Row(
        children: [
          Expanded(
            // A TextField publishes its text (or one dot per character) as
            // its semantics value. The replacement node keeps the field
            // findable and focusable by name, and carries nothing else.
            child: ListenableBuilder(
              listenable: _focusNode,
              builder: (context, child) => Semantics(
                label: widget.label,
                textField: true,
                obscured: true,
                focusable: true,
                focused: _focusNode.hasFocus,
                onTap: _focusNode.requestFocus,
                excludeSemantics: true,
                child: child,
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                obscureText: _obscured,
                keyboardType: _keyboardType,
                textInputAction: TextInputAction.done,
                maxLines: 1,
                enableSuggestions: false,
                autocorrect: false,
                enableIMEPersonalizedLearning: false,
                autofillHints: const <String>[],
                smartQuotesType: SmartQuotesType.disabled,
                smartDashesType: SmartDashesType.disabled,
                enableInteractiveSelection: false,
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                style: LabeledInputFrame.fieldStyle(context, colors.text),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: LabeledInputFrame.fieldStyle(
                    context,
                    colors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: colors.surface,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _obscured ? widget.showLabel : widget.hideLabel,
            onPressed: () => setState(() => _obscured = !_obscured),
            icon: Icon(
              _obscured ? Icons.visibility_outlined : Icons.visibility_off,
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
