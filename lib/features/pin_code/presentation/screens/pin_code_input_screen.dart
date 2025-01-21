// Make sure the text, confirm handler and success state listener handler can
//  be passed in so the screen can be used in different flows and pages.

import 'package:bb_mobile/features/pin_code/presentation/widgets/numeric_keyboard.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:flutter/material.dart';

class PinCodeInputScreen extends StatelessWidget {
  final String pinCode;
  final String title;
  final String subtitle;
  final String submitButtonLabel;
  final void Function() onBackspace;
  final bool? disableBackspace;
  final List<int> keyboardNumbers;
  final void Function(int key) onKey;
  final bool? disableKeys;
  final void Function() onSubmit;
  final bool? disableSubmit;
  final int? failedAttempts;
  final int? timeoutSeconds;
  final void Function()? backHandler;

  const PinCodeInputScreen({
    super.key,
    this.pinCode = '',
    required this.title,
    required this.subtitle,
    required this.submitButtonLabel,
    required this.onBackspace,
    this.disableBackspace,
    required this.keyboardNumbers,
    required this.onKey,
    this.disableKeys,
    required this.onSubmit,
    this.disableSubmit,
    this.failedAttempts,
    this.timeoutSeconds,
    this.backHandler,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: backHandler != null,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        backHandler?.call();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: false,
          leading: backHandler != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: backHandler,
                )
              : null,
        ),
        body: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            PinCodeDisplay(
              pinCode: pinCode,
            ),
            const SizedBox(height: 20),
            NumericKeyboard(
              numbers: keyboardNumbers,
              onNumberSelected: onKey,
              onBackspacePressed: onBackspace,
              disableBackspace: disableBackspace,
              disableKeys: disableKeys,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: disableSubmit ?? true ? null : onSubmit,
              child: Text(submitButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
