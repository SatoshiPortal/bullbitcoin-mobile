import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_fallback_listener.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<TorTransportFallback> fallbacks;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    fallbacks = StreamController<TorTransportFallback>.broadcast();
    navigatorKey = GlobalKey<NavigatorState>();
  });

  tearDown(() => fallbacks.close());

  /// Mounted like the app does it: above `MaterialApp`, so localization and
  /// overlay come from the root navigator, not from the listener's context.
  Future<void> pumpAboveApp(WidgetTester tester, {Key? key}) =>
      tester.pumpWidget(
        TorFallbackListener(
          key: key,
          fallbacks: fallbacks.stream,
          resolveOverlay: () => navigatorKey.currentState?.overlay,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    SnackBarUtils.dismiss();
    await tester.pumpAndSettle();
  }

  const censored = TorTransportFallback(
    from: TorTransport.direct,
    to: TorTransport.snowflake,
    reason: TorFallbackReason.censorship,
  );

  testWidgets('explains a censorship fallback wherever the user is', (
    tester,
  ) async {
    await pumpAboveApp(tester);

    fallbacks.add(censored);
    await tester.pump();

    expect(
      find.text('Your network seems to block Tor. Switching to Snowflake.'),
      findsOneWidget,
    );
    await settle(tester);
  });

  for (final reason in [TorFallbackReason.stalled, TorFallbackReason.timeout]) {
    testWidgets('explains a ${reason.name} fallback as slowness', (
      tester,
    ) async {
      await pumpAboveApp(tester);

      fallbacks.add(
        TorTransportFallback(
          from: TorTransport.direct,
          to: TorTransport.snowflake,
          reason: reason,
        ),
      );
      await tester.pump();

      expect(
        find.text('Tor is connecting slowly. Switching to Snowflake.'),
        findsOneWidget,
      );
      await settle(tester);
    });
  }

  testWidgets('shows one snackbar per fallback, not per rebuild', (
    tester,
  ) async {
    final shown = <String>[];
    Future<void> pump() => tester.pumpWidget(
      TorFallbackListener(
        fallbacks: fallbacks.stream,
        resolveOverlay: () => navigatorKey.currentState?.overlay,
        show: (_, message) => shown.add(message),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox(),
        ),
      ),
    );
    await pump();

    fallbacks.add(censored);
    await tester.pump();
    await pump();
    await pump();

    expect(shown, ['Your network seems to block Tor. Switching to Snowflake.']);

    fallbacks.add(censored);
    await tester.pump();
    expect(shown, hasLength(2));
  });
}
