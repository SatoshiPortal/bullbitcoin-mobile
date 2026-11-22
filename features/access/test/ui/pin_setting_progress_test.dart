import 'package:access/setup.dart';

import 'dart:async';

import '../test_theme.dart';

import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:access/src/ui/pin_code_setting_flow.dart';
import 'package:access/access.dart';
import 'package:access/src/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class _PinSetting extends MockBloc<PinCodeSettingEvent, PinCodeSettingState>
    implements PinCodeSettingBloc {}

const _initial = PinCodeSettingState(
  choosePinKeyboardNumbers: [],
  confirmPinKeyboardNumbers: [],
);

void main() {
  for (final theme in [Brightness.light, Brightness.dark]) {
    for (final status in [
      PinCodeSettingStatus.initializing,
      PinCodeSettingStatus.success,
    ]) {
      testWidgets('PIN progress ${status.name} in ${theme.name}', (
        tester,
      ) async {
        final loc = await _showProgress(
          tester,
          theme,
          initialState: _initial.copyWith(status: status),
        );
        final initializing = status == PinCodeSettingStatus.initializing;
        expect(
          find.text(initializing ? loc.pinCodeLoading : loc.pinCodeProcessing),
          findsOneWidget,
        );
        expect(
          find.text(
            initializing ? loc.pinCodeCheckingStatus : loc.pinCodeSettingUp,
          ),
          findsOneWidget,
        );
        final loader = find.byType(BullLoader);
        expect(tester.getSize(loader), const Size.square(BullLoader.largeSize));
        expect(find.byType(BullButton), findsNothing);
      });
    }
  }

  testWidgets('PIN setting failure returns with the translated message', (
    tester,
  ) async {
    final states = StreamController<PinCodeSettingState>();
    addTearDown(states.close);
    final loc = await _showProgress(
      tester,
      Brightness.light,
      initialState: _initial,
      states: states.stream,
    );
    states.add(
      _initial.copyWith(
        status: PinCodeSettingStatus.failure,
        failure: const AccessPinSaveFailure(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PinCodeSettingFlow), findsNothing);
    expect(find.text('Open PIN settings'), findsOneWidget);
    expect(find.text(loc.pinCodeSaveError), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}

Future<AccessLocalizations> _showProgress(
  WidgetTester tester,
  Brightness theme, {
  required PinCodeSettingState initialState,
  Stream<PinCodeSettingState> states = const Stream.empty(),
}) async {
  final bloc = _PinSetting();
  whenListen(bloc, states, initialState: initialState);
  accessLocator.pushNewScope(
    init: (scope) => scope.registerFactory<PinCodeSettingBloc>(() => bloc),
  );
  addTearDown(accessLocator.popScope);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/pin'),
            child: const Text('Open PIN settings'),
          ),
        ),
      ),
      GoRoute(
        path: '/pin',
        builder: (_, _) => PinCodeSettingFlow(onBackUp: (_) async {}),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: accessTestTheme(theme),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        AccessLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AccessLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open PIN settings'));
  await tester.pumpAndSettle();
  return AccessLocalizations.of(
    tester.element(find.byType(PinCodeSettingFlow)),
  );
}
