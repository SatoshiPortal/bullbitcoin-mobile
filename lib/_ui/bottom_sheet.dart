import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

Future showBBBottomSheet({
  required BuildContext context,
  required Widget child,
  bool scrollToBottom = false,
}) {
  return showMaterialModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => PopUpBorder(
      scrollToBottom: scrollToBottom,
      child: child,
    ),
  );
}
