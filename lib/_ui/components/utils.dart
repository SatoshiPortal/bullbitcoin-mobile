import 'package:bb_mobile/_ui/components/alert.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

// TODO: How to make 3rd param as Cubit and still call clearErrors()
Function showErrorAlert = (BuildContext context, String err, dynamic cubit) {
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
                  cubit.clearErrors();
                  context.pop();
                },
              ),
            ),
          ];
        },
      ),
    );
  });
};
