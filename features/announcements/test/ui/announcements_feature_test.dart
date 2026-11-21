import 'dart:async';

import 'package:announcements/announcements.dart';
import 'package:announcements/setup.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences_dao.dart';
import 'package:preferences/testing.dart';

class _Dao extends Mock implements PreferencesDao {}

void main() {
  testWidgets(
    'mount reads persisted dismissals and owns the update subscription',
    (tester) async {
      final dao = _Dao();
      when(dao.readDismissals).thenAnswer(
        (_) async => [
          (id: 'aFutureAnnouncement', dismissedAt: DateTime.now().toUtc()),
        ],
      );
      final preferences = PreferencesTesting.fromDao(dao);
      addTearDown(preferences.close);
      final updates = StreamController<bool>.broadcast();
      addTearDown(updates.close);
      const updateRequired = true;
      final feature = AnnouncementsFeature.mount(
        dismissals: preferences.announcementDismissals,
        isAppUpdateRequired: () => updateRequired,
        watchAppUpdateRequired: () => updates.stream,
        openPayjoinSettings: (_) =>
            fail('The update warning has no destination'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [
            AnnouncementsLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: feature.carousel()),
        ),
      );
      await tester.pumpAndSettle();

      verify(dao.readDismissals).called(1);
      expect(find.text('Update BULL'), findsOneWidget);
      expect(updates.hasListener, isTrue);

      final now = DateTime.now().toUtc();
      when(
        dao.readDismissals,
      ).thenAnswer((_) async => [(id: 'appUpdateRequired', dismissedAt: now)]);
      // The live signal causes the carousel to consult the saved snooze.
      updates.add(updateRequired);
      await tester.pumpAndSettle();

      expect(find.text('Update BULL'), findsNothing);
      verify(dao.readDismissals).called(1);

      when(dao.readDismissals).thenAnswer(
        (_) async => [
          (
            id: 'appUpdateRequired',
            dismissedAt: now.subtract(const Duration(days: 2)),
          ),
        ],
      );
      updates.add(updateRequired);
      await tester.pumpAndSettle();

      expect(find.text('Update BULL'), findsOneWidget);
      verify(dao.readDismissals).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(updates.hasListener, isFalse);
    },
  );
}
