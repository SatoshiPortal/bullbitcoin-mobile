import 'package:access/setup.dart';

import '../test_theme.dart';

import 'package:access/src/presentation/bloc/app_unlock_bloc.dart';
import 'package:access/src/ui/pin_code_unlock_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _UnlockBloc extends Mock implements AppUnlockBloc {}

void main() {
  for (final theme in [Brightness.light, Brightness.dark]) {
    for (final (name, length, busy, cooldown, eligible) in [
      ('empty', 0, false, 0, false),
      ('verifying', 4, true, 0, false),
      ('cooldown', 4, false, 5, false),
      ('ready', 4, false, 0, true),
    ]) {
      testWidgets('unlock reflects $name availability in $theme', (
        tester,
      ) async {
        final bloc = _UnlockBloc();
        when(() => bloc.state).thenReturn(
          AppUnlockState(
            keyboardNumbers: List.generate(10, (i) => i),
            pinCode: List.filled(length, '0').join(),
            isVerifying: busy,
            timeoutSeconds: cooldown,
          ),
        );
        when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
        await tester.pumpWidget(
          MaterialApp(
            theme: accessTestTheme(theme),
            localizationsDelegates: const [
              bullUiLocalizationsDelegate,
              AccessLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AccessLocalizations.supportedLocales,
            home: BlocProvider<AppUnlockBloc>.value(
              value: bloc,
              child: const PinCodeUnlockInputScreen(),
            ),
          ),
        );
        final button = tester.widget<BullButton>(find.byType(BullButton));
        expect(button.disabled, !eligible);
        final ink = tester.widget<InkWell>(
          find.descendant(
            of: find.byType(BullButton),
            matching: find.byType(InkWell),
          ),
        );
        expect(ink.onTap == null, !eligible);
        await tester.tap(find.byType(BullButton), warnIfMissed: false);
        if (eligible) {
          verify(() => bloc.add(const AppUnlockSubmitted())).called(1);
        } else {
          verifyNever(() => bloc.add(const AppUnlockSubmitted()));
        }
      });
    }
  }
}
