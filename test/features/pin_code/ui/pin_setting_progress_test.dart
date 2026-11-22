import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
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
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
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
      AppThemeType.light,
      initialState: _initial,
      states: states.stream,
    );
    states.add(
      _initial.copyWith(
        status: PinCodeSettingStatus.failure,
        failure: const PinCodeSaveFailure(),
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

Future<AppLocalizations> _showProgress(
  WidgetTester tester,
  AppThemeType theme, {
  required PinCodeSettingState initialState,
  Stream<PinCodeSettingState> states = const Stream.empty(),
}) async {
  final bloc = _PinSetting();
  whenListen(bloc, states, initialState: initialState);
  locator.pushNewScope(
    init: (scope) => scope.registerFactory<PinCodeSettingBloc>(() => bloc),
  );
  addTearDown(locator.popScope);
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
      theme: AppTheme.themeData(theme),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ...appLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open PIN settings'));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(PinCodeSettingFlow)));
}
