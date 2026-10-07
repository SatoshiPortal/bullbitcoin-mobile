import 'dart:async';

import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:bull_recoverbull/src/ui/screens/password_input_page.dart';
import 'package:bull_recoverbull/src/ui/screens/view_vault_key_page.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The `no_screenshot` plugin flips the OS capture flag through this channel.
const _noScreenshot = MethodChannel('com.flutterplaza.no_screenshot_methods');

const _vaultKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

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
  theme: ThemeData(extensions: const [testBullTheme]),
  localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
  supportedLocales: RecoverBullLocalizations.supportedLocales,
  home: home,
);

void main() {
  final calls = <String>[];

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshot, (call) async {
          calls.add(call.method);
          return true;
        });
    // The controller is a process-wide singleton: drain any screen a previous
    // test left acquired so each test starts unprotected.
    for (var i = 0; i < 100; i++) {
      await ScreenCaptureProtection.instance.release();
    }
    ScreenCaptureProtection.instance.enabledByUser = true;
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshot, null);
  });

  group('ViewVaultKeyPage', () {
    testWidgets('blocks screen capture while it is shown', (tester) async {
      await tester.pumpWidget(
        _app(const ViewVaultKeyPage(vaultKey: _vaultKey)),
      );
      await tester.pump();
      expect(calls.lastOrNull, 'screenshotOff');

      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump();
      expect(calls.lastOrNull, 'screenshotOn');
    });

    testWidgets('keeps the key out of the semantics tree', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const ViewVaultKeyPage(vaultKey: _vaultKey)),
      );
      await tester.pump();

      final visiblePrefix = _vaultKey.substring(0, 6);
      expect(find.textContaining(visiblePrefix), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(visiblePrefix)), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining(visiblePrefix), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(visiblePrefix)), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets('PasswordInputPage blocks screen capture while it is shown', (
    tester,
  ) async {
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
    expect(calls.lastOrNull, 'screenshotOff');

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump();
    expect(calls.lastOrNull, 'screenshotOn');
  });
}
