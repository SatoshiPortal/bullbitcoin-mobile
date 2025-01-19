// Make sure the text, confirm handler and success state listener handler can
//  be passed in so the screen can be used in different flows and pages.

import 'package:flutter/material.dart';

class PinCodeInputScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Pin Code Input Screen'),
      ),
    );
  }
}
