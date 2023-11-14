import 'package:bb_mobile/_ui/components/alert.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

void showErrorAlert(BuildContext context, String err, [Function? onClose]) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    Alert.openPopUp(
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
