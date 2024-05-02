import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:no_screenshot/no_screenshot.dart';

class AppLifecycleOverlay extends StatefulWidget {
  const AppLifecycleOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleOverlay> createState() => _AppLifecycleOverlayState();
}

class _AppLifecycleOverlayState extends State<AppLifecycleOverlay>
    with WidgetsBindingObserver {
  bool shouldBlur = false;
  final _noScreenshot = NoScreenshot.instance;

  final sensitivePaths = [
    '/home/import',
    '/home/wallet/wallet-settings/open-backup',
    '/home/wallet/wallet-settings/wallet-settings/backup',
    '/home/wallet/wallet-settings/wallet-settings/test-backup',
    '/home/wallet-settings/open-backup',
    '/home/wallet-settings/wallet-settings/backup',
    '/home/wallet-settings/wallet-settings/test-backup',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    locator<GoRouter>().routerDelegate.addListener(() {
      final routePath = locator<GoRouter>()
          .routerDelegate
          .currentConfiguration
          .routes
          .map((RouteBase e) => (e as GoRoute).path)
          .join();
      // print(routePath);
      if (sensitivePaths.any((path) => routePath.startsWith(path))) {
        _noScreenshot.screenshotOff();
      } else {
        _noScreenshot.screenshotOn();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // _noScreenshot.screenshotOff();
    setState(() {
      shouldBlur = state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colour.primary,
      child: Opacity(
        opacity: shouldBlur ? 0 : 1,
        child: widget.child,
      ),
    );
  }
}
