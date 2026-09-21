import 'dart:async';

import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/settings_failure_listener.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  late _MockSettingsCubit cubit;
  late StreamController<SettingsState> states;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    cubit = _MockSettingsCubit();
    states = StreamController<SettingsState>.broadcast();
    navigatorKey = GlobalKey<NavigatorState>();
    when(() => cubit.state).thenReturn(const SettingsState());
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(cubit.clearFailure).thenReturn(null);
  });

  tearDown(() => states.close());

  /// Reproduces the real mounting point: the listener sits next to the app-wide
  /// provider, ABOVE `MaterialApp`, so its own context has neither a
  /// `Localizations` nor an `Overlay` ancestor. Resolving either through it
  /// throws, which is what this test exists to catch.
  Future<void> pumpListenerAboveApp(
    WidgetTester tester, {
    bool overlayReady = true,
  }) async {
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: SettingsFailureListener(
          resolveOverlay: () =>
              overlayReady ? navigatorKey.currentState?.overlay : null,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
  }

  /// The snackbar schedules a 3s auto-dismiss timer; drain it so the test does
  /// not end with a pending timer.
  Future<void> settleSnackBar(WidgetTester tester) async {
    SnackBarUtils.dismiss();
    await tester.pumpAndSettle();
  }

  testWidgets('shows the failure even though it is mounted above MaterialApp', (
    tester,
  ) async {
    await pumpListenerAboveApp(tester);

    states.add(const SettingsState(failure: SettingsStorageFailure('io')));
    await tester.pump();

    expect(
      find.text('That setting could not be saved. Please try again.'),
      findsOneWidget,
    );
    verify(cubit.clearFailure).called(1);

    await settleSnackBar(tester);
  });

  testWidgets('never shows the raw reason', (tester) async {
    await pumpListenerAboveApp(tester);

    states.add(
      const SettingsState(
        failure: SettingsStorageFailure('SqliteException(13): disk full'),
      ),
    );
    await tester.pump();

    expect(find.textContaining('SqliteException'), findsNothing);

    await settleSnackBar(tester);
  });

  testWidgets('keeps the failure when nothing is mounted to report into', (
    tester,
  ) async {
    // Before the first frame the root navigator has no overlay. Consuming the
    // failure there would drop it silently and, because clearFailure is its
    // only consumer, suppress every later report of the same failure.
    await pumpListenerAboveApp(tester, overlayReady: false);

    states.add(const SettingsState(failure: SettingsStorageFailure('io')));
    await tester.pump();

    verifyNever(cubit.clearFailure);
  });
}
