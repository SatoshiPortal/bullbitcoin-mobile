import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';

import '../../../overview/support/overview_home_harness.dart';

void main() {
  test(
    'unknown readiness falls back to physical backup and dismissal',
    () async {
      final h = OverviewHomeHarness()..backupAnswer = null;
      addTearDown(h.close);
      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('default', isDefault: true, balanceSat: 1),
        ]),
      );
      await flushEvents();
      expect(h.controller.current.backupWarning, isTrue);
      h.controller.dismissBackupWarning();
      expect(h.controller.current.backupWarning, isFalse);

      final backedUp = OverviewHomeHarness()..backupAnswer = null;
      addTearDown(backedUp.close);
      backedUp.physicalBackups['default'] = true;
      backedUp.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('default', isDefault: true, balanceSat: 1),
        ]),
      );
      await flushEvents();
      expect(backedUp.controller.current.backupWarning, isFalse);

      final ready = OverviewHomeHarness()..backupAnswer = false;
      addTearDown(ready.close);
      ready.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('default', isDefault: true, balanceSat: 1),
        ]),
      );
      await flushEvents();
      expect(ready.controller.current.backupWarning, isFalse);
    },
  );

  testWidgets('backup warning owns accessibility until dismissed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = OverviewHomeHarness();
    locator.registerSingleton<OverviewHomeController>(h.controller);
    addTearDown(() async {
      await locator.unregister<OverviewHomeController>();
      await h.close();
    });
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('default', isDefault: true, balanceSat: 0),
      ]),
    );
    await tester.runAsync(flushEvents);
    var historyTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppRouter.withBackupWarning(
            Align(
              alignment: Alignment.topCenter,
              child: TextButton(
                onPressed: () => historyTaps++,
                child: const Text('History'),
              ),
            ),
          ),
        ),
      ),
    );
    final history = find.semantics.byLabel('History');
    expect(history, findsOne);
    final reads = h.backupReadsStarted;
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('default', isDefault: true, balanceSat: 1),
      ]),
    );
    await tester.runAsync(flushEvents);
    await tester.pumpAndSettle();
    expect(h.backupReadsStarted, reads + 1);
    expect(history, findsNothing);
    await tester.tap(find.text('History'), warnIfMissed: false);
    expect(historyTaps, 0);
    const title = 'BACKUP YOUR WALLET NOW';
    expect(
      tester.getSemantics(find.bySemanticsLabel(title)),
      matchesSemantics(label: title, isHeader: true, namesRoute: true),
    );
    expect(find.bySemanticsLabel('YES'), findsOneWidget);
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.bySemanticsLabel('NO, I UNDERSTAND THE RISK'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(title), findsNothing);
    expect(history, findsOne);
    await tester.tap(find.bySemanticsLabel('History'));
    expect(historyTaps, 1);
    final readsAfterDismissal = h.backupReadsStarted;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(h.backupReadsStarted, readsAfterDismissal);
    semantics.dispose();
  });
}
