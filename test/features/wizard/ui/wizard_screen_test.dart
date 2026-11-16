import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/mark_wizard_complete_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/save_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/customize_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/mission_consent_row.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWizardRepository implements WizardRepository {
  WizardChoices? pending;

  @override
  Future<bool> isComplete() async => false;

  @override
  Future<void> markComplete() async {}

  @override
  Future<void> savePending(WizardChoices choices) async => pending = choices;

  @override
  Future<WizardChoices?> readPending() async => pending;

  @override
  Future<void> clearPending() async => pending = null;
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Device.screen = const Size(400, 800);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final allowed in [false, true]) {
    testWidgets(
      'the exchange switch follows the platform permission $allowed',
      (tester) async {
        final repository = _FakeWizardRepository();
        await _pump(
          tester,
          BlocProvider(
            create: (_) => WizardBloc(
              savePending: SavePendingWizardChoicesUsecase(
                repository: repository,
              ),
              markComplete: MarkWizardCompleteUsecase(repository: repository),
            ),
            child: WizardScreen(exchangeAllowed: allowed),
          ),
        );
        final pages =
            tester.widget<PageView>(find.byType(PageView)).childrenDelegate
                as SliverChildListDelegate;
        expect(pages.children, hasLength(4));

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        final switches = find.descendant(
          of: find.byType(CustomizeStep),
          matching: find.byType(BullSwitch),
        );
        // Dark mode, then the exchange where the platform allows it.
        expect(switches, findsNWidgets(allowed ? 2 : 1));
        if (allowed) {
          await tester.tap(switches.at(1));
          await tester.pump();
        }

        // Skip on the settings page confirms the exchange choice shown there,
        // then sends the user to the mandatory mission question.
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.byType(MissionConsentRow), findsOneWidget);
        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        final saved = repository.pending;
        expect(saved, isNotNull);
        expect(saved?.reportingConsent, isFalse);
        expect(saved?.touched.contains(WizardField.exchangeAccess), allowed);
        if (allowed) expect(saved?.exchangeAccess, isFalse);
        // Lets the mission-required snackbar time out.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final yesFirst in [true, false]) {
    testWidgets('the consent row puts Yes on the left: $yesFirst', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: MissionConsentRow(
            consent: null,
            onYes: () {},
            onNo: () {},
            yesFirst: yesFirst,
          ),
        ),
      );
      final yesX = tester.getCenter(find.text('Yes')).dx;
      final noX = tester.getCenter(find.text('No')).dx;
      expect(yesX < noX, yesFirst);
    });
  }
}
