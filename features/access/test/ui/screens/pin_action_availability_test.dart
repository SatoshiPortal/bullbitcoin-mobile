import 'package:access/setup.dart';

import 'dart:ui' show Tristate, SemanticsAction;

import '../../test_theme.dart';

import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/ui/screens/choose_pin_code_screen.dart';
import 'package:access/src/ui/screens/confirm_pin_code_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _PinBloc extends Mock implements PinCodeSettingBloc {}

void main() {
  for (final theme in [Brightness.light, Brightness.dark]) {
    for (final confirm in [false, true]) {
      for (final scenario in [
        (eligible: false, busy: false),
        (eligible: true, busy: false),
        if (confirm) (eligible: true, busy: true),
      ]) {
        final eligible = scenario.eligible;
        final enabled = eligible && !scenario.busy;
        testWidgets(
          'PIN action reflects eligibility (theme: $theme, confirm: $confirm, eligible: $eligible, busy: ${scenario.busy})',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final bloc = _PinBloc();
            final state = PinCodeSettingState(
              isConfirming: scenario.busy,
              choosePinKeyboardNumbers: List.generate(10, (i) => i),
              confirmPinKeyboardNumbers: List.generate(10, (i) => i),
              pinCode: eligible ? List.filled(4, '0').join() : '',
              pinCodeConfirmation: eligible ? List.filled(4, '0').join() : '',
            );
            when(() => bloc.state).thenReturn(state);
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
                home: BlocProvider<PinCodeSettingBloc>.value(
                  value: bloc,
                  child: confirm
                      ? const ConfirmPinCodeScreen()
                      : const ChoosePinCodeScreen(),
                ),
              ),
            );
            final button = tester.widget<BullButton>(find.byType(BullButton));
            expect(button.disabled, !enabled);
            final nodes = find.semantics.byPredicate(
              (node) =>
                  node.label == button.label && node.flagsCollection.isButton,
            );
            expect(nodes, findsOne);
            final node = nodes.evaluate().single;
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              enabled,
            );
            expect(
              node.flagsCollection.isEnabled,
              enabled ? Tristate.isTrue : Tristate.isFalse,
            );
            final tap = tester
                .widget<InkWell>(
                  find.descendant(
                    of: find.byType(BullButton),
                    matching: find.byType(InkWell),
                  ),
                )
                .onTap;
            expect(tap == null, !enabled);
            await tester.tap(find.byType(BullButton), warnIfMissed: false);
            if (confirm) {
              if (enabled) {
                verify(() => bloc.add(const PinCodeSettingPinCodeConfirmed()))
                    .called(1);
              } else {
                verifyNever(
                  () => bloc.add(const PinCodeSettingPinCodeConfirmed()),
                );
              }
            } else {
              if (enabled) {
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
