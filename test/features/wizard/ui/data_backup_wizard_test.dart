import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_app.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final loc = AppLocalizationsEn();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'the wizard saves backup consent and preserves the remaining setup choices',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var finished = false;
      await tester.pumpWidget(WizardApp(onDone: (_) => finished = true));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.wizardNextButton));
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupConsentTitle), findsOneWidget);
      expect(
        await WizardRepositoryImpl(WizardLocalDatasourceImpl()).readPending(),
        isNull,
      );
      await tester.tap(find.text(loc.wizardSkipButton));
      await tester.pumpAndSettle();
      expect(find.text(loc.dataBackupConsentTitle), findsOneWidget);
      expect(finished, isFalse);
      await tester.tap(
        find.byKey(const ValueKey('wizard-data-backup-decline')),
      );
      await tester.pumpAndSettle();
      final pending = await WizardRepositoryImpl(WizardLocalDatasourceImpl())
          .readPending();
      expect(pending?.dataBackupEnabled, isFalse);
      expect(finished, isFalse);
      expect(
        find.byKey(const ValueKey('wizard-data-backup-decline')),
        findsNothing,
      );
      await tester.tap(find.text(loc.wizardNextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.wizardMissionNo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.getStartedButton));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      final completed = await WizardRepositoryImpl(WizardLocalDatasourceImpl())
          .readPending();
      expect(completed?.dataBackupEnabled, isFalse);
      expect(completed?.reportingConsent, isFalse);
    },
  );
}
