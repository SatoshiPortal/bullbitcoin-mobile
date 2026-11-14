import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'restored PSBT route without context renders an unavailable state',
    (tester) async {
      final router = GoRouter(
        initialLocation: PsbtFlowRoutes.show.path,
        routes: [PsbtRouterConfig.route],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(Scaffold));
      expect(
        find.text(AppLocalizations.of(context).oopsSomethingWentWrong),
        findsOneWidget,
      );
    },
  );
}
