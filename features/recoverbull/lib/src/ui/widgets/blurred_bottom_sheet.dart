import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';

class BlurredBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    if (Theme.of(context).extension<BullTheme>() == null) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        useSafeArea: true,
        builder: (_) => child,
      );
    }
    return BullBottomSheet.show<T>(
      context: context,
      child: child,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
    );
  }
}
