import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/choose_pin_code_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/confirm_pin_code_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _PinBloc extends Mock implements PinCodeSettingBloc {}

void main() {
  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    for (final confirm in [false, true]) {
      for (final eligible in [false, true]) {
        testWidgets(
          'PIN action reflects eligibility (theme: $theme, confirm: $confirm, eligible: $eligible)',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final bloc = _PinBloc();
            final state = PinCodeSettingState(
              choosePinKeyboardNumbers: List.generate(10, (i) => i),
              confirmPinKeyboardNumbers: List.generate(10, (i) => i),
              pinCode: eligible ? List.filled(4, '0').join() : '',
              pinCodeConfirmation: eligible ? List.filled(4, '0').join() : '',
            );
            when(() => bloc.state).thenReturn(state);
            when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.themeData(theme),
                localizationsDelegates: const [
                  bullUiLocalizationsDelegate,
                  ...appLocalizationsDelegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: BlocProvider<PinCodeSettingBloc>.value(
                  value: bloc,
                  child: confirm
                      ? const ConfirmPinCodeScreen()
                      : const ChoosePinCodeScreen(),
                ),
              ),
            );
            final button = tester.widget<BullButton>(find.byType(BullButton));
            expect(button.disabled, !eligible);
            final tap = tester
                .widget<InkWell>(
                  find.descendant(
                    of: find.byType(BullButton),
                    matching: find.byType(InkWell),
                  ),
                )
                .onTap;
            expect(tap == null, !eligible);
            await tester.tap(find.byType(BullButton), warnIfMissed: false);
            if (confirm) {
              if (eligible) {
                verify(() => bloc.add(const PinCodeSettingPinCodeConfirmed()))
                    .called(1);
              } else {
                verifyNever(
                  () => bloc.add(const PinCodeSettingPinCodeConfirmed()),
                );
              }
            } else {
              if (eligible) {
                verify(() => bloc.add(const PinCodeSettingPinCodeChosen()))
                    .called(1);
              } else {
                verifyNever(
                  () => bloc.add(const PinCodeSettingPinCodeChosen()),
                );
              }
            }
            semantics.dispose();
          },
        );
      }
    }
  }
}
