import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

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

class BBAlert extends StatelessWidget {
  const BBAlert({this.title, required this.text, required this.buttons});

  static Future _openPopUp(BuildContext context, AlertData alertData) {
    return showGeneralDialog(
      barrierLabel: 'showGeneralDialog',
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 600),
      context: context,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: BBAlert(
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

  static void showErrorAlertPopUp({
    String title = 'Error',
    required String err,
    Function? onClose,
  }) {
    if (navigatorKey.currentContext == null) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      BBAlert._openPopUp(
        navigatorKey.currentContext!,
        AlertData(
          title: title,
          text: err,
          actionButtonsBuilder: (context) {
            return [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: BBButton.bigBlack(
                  label: 'Okay',
                  filled: true,
                  onPressed: () {
                    context.pop();
                    if (onClose != null) {
                      onClose();
                    }
                  },
                ),
              ),
            ];
          },
        ),
      );
    });
  }

  static void showErrorAlert(BuildContext context, {required String err, Function? onClose}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      BBAlert._openPopUp(
        context,
        AlertData(
          title: 'Error',
          text: err,
          actionButtonsBuilder: (context) {
            return [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: BBButton.bigBlack(
                  label: 'Okay',
                  filled: true,
                  onPressed: () {
                    context.pop();
                    if (onClose != null) {
                      onClose();
                    }
                  },
                ),
              ),
            ];
          },
        ),
      );
    });
  }

  final String? title;
  final String text;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return IntrinsicHeight(
      child: SizedBox(
        width: width,
        child: AlertDialog(
          backgroundColor: context.colour.background,
          title: title != null ? BBText.titleLarge(title ?? '') : Container(),
          content: BBText.error(text),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          actions: buttons,
          surfaceTintColor: context.colour.background,
        ),
      ),
    );
  }
}
