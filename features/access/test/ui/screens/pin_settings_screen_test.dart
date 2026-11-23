import 'package:access/setup.dart';

import '../../test_theme.dart';

import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/ui/screens/pin_settings_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInfoCard, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinCodeSettingBloc extends Mock implements PinCodeSettingBloc {}

void main() {
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
