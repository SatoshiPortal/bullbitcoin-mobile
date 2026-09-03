import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

Future<String?> showSignerPassphraseDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String hint,
  required String cancelLabel,
  required String confirmLabel,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SignerPassphraseDialog(
    title: title,
    description: description,
    hint: hint,
    cancelLabel: cancelLabel,
    confirmLabel: confirmLabel,
  ),
);

final class _SignerPassphraseDialog extends StatefulWidget {
  final String title;
  final String description;
  final String hint;
  final String cancelLabel;
  final String confirmLabel;

  const _SignerPassphraseDialog({
    required this.title,
    required this.description,
    required this.hint,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  State<_SignerPassphraseDialog> createState() =>
      _SignerPassphraseDialogState();
}

final class _SignerPassphraseDialogState extends State<_SignerPassphraseDialog>
    with PrivacyScreen {
  var _passphrase = '';

  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.description),
        const Gap(16),
        BullInputText(
          value: _passphrase,
          onChanged: (value) => setState(() => _passphrase = value),
          hint: widget.hint,
          obscure: true,
          enableSuggestions: false,
          autocorrect: false,
          smartQuotesType: SmartQuotesType.disabled,
          smartDashesType: SmartDashesType.disabled,
          maxLines: 1,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      TextButton(
        onPressed: _passphrase.isEmpty
            ? null
            : () => Navigator.of(context).pop(_passphrase),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
