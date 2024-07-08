import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

extension Xontext on BuildContext {
  SnackBar showToast(String text) {
    return SnackBar(
      content: Center(child: BBText.titleLarge(text)),
      backgroundColor: colour.primaryContainer,
      elevation: 4,
    );
  }
}
