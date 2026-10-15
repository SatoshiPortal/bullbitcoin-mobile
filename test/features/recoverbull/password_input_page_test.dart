import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The `no_screenshot` plugin flips the OS capture flag through this channel.
const _noScreenshot = MethodChannel('com.flutterplaza.no_screenshot_methods');

class _FakeRecoverBullBloc extends Fake implements RecoverBullBloc {
  final StreamController<RecoverBullState> _states =
      StreamController<RecoverBullState>.broadcast();

  @override
  RecoverBullState get state =>
      const RecoverBullState(flow: RecoverBullFlow.recoverVault);

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  @override
  void add(RecoverBullEvent event) {}

  @override
  Future<void> close() => _states.close();
}

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  final captureCalls = <String>[];

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshot, (call) async {
          captureCalls.add(call.method);
          return true;
        });
    // The controller is a process-wide singleton: drain any screen a previous
    // test left acquired so each test starts unprotected.
    for (var i = 0; i < 100; i++) {
      await ScreenCaptureProtection.instance.release();
    }
    ScreenCaptureProtection.instance.enabledByUser = true;
    captureCalls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshot, null);
  });

  testWidgets('blocks screen capture while it is shown', (tester) async {
    // A phone-sized surface: the page is laid out for a tall screen.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = _FakeRecoverBullBloc();
    addTearDown(bloc.close);

    await tester.pumpWidget(
      _app(
        BlocProvider<RecoverBullBloc>.value(
          value: bloc,
          child: const PasswordInputPage(),
        ),
      ),
    );
    await tester.pump();
    expect(captureCalls.lastOrNull, 'screenshotOff');

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(captureCalls.lastOrNull, 'screenshotOn');
  });
}
