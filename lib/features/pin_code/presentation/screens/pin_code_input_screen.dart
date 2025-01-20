// Make sure the text, confirm handler and success state listener handler can
//  be passed in so the screen can be used in different flows and pages.

import 'package:flutter/material.dart';

class PinCodeInputScreen extends StatelessWidget {
  final String pinCode;
  final void Function() onSubmit;
  final void Function() onBackspace;
  final void Function(String key) onKey;
  final int? failedAttempts;
  final int? timeoutSeconds;
  final void Function()? backHandler;

  const PinCodeInputScreen({
    super.key,
    this.pinCode = '',
    required this.onSubmit,
    required this.onBackspace,
    required this.onKey,
    this.failedAttempts,
    this.timeoutSeconds,
    this.backHandler,
  });

  @override
  Widget build(BuildContext context) {
    // Todo: add backhandler if passed in
    return Scaffold(
      body: Center(
        child: Text('Pin Code Input Screen: $pinCode'),
      ),
    );
  }
}
