import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

class AlertData {
  const AlertData({
    this.title,
    required this.text,
    this.actionButtonsBuilder,
  });

  final String text;
  final String? title;
  final List<Widget> Function(BuildContext)? actionButtonsBuilder;
}

class Alert extends StatelessWidget {
  const Alert({this.title, required this.text, required this.buttons});

  static Future openPopUp(BuildContext context, AlertData alertData) {
    return showGeneralDialog(
      barrierLabel: 'showGeneralDialog',
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      context: context,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Alert(
            title: alertData.title,
            text: alertData.text,
            buttons: alertData.actionButtonsBuilder != null
                ? alertData.actionButtonsBuilder!(context)
                : [],
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }

  final String? title;
  final String text;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return IntrinsicHeight(
      child: SizedBox(
        width: width * (95 / 100),
        child: AlertDialog(
          backgroundColor: context.colour.onPrimary,
          title: title != null ? Text(title ?? '') : Container(),
          content: Text(text),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: buttons,
        ),
      ),
    );
  }
}
