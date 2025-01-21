import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/shuffled_numbers_keyboard.dart';
import 'package:flutter/material.dart';

class PinCodeInputScreen extends StatelessWidget {
  final String pinCode;
  final String title;
  final String subtitle;
  final String submitButtonLabel;
  final void Function()? onBackspace;
  final void Function(int key)? onKey;
  final void Function()? onSubmit;
  final int? failedAttempts;
  final int? timeoutSeconds;
  final void Function()? backHandler;

  const PinCodeInputScreen({
    super.key,
    this.pinCode = '',
    required this.title,
    required this.subtitle,
    required this.submitButtonLabel,
    this.onBackspace,
    this.onKey,
    this.onSubmit,
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
            ShuffledNumbersKeyboard(
              onNumberSelected: onKey,
              onBackspacePressed: onBackspace,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onSubmit,
              child: Text(submitButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
