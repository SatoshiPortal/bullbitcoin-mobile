import 'package:access/setup.dart';
import 'package:access/src/domain/access_failure.dart';

import '../../test_theme.dart';

import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/ui/screens/pin_settings_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInfoCard, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../presentation/bloc/pin_code_setting_bloc_test.dart'
    show
        MockCheckPinBackupUsecase,
        MockDeletePinCodeUsecase,
        MockIsPinCodeSetUsecase,
        MockSetPinCodeUsecase;

class _MockPinCodeSettingBloc extends Mock implements PinCodeSettingBloc {}

void main() {
  testWidgets('Change PIN opens PIN selection without seed proof', (
    tester,
  ) async {
    final isPinCodeSet = MockIsPinCodeSetUsecase();
    when(() => isPinCodeSet.execute()).thenAnswer((_) async => const Ok(true));
    final checkBackup = MockCheckPinBackupUsecase();
    when(() => checkBackup.execute())
        .thenAnswer((_) async => const Err(AccessBackupRequiredFailure(1)));
    final bloc = PinCodeSettingBloc(
      setPinCodeUsecase: MockSetPinCodeUsecase(),
      deletePinCodeUsecase: MockDeletePinCodeUsecase(),
      lockChanges: const Stream.empty(),
      isPinCodeSetUsecase: isPinCodeSet,
      checkBackupUsecase: checkBackup,
    );
    addTearDown(bloc.close);
    bloc.add(const PinCodeSettingStarted());

    await tester.pumpWidget(
      MaterialApp(
        theme: accessTestTheme(Brightness.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          AccessLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AccessLocalizations.supportedLocales,
        home: BlocProvider<PinCodeSettingBloc>.value(
          value: bloc,
          child: PinSettingsScreen(onBackUp: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change PIN'));
    await tester.pumpAndSettle();

    expect(bloc.state.status, PinCodeSettingStatus.choose);
    verifyNever(() => checkBackup.execute());
  });

  // Without a backup, the requirement is explained in place with the action
  // that lifts it, instead of a redirect that left Create PIN dead on return.
  testWidgets('a required backup is offered in place', (tester) async {
    final bloc = _MockPinCodeSettingBloc();
    when(() => bloc.state).thenReturn(
      const PinCodeSettingState(
        status: PinCodeSettingStatus.backupRequired,
        choosePinKeyboardNumbers: [],
        confirmPinKeyboardNumbers: [],
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    var backUpOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: accessTestTheme(Brightness.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          AccessLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AccessLocalizations.supportedLocales,
        home: BlocProvider<PinCodeSettingBloc>.value(
          value: bloc,
          child: PinSettingsScreen(onBackUp: () => backUpOpened = true),
        ),
      ),
    );

    expect(find.byType(BullInfoCard), findsOneWidget);
    final create = tester.widget<BullButton>(
      find.widgetWithText(BullButton, 'Create PIN'),
    );
    expect(create.disabled, isTrue);

    await tester.tap(find.text('Start Backup'));
    expect(backUpOpened, isTrue);
  });
}
