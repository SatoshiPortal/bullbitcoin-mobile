import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void popUntilPath(BuildContext context, String routePath) {
  while (GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.matches.last.matchedLocation !=
      routePath) {
    if (!context.canPop()) return;
    context.pop();
  }
}
