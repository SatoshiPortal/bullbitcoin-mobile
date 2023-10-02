import 'dart:ui';

import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class PopUpBorder extends StatelessWidget {
  const PopUpBorder({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 100,
      ),
      controller: ModalScrollController.of(context),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 16),
        child: ColoredBox(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IgnorePointer(
                ignoring: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colour.onPrimary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(25.0),
                    ),
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
