import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:silent/src/ui/sp_router.dart';

abstract final class SilentNavigation {
  static Future<void> openWallet(BuildContext context) async {
    await context.pushNamed<void>(SpRoute.spWalletDetail.name);
  }

  static Future<void> openSettings(
    BuildContext context, {
    required bool isSetUp,
  }) async {
    await context.pushNamed<void>(
      isSetUp ? SpRoute.spSettings.name : SpSetupRoute.spSetup.name,
    );
  }
}
