import 'dart:async';
import 'dart:ui';

import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class PopUpBorder extends StatefulWidget {
  const PopUpBorder({
    super.key,
    required this.child,
    this.scrollToBottom = false,
  });

  final Widget child;
  final bool scrollToBottom;

  @override
  State<PopUpBorder> createState() => _PopUpBorderState();
}

class _PopUpBorderState extends State<PopUpBorder> {
  final _scroll = ScrollController();

  late StreamSubscription<bool> keyboardSubscription;
  late KeyboardVisibilityController controller;

  @override
  void initState() {
    super.initState();

    controller = KeyboardVisibilityController();

    keyboardSubscription = controller.onChange.listen((bool visible) async {
      if (visible && widget.scrollToBottom) {
        await Future.delayed(300.ms);
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 100,
      ),
      controller: _scroll,
      // controller: ModalScrollController.of(context),
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
                    color: context.colour.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(25.0),
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
