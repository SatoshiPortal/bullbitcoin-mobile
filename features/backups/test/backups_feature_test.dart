import 'package:backups/backups.dart';
import 'package:bull_ui/bull_ui.dart' show BullBackupOptionCard;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('keeps the options path and dispatches the physical mode', (
    tester,
  ) async {
    final selected = <String>[];
    String? optionsPath;
    final feature = BackupsFeature.mount(
      copyOf: (context) {
        optionsPath = GoRouterState.of(context).uri.path;
        return _copy;
      },
      encryptedIcon: const SizedBox.shrink(),
      physicalIcon: const SizedBox.shrink(),
      onStartPhysical: (_) => selected.add('start'),
      onVerifyPhysical: (_) => selected.add('verify'),
    );
    final router = GoRouter(
      initialLocation: '/settings/backup-settings',
      routes: [
        GoRoute(
          path: '/settings/backup-settings',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => BackupsNavigation.start(context),
                  child: const Text('Start'),
                ),
                TextButton(
                  onPressed: () => BackupsNavigation.verify(context),
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),
          routes: [feature.route],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: testBullExtensions),
      ),
    );
    await tester.pumpAndSettle();

    for (final (button, title, mode) in [
      ('Start', _copy.backupTitle, 'start'),
      ('Verify', _copy.testTitle, 'verify'),
    ]) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(optionsPath, '/settings/backup-settings/backup-options');
      expect(find.text(title), findsOneWidget);
      final physical = find.ancestor(
        of: find.text(_copy.physical.title),
        matching: find.byType(BullBackupOptionCard),
      );
      await tester.tap(physical);
      expect(selected.last, mode);
      await tester.tap(find.text(_copy.helpLabel));
      await tester.pumpAndSettle();
      expect(find.text(_copy.helpTitle), findsOneWidget);
      await tester.tap(find.byTooltip(_copy.closeLabel));
      await tester.pumpAndSettle();
      expect(find.text(_copy.helpTitle), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
    }
    expect(selected, ['start', 'verify']);
  });
}

const BackupsCopy _copy = (
  backupTitle: 'Back up wallet',
  testTitle: 'Test backup',
  importanceWarning: 'Keep a backup',
  encrypted: (title: 'Encrypted', description: 'Encrypted method', tag: 'One'),
  physical: (title: 'Physical', description: 'Physical method', tag: 'Two'),
  helpLabel: 'Help',
  helpTitle: 'Choose a method',
  closeLabel: 'Close',
  losePhysical: 'Physical risk',
  encryptedVault: 'Encrypted vault',
  physicalRecommendation: 'Physical recommendation',
  physicalRecommendationText: 'Physical advice',
  encryptedRecommendation: 'Encrypted recommendation',
  encryptedRecommendationText: 'Encrypted advice',
  moreInfo: 'More information',
);
